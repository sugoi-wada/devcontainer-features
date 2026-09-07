#!/bin/bash

set -e

source dev-container-features-test-lib

# apt リポジトリに存在するバージョンの固定指定。
# ベースイメージの python3 が新しすぎて apt が依存を解決できない場合は
# アーカイブ版へフォールバックするため、どちらの経路でも同じバージョンが入る。
check "指定したバージョンがインストールされている" bash -c "gcloud --version | grep -E 'Google Cloud SDK 560\.0\.0'"

# どちらの経路を通ったかに応じて、残っている apt 設定の整合性を検証する。
# アーカイブ経路では apt リポジトリ設定が撤去されていること（二重インストール防止）、
# apt 経路では source list と署名鍵が揃っていることを確認する。
check "経路に応じた apt 設定になっている" bash -c '
set -e
if [ -d /usr/local/google-cloud-sdk ]; then
    echo "アーカイブ経路: apt リポジトリ設定が撤去されていることを確認します"
    test ! -f /etc/apt/sources.list.d/google-cloud-sdk.list
else
    echo "apt 経路: source list と署名鍵が存在することを確認します"
    test -f /etc/apt/sources.list.d/google-cloud-sdk.list
    test -s /usr/share/keyrings/cloud.google.gpg
fi
apt-get update
'

reportResults
