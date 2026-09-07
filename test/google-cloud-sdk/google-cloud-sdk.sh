#!/bin/bash

set -e

source dev-container-features-test-lib

check "gcloud --version" bash -c "gcloud --version | grep -E 'Google Cloud SDK'"
check "gsutil --version" bash -c "gsutil --version | grep -E 'gsutil version'"
check "login shell でも gcloud が使える" bash -lc "gcloud --version"

reportResults
