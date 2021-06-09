#!/usr/bin/env bash

# Run this script to get the outputs to put into the console deployment yaml
# Then deploy all of the YAML resources into the kube-system namespace

set -euo pipefail
set -x

CONSOLE_IMAGE=${CONSOLE_IMAGE:="quay.io/openshift/origin-console:latest"}
CONSOLE_PORT=${CONSOLE_PORT:=9000}
BRIDGE_USER_AUTH="disabled"
BRIDGE_K8S_MODE="off-cluster"
BRIDGE_K8S_AUTH="bearer-token"
CONSOLE_SERVICEACCOUNT="openshift-console"

# FIXME: this should not be the default...
BRIDGE_K8S_MODE_OFF_CLUSTER_SKIP_VERIFY_TLS=true

# user the service account from kube-system for auth
CONSOLE_SERVICE_ACCOUNT_NAMESPACE=${CONSOLE_SERVICE_ACCOUNT_NAMESPACE:=kube-system}
BRIDGE_K8S_MODE_OFF_CLUSTER_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
BRIDGE_K8S_AUTH_BEARER_TOKEN=$(kubectl get secret $(kubectl get serviceaccount $CONSOLE_SERVICEACCOUNT -n "$CONSOLE_SERVICE_ACCOUNT_NAMESPACE" -o jsonpath='{.secrets[0].name}') -n "$CONSOLE_SERVICE_ACCOUNT_NAMESPACE" -o jsonpath='{.data.token}' | base64 --decode )

echo "API Server: $BRIDGE_K8S_MODE_OFF_CLUSTER_ENDPOINT"
echo "Console Image: $CONSOLE_IMAGE"
echo "Console URL: http://localhost:${CONSOLE_PORT}"
echo
set | grep BRIDGE
#docker run --rm -p "$CONSOLE_PORT":9000 --env-file <(set | grep BRIDGE) $CONSOLE_IMAGE
