# Scripts for Cluster Federation Setup

Scripts based on @kelseyhightower's [Federation the hard way](https://github.com/kelseyhightower/kubernetes-cluster-federation).

They're useful for building / and dedugging dnsproviders

## Set up DNS
1. Create an Azure Resource Group
2. Add the DNS Zone for your federation. You should see a zone with an NS and an SOA record

## Create a Service Principal with access to the DNS service
1. Create an AAD Service Principal with Contributor access scoped to the resource group in which the DNS Zone is located (You could probably scope just to the DNS zone)
```az ad sp create-for-rbac -n "http://MyApp" --role contributor --scopes /subscriptions/[your subscription id]/resourceGroups/[your resource group]
```

Make note of `appId`, `password` and `tenant`. Those will need to go into the provider config file. 

## Federation Host Cluster
1. Setup a kubernetes cluster. The scripts assume you created an ARM templates using [acs-engine](https://github.com/Azure/acs-engine). `setup-cluster.sh` will create a resource group and then deploy the ARM template.  
2. Build a hyperkube running your DNS federation provider. You can clone the kubernetes repo, add your code, set `REGISTRY` and `VERSION` environment variables and then build the hyperkube by running `./hack/dev-push-hyperkube.sh`
3. Edit the `clouddns.conf` file in this folder with the configuration for your resource group and your service principal
```
[Global]
subscription-id = 
tenant-id = 
client-id = 
secret = 
resourceGroup = 
```
4. Run `setup-cluster.sh` with those parameters:
- location
- resource group name
- path to the ARM template 
5. ssh to the master and run `setup.sh [clustername]` with the cluster name (the dnsPrefix in the acs-engine API model) as the parameter
6. Still on the master, run `joincluster.sh [clustername]`, also with the cluster name as parameter
7. Deploy the ReplicaSet
- `kubectl create -f rs/nginx.yaml`
- Change the service file `services/nginx.yaml` to type `LoadBalancer`
- `kubectl create -f services/nginx.yaml`

In some cases, it takes a while for the federation-apiserver service to direct traffic to the apiserver container. You may see errors like: ```Could not find resources from API Server: Get https://federation-apiserver:443/api: dial tcp 10.0.206.126:443: i/o timeout``` and the federation API controller pod crashes. It may take several restarts of the pod until the federation apiserer is reachable.

## Add federated clusters
To join a 2nd cluster, create a plain cluster using acs engine or setup-cluster. Things get easier if you use the same private/public SSH keys for the clusters. Then:
1. ssh to the master where federation is set up
2. from the federation master, `scp` the `kubeconfig` from the other cluster, i.e. something like
```
mkdir -p /home/azureuser/kubernetes-cluster-federation/kubeconfigs/[2nd cluster name]
scp [2nd cluster ip]:/home/azureuser/.kube/config /home/azureuser/kubernetes-cluster-federation/kubeconfigs/[2nd cluster name]/kubeconfig
```
3. Run `./joincluster [2nd clustername]`
4. verify the 2nd cluster is joined
```
kubectl get clusters
```

# Known Issues
1. Deleting the Service does not clean up CNAME records. Appears to be a federation bug since it's happening with other DNS providers as well
2. Federated Clusters have to be in different Azure regions. Not sure yet what's going on there. 





