#!/bin/bash

#set -x

# source https://github.com/aws/aws-app-mesh-examples/blob/master/walkthroughs/howto-k8s-http2/deploy.sh
display_usage() {
    echo -e "\nPresumes you have set AWS_ACCOUNT_ID and AWS_REGION (or AWS_DEFAULT_REGION) as environment varaibles \n"
    echo -e "\nYou must also have " \
        "eksctl, helm, kubectl, operator-sdk and aws-cli-2 installed and aws configured with your access key and secret. " \
        "See scripts in helper-scripts for installation.\n"
    echo -e "Usage:\n$0 \n"
}

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ACCOUNT_ID not set"
    display_usage
    exit 1
fi

if [ -z "$AWS_REGION" ]; then
    if [ -z "$AWS_DEFAULT_REGION" ]; then
        echo "AWS_REGION not set"
        display_usage
        exit 1
    else
        AWS_REGION=$AWS_DEFAULT_REGION
    fi
fi

# check whether user had supplied -h or --help . If yes display usage
if [[ ( $# == "--help") ||  $# == "-h" ]]; then
    display_usage
    exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

PROJECT_NAME_ROOT="pdf"
UNIQUEISH_ID=$(uuidgen | awk -F "-" '{ print $1 }')
PROJECT_NAME="$PROJECT_NAME_ROOT-$UNIQUEISH_ID"
APP_NAMESPACE="ns-$PROJECT_NAME"
SSH_PUB_KEY="~/.ssh/id_rsa.pub" #$1

#if no cluster name, this script will create
get_cluster() {
    if  [ -z "$EKS_CLUSTER_NAME" ]; then
        export EKS_CLUSTER_NAME="eks-$PROJECT_NAME"
        eksctl create cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION \
        --with-oidc --ssh-access --ssh-public-key $SSH_PUB_KEY \
        --managed
    else
        echo "EKS_CLUSTER_NAME was set to $EKS_CLUSTER_NAME; presumed to exist"
    fi
}

deploy_olm() {
    echo "installing olm"
    operator-sdk olm install
    echo "creating the default namespace for olm 'og-single'"
    kubectl apply -f operatorgroup.yaml
}

main() {
    get_cluster

    export KUBECONFIG="~/.kube/eksctl/clusters/$EKS_CLUSTER_NAME"

    deploy_olm

    echo -e "\n\nProject info:"
    echo "PROJECT_NAME=$PROJECT_NAME"
    echo "UNIQUEISH_ID=$UNIQUEISH_ID"
    echo "SSH_PUB_KEY=$SSH_PUB_KEY"
    echo "ENABLE_APPMESH=$ENABLE_APPMESH"
    echo "EKS_CLUSTER_NAME=$EKS_CLUSTER_NAME"
    echo "KUBECONFIG=$KUBECONFIG"

    echo -e "\nWhen you want to destroy the cluster, you can use" \
        "'eksctl delete cluster $EKS_CLUSTER_NAME'. However, you may need" \
        "to do other clean up like here: https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html"
    echo -e "\nBe sure to run \"export KUBECONFIG=$KUBECONFIG\" to" \
        "enable kubectl with the new cluster\n"
}

main