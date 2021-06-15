#!/bin/bash

#set -x

# source https://github.com/aws/aws-app-mesh-examples/blob/master/walkthroughs/howto-k8s-http2/deploy.sh
display_usage() {
    echo -e "\nPresumes you have set AZURE_REGION (or AZURE_DEFAULT_REGION) as environment varaibles \n"
    echo -e "\nYou must also have " \
        "az, kubectl, operator-sdk installed and aws configured with your access key and secret. " \
        "See scripts in helper-scripts for installation.\n"
    echo -e "Usage:\n$0 RESOURCE_GROUP \n"
}

# if one argument is not supplied, display usage
if [  $# != 1 ]; then
    echo "Please provide RESOURCE_GROUP, if it doesn't exist it will be created."
    display_usage
    exit 1
else
    export RESOURCE_GROUP=$1
fi

if [ -z "$AZURE_REGION" ]; then
    if [ -z "$AZURE_DEFAULT_REGION" ]; then
        echo "AZURE_REGION not set"
        display_usage
        exit 1
    else
        AZURE_REGION=$AZURE_DEFAULT_REGION
    fi
fi
#echo AZURE_REGION $AZURE_REGION
#echo AZURE_DEFAULT_REGION $AZURE_DEFAULT_REGION
export REGION=$AZURE_REGION

DEFAULT_SSH_PUB_KEY="~/.ssh/id_rsa.pub"
if [ -z "$SSH_PUB_KEY" ]; then
    if [ -z "$2" ]; then
        export SSH_PUB_KEY=$DEFAULT_SSH_PUB_KEY
    else
        export SSH_PUB_KEY=$2
    fi
else
    export SSH_PUB_KEY=$DEFAULT_SSH_PUB_KEY
fi
#echo SSH_PUB_KEY $SSH_PUB_KEY
#echo DEFAULT_SSH_PUB_KEY $DEFAULT_SSH_PUB_KEY

# check whether user had supplied -h or --help . If yes display usage
if [[ ( $# == "--help") ||  $# == "-h" ]]; then
    display_usage
    exit 0
fi

UNIQUEISH_ID=$(uuidgen | awk -F "-" '{ print $1 }')
CLUSTER_NAME=aks-$RESOURCE_GROUP
ACR_NAME="acr-$UNIQUEISH_ID$-$RESOURCE_GROUP"
#ACR_NAME  must conform to the following pattern: '^[a-zA-Z0-9]*$'
ACR_NAME=${ACR_NAME//-/}
echo ACR_NAME $ACR_NAME

get_resource_group() {
    echo Finding or creating Resource Group: $RESOURCE_GROUP
    if [ `az group exists --resource-group $RESOURCE_GROUP` == "false" ]; then
        az group create -l $REGION -n $RESOURCE_GROUP #|| :
    fi
}

get_container_registry() {
    echo Creating a container registry in $RESOURCE_GROUP called $ACR_NAME
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
}

get_cluster() {
    echo Creating aks: $CLUSTER_NAME in $RESOURCE_GROUP
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --node-count 2 \
        --ssh-key-value ~/.ssh/id_rsa.pub \
        --enable-managed-identity \
        --attach-acr $ACR_NAME
}

save_credentials() {
    DIR=$HOME/.kube/aks/clusters
    mkdir -p $DIR
    echo Writing kube config to $DIR/$CLUSTER_NAME
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --file $DIR/$CLUSTER_NAME
}

deploy_olm() {
    echo "installing olm"
    operator-sdk olm install
    echo "creating the default namespace for olm 'og-single'"
    kubectl apply -f operatorgroup.yaml
}

# PROJECT_NAME_ROOT="pdf"
# UNIQUEISH_ID=$(uuidgen | awk -F "-" '{ print $1 }')
# PROJECT_NAME="$PROJECT_NAME_ROOT-$UNIQUEISH_ID"
# APP_NAMESPACE="ns-$PROJECT_NAME"
# SSH_PUB_KEY="~/.ssh/id_rsa.pub" #$1

main() {
    get_resource_group
    get_container_registry
    get_cluster
    save_credentials
    export KUBECONFIG="$DIR/$CLUSTER_NAME"

    deploy_olm

    echo -e "\n
    Summary of Deployment:
    Region: $REGION
    Resource Group: $RESOURCE_GROUP
    Container Registry: $ACR_NAME
    Cluster Name: $CLUSTER_NAME

    Recommend running: export KUBECONFIG=$DIR/$CLUSTER_NAME
    "

    # echo -e "\n\nProject info:"
    # echo "PROJECT_NAME=$PROJECT_NAME"
    # echo "UNIQUEISH_ID=$UNIQUEISH_ID"
    # echo "SSH_PUB_KEY=$SSH_PUB_KEY"
    # echo "ENABLE_APPMESH=$ENABLE_APPMESH"
    # echo "EKS_CLUSTER_NAME=$EKS_CLUSTER_NAME"
    # echo "KUBECONFIG=$KUBECONFIG"

    # echo -e "\nWhen you want to destroy the cluster, you can use" \
    #     "'eksctl delete cluster $EKS_CLUSTER_NAME'. However, you may need" \
    #     "to do other clean up like here: https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html"
    # echo -e "\nBe sure to run \"export KUBECONFIG=$KUBECONFIG\" to" \
    #     "enable kubectl with the new cluster\n"
}

main