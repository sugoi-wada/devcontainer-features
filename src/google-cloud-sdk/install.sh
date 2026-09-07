#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://cloud.google.com/sdk/docs/install
#
# Debian / Ubuntu では packages.cloud.google.com の apt リポジトリを使います。
# 配布パッケージ名は google-cloud-sdk から google-cloud-cli に変更されているため後者を使用します。
# apt が使えない環境、または apt リポジトリに存在しないバージョンが指定された場合は
# 公式のバージョン付きアーカイブ（tar.gz）にフォールバックします。

set -e

CLOUD_SDK_VERSION="${VERSION:-"latest"}"
INSTALL_COMPONENTS="${COMPONENTS:-""}"

APT_PACKAGE_NAME="google-cloud-cli"
INSTALL_DIR="/usr/local/google-cloud-sdk"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'スクリプトはroot権限で実行する必要があります。sudo、su、またはDockerfileに "USER root" を追加してからこのスクリプトを実行してください。'
    exit 1
fi

# インストール先を所有させるユーザーを決定する（アーカイブ版で gcloud components install を使えるようにするため）
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    for CURRENT_USER in vscode node codespace "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME="${CURRENT_USER}"
            break
        fi
    done
    if [ -z "${USERNAME}" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

export DEBIAN_FRONTEND=noninteractive

apt_get_update() {
    echo "apt-get updateを実行しています..."
    apt-get update -y
}

# パッケージが未インストールの場合のみインストールする
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* 2> /dev/null | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

# aptリポジトリに該当パッケージが存在するか判定する
apt_package_exists() {
    apt-cache policy "$1" 2> /dev/null | grep -qE "^\s+Candidate: [^(]" 
}

# アーキテクチャの判定（Google Cloud CLI のアーカイブ名に合わせる）
detect_archive_arch() {
    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64 | amd64)
            echo "x86_64"
            ;;
        arm64 | aarch64)
            echo "arm"
            ;;
        *)
            echo "サポートされていないアーキテクチャです: ${arch}" >&2
            return 1
            ;;
    esac
}

# 追加コンポーネント指定をカンマ・空白区切りのどちらでも受け付けて正規化する
normalize_components() {
    echo "${INSTALL_COMPONENTS}" | tr ',' ' ' | tr -s ' '
}

setup_shell_integration() {
    echo "PATHとシェル補完を設定しています..."
    cat > /etc/profile.d/google-cloud-sdk.sh << EOF
if [ -f "${INSTALL_DIR}/path.bash.inc" ]; then
    . "${INSTALL_DIR}/path.bash.inc"
fi
if [ -n "\${BASH_VERSION}" ] && [ -f "${INSTALL_DIR}/completion.bash.inc" ]; then
    . "${INSTALL_DIR}/completion.bash.inc"
fi
EOF
    chmod 755 /etc/profile.d/google-cloud-sdk.sh

    if type zsh > /dev/null 2>&1 || [ -d /etc/zsh ]; then
        mkdir -p /etc/zsh
        if ! grep -q "${INSTALL_DIR}/path.zsh.inc" /etc/zsh/zshrc 2> /dev/null; then
            cat >> /etc/zsh/zshrc << EOF

if [ -f "${INSTALL_DIR}/path.zsh.inc" ]; then
    . "${INSTALL_DIR}/path.zsh.inc"
fi
if [ -f "${INSTALL_DIR}/completion.zsh.inc" ]; then
    . "${INSTALL_DIR}/completion.zsh.inc"
fi
EOF
        fi
    fi

    # 非ログインシェルからも使えるようにシンボリックリンクを作成
    for cmd in gcloud gsutil bq docker-credential-gcloud gcloud-crc32c git-credential-gcloud.sh; do
        if [ -x "${INSTALL_DIR}/bin/${cmd}" ]; then
            ln -sf "${INSTALL_DIR}/bin/${cmd}" "/usr/local/bin/${cmd}"
        fi
    done
}

# ------------------------------------------------------------------
# apt リポジトリ経由でのインストール（Debian / Ubuntu）
# ------------------------------------------------------------------
install_via_apt() {
    echo "aptリポジトリからGoogle Cloud CLIをインストールします。"

    check_packages ca-certificates curl gnupg apt-transport-https

    # 古いリポジトリ設定があれば削除
    rm -f /etc/apt/sources.list.d/google-cloud-sdk.list

    mkdir -p /usr/share/keyrings
    echo "Google Cloud CLIの署名鍵をインポートしています..."
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    chmod 644 /usr/share/keyrings/cloud.google.gpg

    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list

    apt_get_update

    # --- 先にインストール対象をすべて解決する（途中で失敗してアーカイブ版と二重インストールになるのを避ける） ---
    local apt_target="${APT_PACKAGE_NAME}"
    if [ "${CLOUD_SDK_VERSION}" != "latest" ]; then
        # apt上のバージョン表記は <version>-0 形式
        local apt_version="${CLOUD_SDK_VERSION}"
        case "${apt_version}" in
            *-*) ;;
            *) apt_version="${apt_version}-0" ;;
        esac
        if ! apt-cache madison "${APT_PACKAGE_NAME}" | grep -q " ${apt_version} "; then
            echo "aptリポジトリにバージョン ${CLOUD_SDK_VERSION} が見つかりませんでした。アーカイブ版にフォールバックします。"
            return 1
        fi
        apt_target="${APT_PACKAGE_NAME}=${apt_version}"
    fi

    # 追加コンポーネントは apt 上のパッケージ名に解決する
    # 多くは google-cloud-cli-<component>、kubectl などはコンポーネント名そのままのパッケージ名
    local component_packages=""
    local components
    components="$(normalize_components)"
    for component in ${components}; do
        local resolved=""
        local candidate
        for candidate in "${APT_PACKAGE_NAME}-${component}" "${component}"; do
            if apt_package_exists "${candidate}"; then
                resolved="${candidate}"
                break
            fi
        done
        if [ -z "${resolved}" ]; then
            echo "コンポーネント '${component}' に対応するaptパッケージが見つかりませんでした。アーカイブ版にフォールバックします。"
            return 1
        fi
        component_packages="${component_packages} ${resolved}"
    done

    # ここまでで対象は解決済み。以降の失敗はフォールバックせずエラーにする
    # （apt が途中で失敗した状態でアーカイブ版を重ねると壊れたインストールになるため）
    echo "Google Cloud CLIをインストールしています: ${apt_target}${component_packages}"
    # shellcheck disable=SC2086
    if ! apt-get -y install --no-install-recommends "${apt_target}" ${component_packages}; then
        echo "aptによるインストールに失敗しました。上記のエラーを確認してください。"
        exit 1
    fi
}

# ------------------------------------------------------------------
# 公式アーカイブ経由でのインストール（apt以外の環境 / apt未収録バージョン）
# ------------------------------------------------------------------
install_via_archive() {
    echo "公式アーカイブからGoogle Cloud CLIをインストールします。"

    local sdk_arch
    sdk_arch="$(detect_archive_arch)"

    if type apt-get > /dev/null 2>&1; then
        check_packages ca-certificates curl tar gzip python3
    elif type apk > /dev/null 2>&1; then
        apk add --no-cache ca-certificates curl tar gzip python3
    elif type dnf > /dev/null 2>&1; then
        dnf install -y ca-certificates curl tar gzip python3
    elif type yum > /dev/null 2>&1; then
        yum install -y ca-certificates curl tar gzip python3
    fi

    local required
    for required in curl tar python3; do
        if ! type "${required}" > /dev/null 2>&1; then
            echo "必須コマンドが見つかりません: ${required}"
            exit 1
        fi
    done

    # latest: google-cloud-cli-linux-<arch>.tar.gz / 固定版: google-cloud-cli-<version>-linux-<arch>.tar.gz
    local version_path=""
    if [ "${CLOUD_SDK_VERSION}" != "latest" ]; then
        version_path="-${CLOUD_SDK_VERSION}"
    fi
    local download_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli${version_path}-linux-${sdk_arch}.tar.gz"

    if [ -d "${INSTALL_DIR}" ]; then
        echo "既存のインストール (${INSTALL_DIR}) を削除します..."
        rm -rf "${INSTALL_DIR}"
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    echo "Google Cloud CLIをダウンロードしています..."
    echo "URL: ${download_url}"
    if ! curl -fsSL "${download_url}" -o "${tmp_dir}/google-cloud-cli.tar.gz"; then
        echo "ダウンロードに失敗しました。指定したバージョン (${CLOUD_SDK_VERSION}) が存在するか確認してください。"
        echo "利用可能なバージョン: https://cloud.google.com/sdk/docs/downloads-versioned-archives"
        rm -rf "${tmp_dir}"
        exit 1
    fi

    echo "アーカイブを展開しています..."
    tar -xzf "${tmp_dir}/google-cloud-cli.tar.gz" -C "$(dirname "${INSTALL_DIR}")"
    rm -rf "${tmp_dir}"

    echo "Google Cloud CLIをセットアップしています..."
    CLOUDSDK_PYTHON="$(command -v python3)" \
        "${INSTALL_DIR}/install.sh" \
        --quiet \
        --usage-reporting=false \
        --path-update=false \
        --command-completion=false \
        --bash-completion=false

    local components
    components="$(normalize_components)"
    if [ -n "${components}" ]; then
        echo "追加コンポーネントをインストールしています: ${components}"
        # shellcheck disable=SC2086
        CLOUDSDK_PYTHON="$(command -v python3)" CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
            "${INSTALL_DIR}/bin/gcloud" components install ${components} --quiet
    fi

    if [ "${CLOUD_SDK_VERSION}" != "latest" ]; then
        CLOUDSDK_PYTHON="$(command -v python3)" \
            "${INSTALL_DIR}/bin/gcloud" config set --installation component_manager/disable_update_check true
    fi

    setup_shell_integration

    if [ "${USERNAME}" != "root" ]; then
        echo "${INSTALL_DIR} の所有者を ${USERNAME} に変更しています..."
        chown -R "${USERNAME}:$(id -gn "${USERNAME}")" "${INSTALL_DIR}"
    fi
}

# ------------------------------------------------------------------
# 実行
# ------------------------------------------------------------------
if type apt-get > /dev/null 2>&1; then
    if ! install_via_apt; then
        install_via_archive
    fi
else
    install_via_archive
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Google Cloud CLIのインストールが完了しました！"
gcloud --version
