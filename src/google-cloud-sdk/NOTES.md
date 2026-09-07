## インストール方式

| 環境 / 指定 | インストール方式 |
| --- | --- |
| Debian / Ubuntu で `version: latest` | apt リポジトリ (`google-cloud-cli`) |
| Debian / Ubuntu でバージョン指定あり、かつ apt リポジトリに存在する | apt リポジトリ (`google-cloud-cli=<version>-0`) |
| 上記以外（apt 非対応ディストリ、apt に存在しない古いバージョン） | 公式アーカイブ（`/usr/local/google-cloud-sdk` に展開） |

apt リポジトリには直近 40〜50 バージョン程度しか残らないため、それより古いバージョンを指定した場合は
自動的に[バージョン付きアーカイブ](https://cloud.google.com/sdk/docs/downloads-versioned-archives)へフォールバックします。

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
