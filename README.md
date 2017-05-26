# Scripts for Cluster Federation Setup

Scripts based on @kelseyhightower's [Federation the hard way](https://github.com/kelseyhightower/kubernetes-cluster-federation).

They're useful for building / and dedugging dnsproviders

1. First setup a kubernetes cluster. The scripts assume you created an ARM templates using [acs-engine](https://github.com/Azure/acs-engine). `setup-cluster.sh` will create a resource group and then deploy the ARM template.  
2. Build a hyperkube running your DNS federation provider. You can clone the kubernetes repo, add your code, set `REGISTRY` and `VERSION` environment variables and then build the hyperkube by running `./hack/dev-push-hyperkube.sh`
3. Run `setup-cluster.sh` with those parameters:
- location
- resource group name
- path to the ARM template 
4. ssh to the master and run `setup.sh [clustername]` with the cluster name (the dnsPrefix in the acs-engine API model) as the parameter
5. Still on the master, run `joincluster.sh [clustername]`, also with the cluster name as parameter
6. Deploy the ReplicaSet
- kubectl create -f `rs/nginx.yaml`
- Change the service file `services/nginx.yaml` to type `LoadBalancer`
- kubectl create -f `services/nginx.yaml`

In some cases, it takes a while for the federation-apiserver service to direct traffic to the apiserver container. You may see errors like: ```Could not find resources from API Server: Get https://federation-apiserver:443/api: dial tcp 10.0.206.126:443: i/o timeout``` and the federation API controller pod crashes. It may take several restarts of the pod until the federation apiserer is reachable.

To join a 2nd cluster, create a plain cluster using acs engine or setup-cluster. Things get easier if you use the same private/public SSH keys for the clusters. Then:
1. ssh to the master where federation is set up
2. from the federation master, `scp` the `kubeconfig` from the other cluster, i.e. something like
```
scp [2nd cluster ip]:/home/azureuser/.kube/config /home/azureuser/kubernetes-cluster-federation/kubeconfigs/[2nd cluster name]/kubeconfig
```
3. Run ./joincluster [2nd clustername]
4. verify the 2nd cluster is joined
```
kubectl get clusters
```





