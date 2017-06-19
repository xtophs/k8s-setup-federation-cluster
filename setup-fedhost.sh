#!/bin/bash

#
# setup.sh
#

if [[ $# != 2 ]]; then
    echo Usage: setup-fedhost.sh [cluster name] [zoneName]
    exit 1
fi  

kubectl config use-context ${1}

binding=$(kubectl get clusterrolebinding permissive-binding)
if [[ -z $binding ]]; then
  echo creating permissive binding. NOT recommended for production clusters
  kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=client --group=system:serviceaccounts
fi

result=$(grep 'authorization-mode=RBAC' /etc/kubernetes/manifests/kube-apiserver.yaml)
if [[ -z $result ]]; then
  echo Kube API server not configured for RBAC
  echo add --authorization-mode=RBAC to the hyperkube startup args in /etc/kubernetes/manifests/kube-apiserver.yaml
  echo end then reboot
  exit 1
fi

cluster=${1}
fedName=myfederation

set -e

if [ ! -f kubernetes-client-linux-amd64.tar.gz ]; then
  curl -LO https://dl.k8s.io/v1.7.0-alpha.4/kubernetes-client-linux-amd64.tar.gz
  tar xzf kubernetes-client-linux-amd64.tar.gz
  sudo cp kubernetes/client/bin/kubefed /usr/local/bin
  sudo chmod +x /usr/local/bin/kubefed
  sudo cp kubernetes/client/bin/kubectl /usr/local/bin
  sudo chmod +x /usr/local/bin/kubectl
fi

wd=$(pwd)
kubefed init ${fedName} --dns-provider="azure-azuredns" --dns-zone-name=${2} --dns-provider-config=${wd}/dns.conf --image=xtoph/hyperkube-amd64:azuredns.20 --controllermanager-arg-overrides="--v=5"

# double check
ns=$(kubectl get namespace --context=myfederation)
if [[ -n $binding ]]; then
  kubectl create namespace default --context=${fedName}
fi

kubectl config use-context ${fedName}
kubefed join ${cluster} --host-cluster-context=${cluster} --cluster-context=${cluster}

if [[ ! -d ./hostname ]]; then 
  git clone https://github.com/OguzPastirmaci/hostname
fi 

kubectl get clusters

echo export KUBECONFIG=~/.kube/config >> .bashrc

echo SUCCESS
