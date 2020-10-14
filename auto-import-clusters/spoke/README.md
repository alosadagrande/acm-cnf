Apply those manifests on the cluster that you want to import.

Please ensure that you properly replace those values:

* DEPLOYMENT_IMAGE
* KLUSTERLET_REG_IMAGE
* KLUSTERLET_WORK_IMAGE
* KUBECONFIG_HUB
* v204_bootstrap_secret.yaml -> Replace KUBECONFIGHUB with your
base64-encodeded kubeconfig file from the cluster that
you want to import

In order to clean the import of a cluster, please execute:
https://github.com/ch-stark/acminstall/blob/master/scripts/crc-cleanendpoint
