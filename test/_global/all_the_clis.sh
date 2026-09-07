#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "check for gcloud" gcloud --version
check "check for gsutil" gsutil --version
check "check for bq" bash -c "bq version"

# Report result
reportResults
