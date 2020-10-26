# Summary

The point here is to find a way to import already deployed OpenShift clusters into ACM using only the CLI. Therefore, it opens the possibility to automate the process of importing a large number of clusters using your favourites automating tools.

## Instructions

* First, go to the hub folder and follow the instructions detailed there.
* Second, go to the spoke folder and follow the instructions.

Finally, you should see your cluster imported by running from the hub cluster:

```sh
$ oc get managedclusters

NAME            HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE   AGE
cnf10           true                                  True     True        8d
cnf21           true                                  True     True        6h17m
local-cluster   true                                  True     True        27h

```

## Hub cluster

Apply those manifests to the hub cluster

Please ensure that you properly replace those values:

* spoke-cluster with the name of your cluster to be imported

Example:

```sh
$ export SPOKE_CLUSTER=cluster-cnf21
$ envsubst < spoke_definition.yaml | oc create -f -
```

## Spoke cluster

The easiest way to import a cluster is extracting the CRDs and import information from the HUB cluster itself.

> :warning: This information is created once the managedcluster resource is applied.

**SPOKE_CLUSTER** is the name of the managedCluster resource we created previously. These commands must be executed from the hub cluster:

```sh 
$ oc get secret $SPOKE_CLUSTER-import -o "jsonpath={.data['crds\.yaml']}" -n $SPOKE_CLUSTER | base64 -d > crds.yaml 

```

```sh
$ oc get secret $SPOKE_CLUSTER-import -o "jsonpath={.data['import\.yaml']}" -n $SPOKE_CLUSTER | base64 -d > import.yaml
```

Finally, apply `crds.yaml` and `import.yaml` manifest in the spoke cluster you want to be imported.
