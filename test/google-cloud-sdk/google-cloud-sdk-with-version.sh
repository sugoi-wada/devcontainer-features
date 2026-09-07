#!/bin/bash

set -e

source dev-container-features-test-lib

check "指定したバージョンがインストールされている" bash -c "gcloud --version | grep -E 'Google Cloud SDK 520\.0\.0'"

reportResults
