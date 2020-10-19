# ACM & the SRIOV Network Operator

## Installation

The installation of SRIOV Network Operator (SRIOV Operator) is done using ACM policies which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Default namespace is `openshift-sriov-network-operator`
* Operator installation by creating the `operatorgroup` and `subscription` objects.
* The `SriovOperatorConfig` is modified so sriov-network-config-daemon daemonset only targets SRIOV capable nodes, which in our case are the node labelled as role worker-cnf.
* Proper CNF capable nodes labelled as role worker-cnf.
* Cluster network object is modified to add a dummy-dhcp-network required by SRIOV Network Operator.

In order to apply the policy named **policy-sriov-operator** a `PlacementRule` is required so that we can target from all our imported clusters the ones that require this policy to be installed or said differently, the ones that requires the SRIOV operator installed. In our case we will target clusters that contain the label **sriov=true** added.

First thing, in our hub cluster create the openshift-sriov-network-operator namespace:

```sh
$ oc create ns openshift-sriov-network-operator
namespace/openshift-sriov-network-operator created
```

Then, inside the openshift-sriov-network-operator namespace, apply the policy which will also create both the `placementrule` and `placementrulebinding`.

> :exclamation: Here we are using the operator for OpenShift 4.6. Since it is not released at the time of writing the Subscription object points to an internal catalogSource. You can take a look to `policy-sriov-operator.yaml` which is runnning operator 4.5 to see the differences. Just make sure once OpenShift 4.6 is GA you replace `Subscription.spec.source` to redhat-operators in the policy manifest.

```sh
$ oc create -f policy-sriov-operator-46.yaml 
policy.policy.open-cluster-management.io/policy-sriov-operator created
placementbinding.policy.open-cluster-management.io/binding-policy-sriov created
placementrule.apps.open-cluster-management.io/placement-policy-sriov created
```

Verify the policy is created:

```sh
$ oc get policy -n openshift-sriov-network-operator
NAME                    AGE
policy-sriov-operator   24s
```

> :warning: If you go to the spoke cluster you will notice the operator is not installed. Even the namespace was not created. That's because we forgot to label our spoke cluster in ACM to match the `placementRule` label (sriov=true)

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
$ oc get pods,operatorgroup,subscription.operators.coreos.com,SriovOperatorConfig
NAME                                          READY   STATUS    RESTARTS   AGE
pod/network-resources-injector-785t5          1/1     Running   0          11d
pod/network-resources-injector-969b6          1/1     Running   0          11d
pod/network-resources-injector-nt8tm          1/1     Running   0          11d
pod/operator-webhook-m4vz8                    1/1     Running   0          11d
pod/operator-webhook-mnx6p                    1/1     Running   0          11d
pod/operator-webhook-pdhs2                    1/1     Running   0          11d
pod/sriov-cni-mbg2m                           2/2     Running   0          11d
pod/sriov-cni-pqzlm                           2/2     Running   0          10d
pod/sriov-device-plugin-5xrdw                 1/1     Running   0          2d8h
pod/sriov-device-plugin-hbtb8                 1/1     Running   0          5h8m
pod/sriov-network-config-daemon-4f6d9         1/1     Running   0          10d
pod/sriov-network-config-daemon-8sbfm         1/1     Running   0          11d
pod/sriov-network-operator-789df4b87b-fk494   1/1     Running   0          11d

NAME                                                        AGE
operatorgroup.operators.coreos.com/sriov-network-operator   11d

NAME                                                                    PACKAGE                  SOURCE                       CHANNEL
subscription.operators.coreos.com/sriov-network-operator-subscription   sriov-network-operator   performance-addon-operator   4.6

NAME                                                    AGE
sriovoperatorconfig.sriovnetwork.openshift.io/default   11d
```


## Configuration

Configuration of the SRIOV Network Operator (SRIOV) is done using ACM GitOps approach. Actually, when we talk about SRIOV configuration we are referring to create or modify a couple of SRIOV related CRDs:

* [SRIOV Network object](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/sriov-network.yaml)
* [SRIOV Network Node Policy](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/sriov-network-node-policy-netdevice.yaml)
* Test executing a [pod](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/deployment-sriov-pod-test.yaml) requesting a VFS from a SRIOV capable node.

> :warning: `SriovNetworkNodePolicy` must be adapted to your environment since depends on the NIC model and NIC interface you are planning to use.

`SriovNetworkNodePolicy` and `SriovNetwork` are create in the hub `openshift-sriov-network-operator` namespace. They are needed to expose the SRIOV Virtual Functions (VFs) to a pod that requires SRIOV features. In our case, we are planning to deploy a test pod that will make use of the SRIOV Network defined. Basically, it is created with two interfaces leveraging Multus integration: one is connected to the OpenShift network and the other will be directly connected to a SRIOV Virtual Function (VFs) of the physical server where the pod is running.

All configuration files: `SriovNetworkNodePolicy`, `SriovNetwork` and test-pod `Deployment` are stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change any of these files on a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it.

> :warning: If you already installed the Performance Addon Operator then you already have the worker-cnf machineConfigPool in place. Otherwise take a look to Performance Addon Operator policy where it the worker-cnf machineConfigPool is created

We need to create the proper ACM manifests to tell ACM where the `ptpConfig` files are locate and which cluster will be targetted. Note that these files are placed in the master branch since they are ACM specific.

```sh
$ git checkout master
$ cd acm-manifests/sriov-operator/stage
```
Connect to the hub cluster:

```sh
$ oc project openshift-sriov-network-operator
$ oc apply -f channel-sriov.yaml
$ oc apply -f app-subs-sriov.yaml
$ oc apply -f placement-stage-clusters.yaml
```
> :exclamation: Notice that you must have an imported cluster labelled as environment=stage to let ACM which is/are the clusters where the PTP configuration files must be applied.

Verify in your hub cluster that those resources are correctly created and propagated:

```sh
$ oc get channel,application,placementrule

NAME                                                           TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/sriov-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   11d

NAME                                     TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/sriov-app-stage                                    11d

NAME                                                                   AGE   REPLICAS
placementrule.apps.open-cluster-management.io/placement-policy-sriov   32m   
placementrule.apps.open-cluster-management.io/stage-clusters           11d   
```

Notice that there are two placementrules. The one required to install SRIOV Network Operator whose target clusters are labelled as sriov=true and the new one which is required to apply the stage configuration to stage clusters actually labelled as environment=stage.

Lastly we can verify that the `ptpConfig` manifest has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployables 
NAME                                                                                          TEMPLATE-KIND            TEMPLATE-APIVERSION                  AGE   STATUS
sriov-subscription-operator-deployable                                                        Subscription             apps.open-cluster-management.io/v1   11d   Propagated
sriov-subscription-operator-operator-sriov-sriov-network-node-policy-sriovnetworknodepolicy   SriovNetworkNodePolicy   sriovnetwork.openshift.io/v1         11d   
sriov-subscription-operator-operator-sriov-sriov-network-sriovnetwork                         SriovNetwork             sriovnetwork.openshift.io/v1         11d   
sriov-subscription-operator-operator-sriov-sriov-pod-test-deployment                          Deployment               apps/v1                              11d   
```

Next, move to your **spoke** cluster where SRIOV configuration is targeted and notice that a two SRIOV Network Policies are shown. The one called sriov-network-node-policy is the applied. See that a SRIOV Network is created along with a test pod which is in Running state. 

> :exclamation: The sriov-pod-test in Running state allows us to verify quickly that the SRIOV configuration is set up correctly.

```sh 
$ oc get sriovnetworknodepolicy,sriovnetwork,deployment -n openshift-sriov-network-operator

NAME                                                                         AGE
sriovnetworknodepolicy.sriovnetwork.openshift.io/default                     11d
sriovnetworknodepolicy.sriovnetwork.openshift.io/sriov-network-node-policy   11d

NAME                                                   AGE
sriovnetwork.sriovnetwork.openshift.io/sriov-network   11d

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/sriov-network-operator   1/1     1            1           11d
deployment.apps/sriov-pod-test           1/1     1            1           11d
```

Finally you can verify that the test pod is connected to the host network using the SRIOV Network Virtual Function. Notice that the physical network address available is 172.22.0.0/24. See there are three interfaces: local, OpenShift network and the physical one exposed as a SRIOV VF.

```sh
oc rsh sriov-pod-test-59cf8bdf74-927zt ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if69: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:87:01:42 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.135.1.66/23 brd 10.135.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::858:aff:fe87:142/64 scope link 
       valid_lft forever preferred_lft forever
25: net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether f6:fa:a1:bd:70:60 brd ff:ff:ff:ff:ff:ff
    inet 172.22.0.208/24 brd 172.22.0.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::f4fa:a1ff:febd:7060/64 scope link 
       valid_lft forever preferred_lft forever
```






