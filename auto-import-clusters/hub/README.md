# Instructions

Apply those manifests to the hub cluster

Please ensure that you properly replace those values:

* spoke-cluster with the name of your cluster to be imported

Example:

```sh
$ export SPOKE_CLUSTER=cluster-cnf21
$ envsubst < spoke_definition.yaml | oc create -f -
```
