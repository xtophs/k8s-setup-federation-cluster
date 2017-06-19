#!/bin/bash
#
# setupcluster.sh
#

set -e

if [[ $# != 5 ]]; then
    echo Usage: setup-cluster [azure region] [resource group name] [path to cluster ARM template] [cluster name] [zoneName]
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


confFile=dns.conf

if [ ! -f ./$confFile ]; then
    echo no DNS provider config. Exiting.
    exit 1
fi


if [ ! -f ./setup-fedhost.sh ]; then
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
configPath=$rootPath/kubernetes-cluster-federation/${confFile}
scriptPath=$rootPath/setup-fedhost.sh

ssh-keyscan $ipAddress >> ~/.ssh/known_hosts

echo copying SSH private key
scp ~/.ssh/id_rsa $sshTarget:$keyPath
ssh $sshTarget 'sudo chmod 400 '$keyPath

echo Copying setup scripts
configPath=$rootPath/${confFile}

scp ./${confFile} $sshTarget:$configPath
scp ./setup-fedhost.sh $sshTarget:$scriptPath

#ssh $sshTarget "./setup-fedhost.sh ${4} ${5} > setup.1.log 2>&1"
#ssh $sshTarget "sudo reboot"

echo to set up federation do:
echo ssh $sshTarget 
echo "./setup-fedhost.sh ${4} ${5} > setup.log 2>&1 &" 
echo
echo to JOIN Existing Federation 
echo ssh to where your federation contoller is running, then
echo scp $ipAddress:/home/azureuser/.kube/config ~/.kube/config.${cluster}
echo export KUBECONFIG=$KUBECONFIG:~/.kube/config.${cluster}
echo kubefed join ...
