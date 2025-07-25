#!/usr/bin/env bash

# Copyright 2019 The Tekton Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script calls out to scripts in tektoncd/plumbing to setup a cluster
# and deploy Tekton Pipelines to it for running integration tests.

source $(dirname $0)/e2e-common.sh
# Script entry point.

# Setting defaults
failed=0

SKIP_INITIALIZE=${SKIP_INITIALIZE:="false"}
export SKIP_SECURITY_CTX=${SKIP_SECURITY_CTX:="false"}
export SKIP_KNATIVE_EG=${SKIP_KNATIVE_EG:="false"}

if [ "${SKIP_INITIALIZE}" != "true" ]; then
  initialize $@
fi

header "Setting up environment"
install_pipeline_crd
install_triggers_crd

header "Running yaml tests"
$(dirname $0)/e2e-tests-yaml.sh || { failed=1 && echo "failed yaml tests"; }

header "Running ingress tests"
$(dirname $0)/e2e-tests-ingress.sh || { failed=1 && echo "failed ingress tests"; }

# Run the integration tests
header "Running Go e2e tests"
go_test_e2e -timeout=20m ./test || { failed=1 && echo "failed integration tests"; }
go_test_e2e -timeout=20m ./cmd/... || { failed=1 && echo "failed integration tests"; }


header "Running examples tests"
$(dirname $0)/e2e-tests-examples.sh || { failed=1 && echo "failed example tests"; }

(( failed )) && fail_test
success
