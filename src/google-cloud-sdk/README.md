
# Google Cloud CLI (google-cloud-sdk)

Google Cloud CLI (gcloud / gsutil / bq) をインストールします。Debian・Ubuntu では apt リポジトリ、それ以外の環境や apt に存在しないバージョン指定時は公式アーカイブを使用します。

## Example Usage

```json
"features": {
    "ghcr.io/sugoi-wada/devcontainer-features/google-cloud-sdk:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | インストールする Google Cloud CLI のバージョン（例: latest, 583.0.0） | string | latest |
| components | 追加インストールするコンポーネント名をカンマまたは空白区切りで指定（例: gke-gcloud-auth-plugin,kubectl）。apt 経路では google-cloud-cli- プレフィックスが自動で付与されます。 | string | - |

## インストール方式

| 環境 / 指定 | インストール方式 |
| --- | --- |
| Debian / Ubuntu で `version: latest` | apt リポジトリ (`google-cloud-cli`) |
| Debian / Ubuntu でバージョン指定あり、かつ apt リポジトリに存在する | apt リポジトリ (`google-cloud-cli=<version>-0`) |
| 上記以外（apt 非対応ディストリ、apt に存在しない古いバージョン、apt が依存関係を解決できない場合） | 公式アーカイブ（`/usr/local/google-cloud-sdk` に展開） |

apt リポジトリには直近 40〜50 バージョン程度しか残らないため、それより古いバージョンを指定した場合は
自動的に[バージョン付きアーカイブ](https://cloud.google.com/sdk/docs/downloads-versioned-archives)へフォールバックします。

apt 経路に進む前に `apt-get install -s`（dry-run）で依存関係を解決できるか検証しています。
例えば `ubuntu:26.04`（python3 3.14）に古いバージョンを固定指定すると
`Depends: python3 (< 3.14)` を満たせないため、この時点で検知してアーカイブ版へフォールバックします。
アーカイブ版へフォールバックする際は、追加した apt リポジトリ設定と署名鍵を撤去します
（アーカイブ版と apt パッケージが二重にインストールされうる状態を残さないため）。

また、apt が依存関係を解決できても既存パッケージの削除・ダウングレードを伴う場合も
アーカイブ版へフォールバックします。

なお `/usr/share/keyrings/cloud.google.gpg` は gcsfuse など他の
`packages.cloud.google.com` リポジトリでも共有される公式のパスのため、
フォールバック時に撤去するのはこの Feature が新規作成した場合のみです。

## `components` の指定

コンポーネント名はカンマ区切り・空白区切りのどちらでも指定できます。

```json
"features": {
    "ghcr.io/sugoi-wada/devcontainer-features/google-cloud-sdk:1": {
        "components": "gke-gcloud-auth-plugin,kubectl"
    }
}
```

- apt 経路では `google-cloud-cli-<component>` パッケージとして解決されます（プレフィックス付きで指定しても動作します）。
- アーカイブ経路では `gcloud components install <component>` が実行されます。

## 既知の注意点

- apt 経路でインストールした場合、`gcloud components install` は無効化されています（apt でコンポーネントを追加してください）。
- パッケージ名は `google-cloud-sdk` から `google-cloud-cli` に変更されています。Feature の ID は互換性のため `google-cloud-sdk` のままです。


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/sugoi-wada/devcontainer-features/blob/main/src/google-cloud-sdk/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
