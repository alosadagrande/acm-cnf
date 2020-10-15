# ACM & Performance Addon Operator

## Installation

Performance Addon Operator installation is done using ACM policies which ensures the following objects must exist in the spoke or imported cluster:

* A namespace (openshift-performance-addon) where the operator will be executed 
* Operator installation by creating the  `operatorgroup` and `subscription` objects
* A specific `machineconfigpool` for CNF capable workers. This pool will match workers with role cnf-worker but can be whatever suits you best.

In order to apply the policy a ` PlacementRule` is required so that we can target from all our imported clusters the ones that require this policy to be install or said differently, the ones that requires the Performance Addon operator installed. In our case we will target clusters that contain the label **pao=true** added.

First thing, in our hub cluster create the openshift-performance-addon namespace:

```sh
$ oc create ns openshift-performance-addon
namespace/openshift-performance-addon created
```
Then, inside the openshift-performance-addon namespace, apply the policy which will create the placementrule and placementrulebinding as well.

```sh
$ oc create -f policy-pao-operator-46.yaml 
policy.policy.open-cluster-management.io/policy-pao-operator created
placementbinding.policy.open-cluster-management.io/binding-policy-pao created
placementrule.apps.open-cluster-management.io/placement-policy-pao created
```

Verify the policy is created:

```sh
$ oc get policy -n openshift-performance-addon
NAME                  AGE
policy-pao-operator   7d19h
```

> :warning: If you go to the spoke cluster you will notice the operator is not installed. Even the namespace was not created. That's because we forgot to label our spoke cluster in ACM to match the placementRule label (pao=true)

Next, let's label the imported cluster by connecting to the ACM user interface and add a label to a cluster or via CLI into the managedClusters object. Remember to set label as pao=true.

```sh
$ oc get managedClusters -o yaml cnf10
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  creationTimestamp: "2020-10-06T12:01:48Z"
  finalizers:
  - open-cluster-management.io/managedclusterrole
  - cluster.open-cluster-management.io/api-resource-cleanup
  - agent.open-cluster-management.io/klusterletaddonconfig-cleanup
  - managedclusterinfo.finalizers.open-cluster-management.io
  - managedcluster-import-controller.open-cluster-management.io/cleanup
  generation: 2
  labels:
    cloud: Other
    clusterID: be3d5065-e852-4702-b4b7-81a9f65e897e
    environment: stage
    name: cnf10
    pao: "true"
    ptp: "true"
    sriov: "true"
    vendor: OpenShift
```

Once the spoke cluster is labelled the policy will have a target cluster to enforce it. Then check that the different objects were created successfully in the target cluster:

```sh
$ oc get pods,operatorgroup,subscription.operators.coreos.com,mcp -n openshift-performance-addon
NAME                                        READY   STATUS    RESTARTS   AGE
pod/performance-operator-5668d87d74-9jkd2   1/1     Running   0          7d

NAME                                                            AGE
operatorgroup.operators.coreos.com/performance-addon-operator   7d19h

NAME                                                           PACKAGE                      SOURCE                       CHANNEL
subscription.operators.coreos.com/performance-addon-operator   performance-addon-operator   performance-addon-operator   4.6

NAME                                                             CONFIG                                                 UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
machineconfigpool.machineconfiguration.openshift.io/master       rendered-master-8c55ecb54824e28391c5c144b3fc9244       True      False      False      3              3                   3                     0                      9d
machineconfigpool.machineconfiguration.openshift.io/worker       rendered-worker-cfbd41056108b83f3a52eae8c7acf303       True      False      False      2              2                   2                     0                      9d
machineconfigpool.machineconfiguration.openshift.io/worker-cnf   rendered-worker-cnf-f1078562e383cf87e9bd4cea93efcd3c   True      False      False      0              0                   0                     0                      7d19h
```

> :exclamation: Notice the machineconfigpool was created but there is not any node matching the role worker-cnf. This will be addressed in the configuration part.

## Configuration

Configuration of the PAO is done using RHACM gitOps approach. The performance profile is located in a Git repository and RHACM applies it on a regular basis. Therefore, in order to change the performance profile it must be done through a Git workflow.

