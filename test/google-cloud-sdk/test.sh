#!/bin/bash

set -e

source dev-container-features-test-lib

check "gcloud --version" gcloud --version
check "gcloud is on PATH" bash -c "gcloud --version | grep -E 'Google Cloud SDK'"
check "gsutil" gsutil --version
check "bq" bash -c "bq version"

reportResults
