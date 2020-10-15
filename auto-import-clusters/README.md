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

