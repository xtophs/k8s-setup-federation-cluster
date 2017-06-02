#!/bin/bash

set -e

cd kubernetes-cluster-federation

kubectl config use-context host-cluster

#TODO: Parameter validation

if [ -z $1 ];
then
 echo no cluster name. Exiting.
 exit 1
fi

cluster=${1}

echo setting up admin user
kubectl config set-credentials admin --kubeconfig kubeconfigs/${cluster}/kubeconfig

client_key_data=$(cat kubeconfigs/${cluster}/kubeconfig | grep client-key-data | cut -d' ' -f6-)
client_cert_data=$(cat kubeconfigs/${cluster}/kubeconfig | grep client-certificate-data | cut -d' ' -f6-)
server=$(cat kubeconfigs/${cluster}/kubeconfig | grep server | cut -d' ' -f6-)

echo setting client key data
kubectl config set users.admin.client-key-data \
    ${client_key_data} \
    --kubeconfig=kubeconfigs/${cluster}/kubeconfig

echo setting client certificate data
kubectl config set users.admin.client-certificate-data \
    ${client_cert_data} \
    --kubeconfig=kubeconfigs/${cluster}/kubeconfig

kubectl config set-context default \
    --cluster=${cluster} \
    --user=admin \
    --kubeconfig=kubeconfigs/${cluster}/kubeconfig

kubectl config use-context default \
    --kubeconfig=kubeconfigs/${cluster}/kubeconfig
    
cat > clusters/${cluster}.yaml <<EOF
apiVersion: federation/v1beta1
kind: Cluster
metadata:
  name: ${cluster}
spec:
  serverAddressByClientCIDRs:
    - clientCIDR: "0.0.0.0/0"
      serverAddress: "${server}"
  secretRef:
    name: ${cluster}
EOF

kubectl create secret generic ${cluster} \
    --from-file=kubeconfigs/${cluster}/kubeconfig

kubectl config use-context federation-cluster

kubectl create -f clusters/${cluster}.yaml

kubectl get clusters

echo SUCCESS

echo kubectl get clusters 


