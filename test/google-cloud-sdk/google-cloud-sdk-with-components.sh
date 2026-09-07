#!/bin/bash

set -e

source dev-container-features-test-lib

check "gcloud --version" bash -c "gcloud --version | grep -E 'Google Cloud SDK'"
check "gke-gcloud-auth-plugin がインストールされている" gke-gcloud-auth-plugin --version
check "kubectl がインストールされている" bash -c "kubectl version --client"

reportResults
