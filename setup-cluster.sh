#!/bin/bash

#
# setupcluster.sh
#

set -e

if [[ $# != 4 ]]; then
    echo Usage: setup-cluster [azure region] [resource group name] [path to cluster ARM template] [cluster name]
    exit 1
fi  

# arguments
# 1: region
# 2: rg name 
# 3: path to cluster ARM templates
# 4: cluster name

az group create -l ${1} -n ${2}

az group deployment create --template-file ${3}/azuredeploy.json --parameters @${3}/azuredeploy.parameters.json -g ${2}

if [ ! -f ~/.ssh/id_rsa ]; then
    echo no private SSH key. Exiting.
    exit 1
fi

if [ ! -f ./clouddns.conf ]; then
    echo no DNS provider config. Exiting.
    exit 1
fi


if [ ! -f ./setup.sh ]; then
    echo no federation setup script. Exiting.
    exit 1
fi

ipName=$(az resource list -g ${2} --resource-type Microsoft.Network/publicIPAddresses --query [0].name --out tsv) 
echo Found IP address $ipName

ipAddress=$(az resource show -g ${2} --resource-type Microsoft.Network/publicIPAddresses -n $ipName --query properties.ipAddress --out tsv)
echo Address is $ipAddress

sshTarget=azureuser@$ipAddress
rootPath=/home/azureuser
keyPath=$rootPath/.ssh/id_rsa
configPath=$rootPath/kubernetes-cluster-federation/clouddns.conf
scriptPath=$rootPath/setup.sh

echo copying SSH private key
scp -q ~/.ssh/id_rsa $sshTarget:$keyPath
ssh -q $sshTarget 'sudo chmod 400 '$keyPath

echo Cloning Repo
ssh -q $sshTarget "git clone https://github.com/kelseyhightower/kubernetes-cluster-federation.git"
scp -q ./clouddns.conf $sshTarget:$configPath

echo Copying setup scripts
scp -q ./setup.sh $sshTarget:$scriptPath
scp -q ./joincluster.sh $sshTarget:$rootPath/joincluster.sh

echo updating federation controller manager config
# TODO: use  REGISTRY and VERSION from the k8s build

scp -q ./federation-controller-manager.yaml $sshTarget:$rootPath/kubernetes-cluster-federation/deployments/ 

echo to set up federation dp:
echo ssh -q $sshTarget 
echo ./setup.sh ${4}
#scp -q $sshTarget:$rootPath/setup.log .

#ok=$(cat setup.log | grep SUCCESS )

#if [[ -z $ok ]];
# then
#     echo error setting up federation
#     tail setup.log 
#     exit 1 
# fi

#echo joining cluster federation
#ssh -q $sshTarget "$rootPath/joincluster.sh ${4} > joincluster.log 2>&1"
#scp -q $sshTarget:$rootPath/joincluster.log .

#cat joincluster.log