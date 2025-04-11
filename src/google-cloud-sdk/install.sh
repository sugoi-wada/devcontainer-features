#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://cloud.google.com/sdk/docs/install
# Maintainer: Google Cloud SDK Team

CLOUD_SDK_VERSION=${VERSION:-"latest"}
INSTALL_COMPONENTS=${COMPONENTS:-""}

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'スクリプトはroot権限で実行する必要があります。sudo、su、またはDockerfileに "USER root" を追加してからこのスクリプトを実行してください。'
    exit 1
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "apt-get updateを実行しています..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# 必要なパッケージのインストール
check_packages curl ca-certificates apt-transport-https lsb-release gnupg2 python3

# OSとアーキテクチャの検出
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# アーキテクチャの変換
case "${ARCH}" in
  x86_64)
    SDK_ARCH="x86_64"
    ;;
  arm64|aarch64)
    SDK_ARCH="arm64"
    ;;
  *)
    echo "サポートされていないアーキテクチャです: ${ARCH}"
    exit 1
    ;;
esac

# OSの判定
case "${OS}" in
  linux)
    PLATFORM="linux"
    
    # Linuxディストリビューションに応じたインストール
    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        # Debian/Ubuntu系の場合
        echo "Debian/Ubuntu系システムを検出しました。"
        
        # 必要なパッケージの確認
        check_packages curl apt-transport-https ca-certificates gnupg
        
        # Google Cloud SDKのリポジトリを追加
        echo "Google Cloud SDKリポジトリを追加しています..."
        
        # 古いリポジトリ設定があれば削除
        if [ -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
            rm -f /etc/apt/sources.list.d/google-cloud-sdk.list
        fi
        
        # GPGキーのディレクトリ作成
        mkdir -p /usr/share/keyrings
        
        # GCPパブリックキーのインポート（より堅牢な方法）
        echo "Google Cloud SDK GPGキーをインポートしています..."
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        
        # リポジトリの追加
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
        
        # パッケージリストの更新（明示的に実行）
        echo "パッケージリストを更新しています..."
        apt-get update -y
        
        # パッケージのインストール
        echo "Google Cloud SDKをインストールしています..."
        apt-get -y install google-cloud-sdk
        
        # 追加コンポーネントのインストール（指定されている場合）
        if [ ! -z "${INSTALL_COMPONENTS}" ]; then
            echo "追加コンポーネントをインストールしています: ${INSTALL_COMPONENTS}"
            apt-get -y install ${INSTALL_COMPONENTS}
        fi
    else
        # その他のLinuxディストリビューションの場合は直接ダウンロード
        INSTALL_METHOD="download"
    fi
    ;;
  darwin)
    PLATFORM="darwin"
    INSTALL_METHOD="download"
    ;;
  *)
    echo "サポートされていないOSです: ${OS}"
    exit 1
    ;;
esac

# パッケージマネージャでインストールできない場合は直接ダウンロード
if [ "${INSTALL_METHOD}" = "download" ] || [ $? -ne 0 ]; then
    echo "Google Cloud SDKを直接ダウンロードしてインストールします..."
    
    # インストール先ディレクトリ
    INSTALL_DIR="/usr/local/google-cloud-sdk"
    
    # 既存のインストールを確認
    if [ -d "${INSTALL_DIR}" ]; then
        echo "Google Cloud SDKはすでに${INSTALL_DIR}にインストールされています。"
        echo "既存のインストールを削除します..."
        rm -rf "${INSTALL_DIR}"
    fi
    
    # 一時ディレクトリの作成
    TMP_DIR=$(mktemp -d)
    cd "${TMP_DIR}"
    
    # バージョン指定（latestでない場合）
    VERSION_PATH=""
    if [ "${CLOUD_SDK_VERSION}" != "latest" ]; then
        VERSION_PATH="-${CLOUD_SDK_VERSION}"
    fi
    
    # パッケージURLの構築
    # ARM64の場合、Google Cloud SDKのダウンロードURLは特殊
    if [ "${SDK_ARCH}" = "arm64" ]; then
        if [ "${PLATFORM}" = "linux" ]; then
            # Linux ARM64の場合
            DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli${VERSION_PATH}-linux-arm.tar.gz"
        else
            # macOS ARM64の場合
            DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli${VERSION_PATH}-darwin-arm.tar.gz"
        fi
    else
        # x86_64の場合
        DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli${VERSION_PATH}-${PLATFORM}-${SDK_ARCH}.tar.gz"
    fi
    
    echo "Google Cloud SDKをダウンロードしています..."
    echo "URL: ${DOWNLOAD_URL}"
    
    # パッケージのダウンロード
    curl -fsSL "${DOWNLOAD_URL}" -o google-cloud-sdk.tar.gz
    
    # パッケージの展開
    echo "パッケージを展開しています..."
    mkdir -p /usr/local
    tar -xzf google-cloud-sdk.tar.gz -C /usr/local
    
    # インストール
    echo "Google Cloud SDKをインストールしています..."
    /usr/local/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=true --command-completion=true --install-python=true
    
    # 追加コンポーネントのインストール（指定されている場合）
    if [ ! -z "${INSTALL_COMPONENTS}" ]; then
        echo "追加コンポーネントをインストールしています: ${INSTALL_COMPONENTS}"
        for component in ${INSTALL_COMPONENTS}; do
            /usr/local/google-cloud-sdk/bin/gcloud components install ${component} --quiet
        done
    fi
    
    # システム全体でgcloudコマンドが使えるようにシンボリックリンクを作成
    ln -sf /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
    ln -sf /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil
    ln -sf /usr/local/google-cloud-sdk/bin/bq /usr/local/bin/bq
    
    # 一時ディレクトリの削除
    cd /
    rm -rf "${TMP_DIR}"
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Google Cloud SDKのインストールが完了しました！"
echo "gcloudコマンドでGoogle Cloud SDKを使用できます。"