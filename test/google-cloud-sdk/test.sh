#!/bin/bash

set -e

source dev-container-features-test-lib

check "install google-cloud-sdk" gcloud --version | grep "Google Cloud SDK"

reportResults