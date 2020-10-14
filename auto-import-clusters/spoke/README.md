Please ensure that you properly replace those values in the env.sh script for the proper ones in your environment:

* SPOKE_CLUSTER
* DEPLOYMENT_IMAGE
* KLUSTERLET_REG_IMAGE
* KLUSTERLET_WORK_IMAGE
* KUBECONFIG_HUB

Then run the following resources:

```sh
$ source ./env.sh
$ envsubst < v210_endpoint-crd.yaml | oc apply -f -
$ envsubst < v212_klusterlet_config.yaml | oc apply -f -
$ envsubst < v214_bootstrap_secret.yaml | oc apply -f -
```

NOTE: These resources are based on ACM v2.1. In order to clean the import of a cluster, please execute: https://github.com/ch-stark/acminstall/blob/master/scripts/crc-cleanendpoint
