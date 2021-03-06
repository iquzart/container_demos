#!/bin/bash
# ./getmekube.sh dzdemo int we a m 1.10.9
echo "This script will create you a kubernetes cluster"

export cluster_name="$1"
export subscription="$2"
export cluster_region="$3"
export cni_type="$4"
export cluster_size="$5"
export kube_version="$6"

OUTPUT_PATH=$HOME/terra_out
TERRA_PATH=$HOME/lib/terraform/terraform
CONFIG_PATH=$HOME/config
VM_SIZE="Standard_D2s_v3"
VM_COUNT=3
KUBE_TEMPLATE_FILE=$PWD/terraform/azurecni.tf
SUBSCRIPTION_FILE=$CONFIG_PATH/variables_$subscription.tf
VARIABLE_FILE=$CONFIG_PATH/variables_common.tf

if [ "$subscription" == "" ]; then
echo "Subscription [int], [dev]?: "
read -n 3 subscription
echo
fi
SUBSCRIPTION_FILE=$CONFIG_PATH/variables_$subscription.tf

if [ "$cluster_region" == "" ]; then
echo "Region [we]westeurope, [ea]eastus, [ne]northeurope?: "
read -n 2 cluster_region
echo
fi

if [ "$cluster_region" == "ne" ]; then
cluster_region="NorthEurope"
elif [ "$cluster_region" == "ea" ]; then
cluster_region="EastUs"
else
cluster_region="WestEurope"
fi

if [ "$cluster_name" == "" ]; then
echo "Name of the cluster: "
read cluster_name
echo
fi

if [ "$cni_type" == "" ]; then
echo "What cni plugin [a]zure, [k]ubenet?: "
read -n 1 cni_type
echo
fi

if [ "$cni_type" == "k" ]; then
KUBE_TEMPLATE_FILE=$PWD/terraform/kubenet.tf
fi

if [ "$cluster_size" == "" ]; then
echo "Size of the cluster [s]mall, [m]edium, [l]arge?: "
read -n 1 cluster_size
echo
fi

if [ "$cluster_size" == "s" ]; then
VM_SIZE="Standard_B2s"
VM_COUNT=2
elif [ "$cluster_size" == "m" ]; then
VM_SIZE="Standard_D2s_v3"
VM_COUNT=3
else
VM_SIZE="Standard_D3s_v3"
VM_COUNT=4
fi

if [ "$kube_version" == "" ]; then
echo "Kubernetes version [1.10.9], [1.11.3], [1.11.4]?: "
read -n 6 kube_version
echo
fi

TERRAFORM_STORAGE_NAME=dzt$cluster_name
KUBE_RG="kub_ter_"$cni_type"_"$cluster_size"_"$cluster_name
LOCATION=$cluster_region

echo "Resource Group: $KUBE_RG"
echo "Terraform State: $TERRAFORM_STORAGE_NAME"
echo "Location: $LOCATION"
echo "$KUBE_TEMPLATE_FILE"
echo "$SUBSCRIPTION_FILE"

echo "using terraform version:"
$TERRA_PATH version

echo "initialzing terraform state storage..."
az group create -n $KUBE_RG -l $LOCATION

az storage account create --resource-group $KUBE_RG --name $TERRAFORM_STORAGE_NAME --location $LOCATION --sku Standard_LRS

TERRAFORM_STORAGE_KEY=$(az storage account keys list --account-name $TERRAFORM_STORAGE_NAME --resource-group $KUBE_RG --query "[0].value")

az storage container create -n tfstate --account-name $TERRAFORM_STORAGE_NAME --account-key $TERRAFORM_STORAGE_KEY

mkdir $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME

cp $SUBSCRIPTION_FILE $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME/variables.tf
cp $KUBE_TEMPLATE_FILE $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME

sed -e "s/VAR_AGENT_COUNT/$VM_COUNT/ ; s/VAR_KUBE_VERSION/$kube_version/ ; s/VAR_KUBE_NAME/$cluster_name/ ; s/VAR_KUBE_RG/$KUBE_RG/ ; s/VAR_KUBE_LOCATION/$LOCATION/" $VARIABLE_FILE >> $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME/variables.tf

less $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME/variables.tf
(cd $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME && $TERRA_PATH init -backend-config="storage_account_name=$TERRAFORM_STORAGE_NAME" -backend-config="container_name=tfstate" -backend-config="access_key=$TERRAFORM_STORAGE_KEY" -backend-config="key=codelab.microsoft.tfstate" )

(cd $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME && $TERRA_PATH plan -out $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME/out.plan)

(cd $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME && $TERRA_PATH apply $OUTPUT_PATH/$TERRAFORM_STORAGE_NAME/out.plan)

