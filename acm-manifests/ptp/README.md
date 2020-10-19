# ACM & the PTP Operator

## Installation

The installation of PTP operator is done using ACM policies which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Default namespace is `openshift-ptp`
* Operator installation by creating the `operatorgroup` and `subscription` objects.
* The `PTPOperatorConfig` is modified so PTP daemonset only targets PTP capable nodes, which in our case are the node labelled as role worker-cnf.
* Proper CNF capable nodes labelled as role worker-cnf.

In order to apply the policy named **policy-ptp-operator** a `PlacementRule` is required so that we can target from all our imported clusters the ones that require this policy to be installed or said differently, the ones that requires the PTP operator installed. In our case we will target clusters that contain the label **ptp=true** added.

First thing, in our hub cluster create the openshift-performance-addon namespace:

```sh
$ oc create ns openshift-ptp
namespace/openshift-ptp created
```

Then, inside the openshift-ptp namespace, apply the policy which will create both the `placementrule` and `placementrulebinding`.

> :exclamation: Here we are using the operator for OpenShift 4.6. Since it is not released at the time of writing the Subscription object points to an internal catalogSource. You can take a look to `policy-ptp-operator.yaml` which is runnning operator 4.5 to see the differences. Just make sure once OpenShift 4.6 is GA you replace `Subscription.spec.source` to redhat-operators in the policy manifest.

```sh
$ oc create -f policy-ptp-operator-46.yaml 
policy.policy.open-cluster-management.io/policy-ptp-operator created
placementbinding.policy.open-cluster-management.io/binding-policy-ptp created
placementrule.apps.open-cluster-management.io/placement-policy-ptp created
```

Verify the policy is created:

```sh
$ oc get policy -n openshift-ptp
NAME                  AGE
policy-ptp-operator   35s
```

> :warning: If you go to the spoke cluster you will notice the operator is not installed. Even the namespace was not created. That's because we forgot to label our spoke cluster in ACM to match the `placementRule` label (ptp=true)

Next, let's label the imported cluster by connecting to the ACM user interface and add a label to a cluster. You can also use oc CLI and modify the proper `managedCluster` object. Remember to set label as ptp=true.

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
$Th oc get pods,operatorgroup,subscription.operators.coreos.com,ptpoperatorconfig -n openshift-ptp
NAME                              READY   STATUS    RESTARTS   AGE
pod/linuxptp-daemon-2pdvf         2/2     Running   0          10d
pod/linuxptp-daemon-7v6rk         2/2     Running   0          9d
pod/ptp-operator-5f76d96f-5dhgg   1/1     Running   0          11d

NAME                                               AGE
operatorgroup.operators.coreos.com/ptp-operators   11d

NAME                                                          PACKAGE        SOURCE                       CHANNEL
subscription.operators.coreos.com/ptp-operator-subscription   ptp-operator   performance-addon-operator   4.6

NAME                                         AGE
ptpoperatorconfig.ptp.openshift.io/default   11d
```




## Configuration

Specific configuration of PTP grandmaster and slaves are done using RHACM gitOps approach. The grandmaster profile and slave profile are stored and applied from Git.



