#!/bin/bash

set -e

source dev-container-features-test-lib

# apt リポジトリに存在するバージョンの固定指定。
# ベースイメージの python3 が新しすぎて apt が依存を解決できない場合は
# アーカイブ版へフォールバックするため、どちらの経路でも同じ結果になる。
check "指定したバージョンがインストールされている" bash -c "gcloud --version | grep -E 'Google Cloud SDK 560\.0\.0'"
check "aptリポジトリ設定が壊れていない" bash -c "apt-get update"

reportResults
