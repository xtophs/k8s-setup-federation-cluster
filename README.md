# Scripts for Cluster Federation Setup

Scripts based on @kelseyhightower's [Federation the hard way](https://github.com/kelseyhightower/kubernetes-cluster-federation).

They're useful for building / and dedugging dnsproviders

1. First setup a kubernetes cluster. The scripts assume you created an ARM templates using [acs-engine](https://github.com/Azure/acs-engine). `setup-cluster.sh` will create a resource group and then deploy the ARM template.  
2. Build a hyperkube running your DNS federation provider. You can clone the kubernetes repo, add your code, set `REGISTRY` and `VERSION` environment variables and then build the hyperkube by running `./hack/dev-push-hyperkube.sh`
3. Run `setup-cluster.sh` with those parameters:
- location
- resource group name
- path to the ARM template 
- OTHERS I NEED TO DOCUMENT