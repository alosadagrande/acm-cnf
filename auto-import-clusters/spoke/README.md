# Intructions

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
