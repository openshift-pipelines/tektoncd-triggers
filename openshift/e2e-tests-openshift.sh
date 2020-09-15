#!/usr/bin/env bash

set -e
source $(dirname $0)/../vendor/github.com/tektoncd/plumbing/scripts/e2e-tests.sh
source $(dirname $0)/resolve-yamls.sh
source $(dirname $0)/pipeline-latest-release.sh

set -x

readonly API_SERVER=$(oc config view --minify | grep server | awk -F'//' '{print $2}' | awk -F':' '{print $1}')
readonly OPENSHIFT_REGISTRY_PREFIX="${OPENSHIFT_REGISTRY_PREFIX:-${IMAGE_FORMAT//:\$\{component\}/}}"
readonly TEST_NAMESPACE=tekton-triggers-tests
readonly TEKTON_TRIGGERS_NAMESPACE=tekton-pipelines
readonly KO_DOCKER_REPO=image-registry.openshift-image-registry.svc:5000/tektoncd-triggers
# Where the CRD will install the triggers
readonly TEKTON_NAMESPACE=tekton-pipelines
# Variable usually set by openshift CI but generating one if not present when running it locally
readonly OPENSHIFT_BUILD_NAMESPACE=${OPENSHIFT_BUILD_NAMESPACE:-tektoncd-build-$$}
# Yaml test skipped due of not being able to run on openshift CI, usually becaus
# of rights.
# test-git-volume: `"gitRepo": gitRepo volumes are not allowed to be used]'
declare -ar SKIP_YAML_TEST=(test-git-volume)

function install_pipeline_crd() {
  local latestreleaseyaml
  echo ">> Deploying Tekton Pipelines"
  if [[ -n ${RELEASE_YAML} ]];then
	latestreleaseyaml=${RELEASE_YAML}
  else
      echo "RELEASE_YAML_NOT_SET"
      exit 1
  fi
  [[ -z ${latestreleaseyaml} ]] && fail_test "Could not get latest released release.yaml"
  kubectl apply -f ${latestreleaseyaml} ||
    fail_test "Build pipeline installation failed"

  # Make sure thateveything is cleaned up in the current namespace.
  for res in pipelineresources tasks pipelines taskruns pipelineruns; do
    kubectl delete --ignore-not-found=true ${res}.tekton.dev --all
  done

  # Wait for pods to be running in the namespaces we are deploying to
  wait_until_pods_running tekton-pipelines || fail_test "Tekton Pipeline did not come up"
}

function install_tekton_triggers() {
  header "Installing Tekton Triggers"

  create_triggers

  wait_until_pods_running $TEKTON_TRIGGERS_NAMESPACE || return 1

  header "Tekton Triggers Installed successfully"
}

function create_triggers() {
  resolve_resources config/ tekton-triggers-resolved.yaml "nothing" $OPENSHIFT_REGISTRY_PREFIX
  oc apply -f tekton-triggers-resolved.yaml
}

function create_test_namespace() {
  for ns in ${TEKTON_NAMESPACE} ${OPENSHIFT_BUILD_NAMESPACE} ${TEST_NAMESPACE};do
     oc get project ${ns} >/dev/null 2>/dev/null || oc new-project ${ns}
  done

  oc policy add-role-to-group system:image-puller system:serviceaccounts:$TEST_NAMESPACE -n $OPENSHIFT_BUILD_NAMESPACE
}

install_pipeline_crd

create_test_namespace

[[ -z ${E2E_DEBUG} ]] && install_tekton_triggers


function run_go_e2e_tests() {
  header "Running Go e2e tests"
  go test -v -count=1 -tags=e2e -timeout=20m ./test --kubeconfig $KUBECONFIG || return 1
}

run_go_e2e_tests || failed=1

((failed)) && exit 1

success
