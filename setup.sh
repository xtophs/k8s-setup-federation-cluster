#!/bin/bash

#
# setup.sh
#

set -e

#TODO: Parameter validation

if [ -z $1 ];
then
 echo no cluster name. Exiting.
 exit 1
fi

cluster=${1}

cd kubernetes-cluster-federation

mkdir -p clusters
mkdir -p kubeconfigs
mkdir -p kubeconfigs/${cluster}

# protecting against 2nd run
# we want to grab the pristine kubeconfig without any of the federation entries
if [ ! -f kubeconfigs/${cluster}/kubeconfig ]
then
  cp ~/.kube/config kubeconfigs/${cluster}/kubeconfig
fi 

kubectl config use-context ${cluster}

nodes=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.role=="agent")].metadata.name}')
echo found $nodes

adminuser=$cluster-admin

for node in $nodes
do
  scp -q ./clouddns.conf $node:/tmp/clouddns.conf
done

echo configuring context
kubectl config set-context host-cluster \
  --cluster=$cluster \
  --user=${adminuser} \
  --namespace=federation

echo switching context
kubectl config use-context host-cluster

echo creating federation namespace
kubectl create -f ns/federation.yaml

echo created federation API server service
kubectl create -f services/federation-apiserver.yaml

echo creating federation token secret
FEDERATION_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > known-tokens.csv <<EOF
${FEDERATION_TOKEN},admin,admin
EOF

kubectl create secret generic federation-apiserver-secrets \
  --from-file=known-tokens.csv

echo creating persistent volume
kubectl create -f pvc/federation-apiserver-etcd.yaml

echo waiting for apiserver service to come up
count=0
while [ $count -lt 20 ]
do
    echo checking for service $count
    ip=$(kubectl get svc federation-apiserver -o jsonpath='{ .status.loadBalancer.ingress[0].ip }')
    if [ -z $ip ]; then
        sleep 60
        count=$((count + 1))
    else
        break
    fi
done

if [ -z $ip ];
then 
    echo api server service did not come up. Exiting
    exit 1
fi


echo setting up configmap with ${ip}
kubectl create configmap federated-apiserver \
  --from-literal=advertise-address=${ip}

kubectl get configmap federated-apiserver \
  -o jsonpath='{.data.advertise-address}'

echo spinning up federation server
kubectl create -f deployments/federation-apiserver.yaml

kubectl config set-cluster federation-cluster \
  --server=https://${ip} --insecure-skip-tls-verify=true

FEDERATION_TOKEN=$(cut -d"," -f1 known-tokens.csv)

kubectl config set-credentials federation-cluster \
  --token=${FEDERATION_TOKEN}

kubectl config set-context federation-cluster \
  --cluster=federation-cluster \
  --user=federation-cluster

kubectl config use-context federation-cluster

mkdir -p kubeconfigs/federation-apiserver

kubectl config view --flatten --minify > kubeconfigs/federation-apiserver/kubeconfig

kubectl config use-context host-cluster

kubectl create secret generic federation-apiserver-kubeconfig \
  --from-file=kubeconfigs/federation-apiserver/kubeconfig

# should be a parameter
export DNS_ZONE_NAME=xtophs.com

#has to be empty for Azure DNS
export DNS_ZONE_ID=

kubectl create configmap federation-controller-manager \
  --from-literal=zone-id=${DNS_ZONE_ID} \
  --from-literal=zone-name=${DNS_ZONE_NAME}

count=0
set +e 

while [ $count -lt 20 ]
do
    echo waiting for apiserver to get ready $count
    resp=$(curl -k https://${ip}:443)

    if [ "$resp" == "Unauthorized" ];
    then
        break
    fi 
    count=$((count + 1))
done

set -e
    
kubectl create -f deployments/federation-controller-manager.yaml

set +e 
count=0
while [ $count -lt 20 ]
do
    echo waiting for federation controller manager $count
    status=$(kubectl get pods -o jsonpath='{ .items[?(@.metadata.labels.module=="federation-controller-manager")].status.phase }')
    if [ "$status" == "Running" ];
    then
        break
    fi 
    sleep 60
    count=$((count + 1))
done

echo Federation Controller Manager Running
set -e
kubectl config use-context federation-cluster
mkdir -p configmaps
cat > configmaps/kube-dns.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  federations: federation=${DNS_ZONE_NAME}
EOF

count=0

set +e
while [ $count -lt 20 ]
do 
  result=$(kubectl create -f configmaps/kube-dns.yaml | grep created)
  if [ -n $result ]; then
    break
  fi
  count=$(( count + 1 ))
done

echo DNS configmap created
cat configmaps/kube-dns.yaml

echo SUCCESS
