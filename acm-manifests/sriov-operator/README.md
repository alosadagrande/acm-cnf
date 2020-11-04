# ACM & the SR-IOV Network Operator

## Installation

The installation of SR-IOV Network Operator (SR-IOV Operator) is done using ACM policies which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Default namespace is `openshift-sriov-network-operator`
* Operator installation by creating the `operatorgroup` and `subscription` objects.
* The `SriovOperatorConfig` is modified so sriov-network-config-daemon daemonset only targets SRIOV capable nodes, which in our case are the node labelled as role worker-cnf.
* Proper CNF capable nodes labelled as role worker-cnf.
* Cluster network object is modified to add a dummy-dhcp-network required by SR-IOV Network Operator. This could come in handy if we want to assign IPs (L3) to pods' VFs.

In order to apply the policy named **policy-sriov-operator** a `PlacementRule` is required so that we can target from all our imported clusters the ones that require this policy to be installed or said differently, the ones that requires the SRIOV operator installed. In our case we will target clusters that contain the label **sriov=true** added.

First thing, in our hub cluster create the openshift-sriov-network-operator namespace:

```sh
$ oc create ns openshift-sriov-network-operator
namespace/openshift-sriov-network-operator created
```
Then, inside the openshift-sriov-network-operator namespace, apply the policy which will install the operator and also create both the `placementrule` and `placementrulebinding`.

> :exclamation: At the time of writing last channel for SR-IOV operator is 4.6 since latest GA version of OpenShift is 4.6.

```sh
$ oc create -f policy-sriov-operator.yaml 
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

Next, let's label the imported cluster by connecting to the ACM user interface and add a label to a cluster. You can also use oc CLI and modify the proper `managedCluster` object. Remember to set label as sriov=true.

```sh
$ oc patch managedClusters cnf10 --type=merge -p '{"metadata":{"labels":{"sriov":"true"}}}'
managedcluster.cluster.open-cluster-management.io/cnf10 patched
```

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
pod/network-resources-injector-54jxn          1/1     Running   0          7m26s
pod/network-resources-injector-5ckgr          1/1     Running   0          7m26s
pod/network-resources-injector-8rhlf          1/1     Running   0          7m26s
pod/operator-webhook-csfcw                    1/1     Running   0          7m26s
pod/operator-webhook-k22s4                    1/1     Running   0          7m26s
pod/operator-webhook-zkgpk                    1/1     Running   0          7m26s
pod/sriov-network-config-daemon-rq76v         1/1     Running   0          3m28s
pod/sriov-network-config-daemon-twpq7         1/1     Running   0          2m53s
pod/sriov-network-operator-5f9bc55cf6-dw7l6   1/1     Running   0          7m55s

NAME                                                         AGE
operatorgroup.operators.coreos.com/sriov-network-operators   8m36s

NAME                                                                    PACKAGE                  SOURCE             CHANNEL
subscription.operators.coreos.com/sriov-network-operator-subscription   sriov-network-operator   redhat-operators   4.6

NAME                                                    AGE
sriovoperatorconfig.sriovnetwork.openshift.io/default   7m29s
```

## Configuration

Configuration of the SR-IOV Network Operator (SR-IOV) is done using ACM GitOps approach. Actually, when we talk about SR-IOV configuration we are referring to create or modify a couple of SR-IOV related CRDs:

* SR-IOV Network objects. In our case since we are creating two SR-IOV networks, [mid haul](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/sriov-network-mh.yaml) and [front haul SR-IOV Network](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/sriov-network-fh.yaml)
* SR-IOV Network Node Policy. We need as well to create two `SriovNetworkNodePolicies` to configure each `SriovNetwork` defined previously.
* Test executing a [pod](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/deployment-sriov-pod-test.yaml) requesting a VFS from both SR-IOV Networks defined.

> :warning: `SriovNetworkNodePolicy` must be adapted to your environment since depends on the NIC model and NIC interface you are planning to use.

`SriovNetworkNodePolicy` and `SriovNetwork` are created in the hub `openshift-sriov-network-operator` namespace. They are needed to expose the SR-IOV Virtual Functions (VFs) to a pod that requires SR-IOV features. In our case, we are planning to deploy a test pod that will make use of the SR-IOV networks defined. Basically, it is a pod created with three interfaces leveraging Multus integration: one is connected to the OpenShift network and the other two will be directly connected to a SR-IOV Virtual Function (VFs) of the physical server where the pod is running.

All configuration files: `SriovNetworkNodePolicy`, `SriovNetwork` and test-pod `Deployment` are stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change any of these files on a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it.

> :warning: If you already installed the Performance Addon Operator then you already have the worker-cnf machineConfigPool in place. Otherwise take a look to Performance Addon Operator policy where it the worker-cnf machineConfigPool is created

We need to create the proper ACM manifests to tell ACM where the confguration files are locate and which cluster will be targetted. Note that these files are placed in the master branch since they are ACM specific.

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

> :exclamation: Note that the objects propagated are the ones included in the [kustomize.yaml](https://github.com/alosadagrande/acm-cnf/blob/stage/operator/sriov/kustomization.yaml) file. Feel free to add or remove objects from there depending on your needs.

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

Notice that there are two placementrules. The one required to install SR-IOV Network Operator whose target clusters are labelled as sriov=true and the new one which is required to apply the stage configuration to stage clusters actually labelled as environment=stage.

Lastly, we can verify that the SR-IOV Network and SR-IOV Network Node Policy manifests have been propagated correctly as well from the Git branch repository to the target clusters. Also, a test application is deployed to verify that SR-IOV is correctly configured.

```sh
$ oc get deployables
NAME                                                                                             TEMPLATE-KIND            TEMPLATE-APIVERSION                  AGE   STATUS
sriov-subscription-operator-deployable                                                           Subscription             apps.open-cluster-management.io/v1   5s    Propagated
sriov-subscription-operator-operator-sriov-sriov-network-fh-sriovnetwork                         SriovNetwork             sriovnetwork.openshift.io/v1         2s    
sriov-subscription-operator-operator-sriov-sriov-network-mh-sriovnetwork                         SriovNetwork             sriovnetwork.openshift.io/v1         2s    
sriov-subscription-operator-operator-sriov-sriov-network-node-policy-fh-sriovnetworknodepolicy   SriovNetworkNodePolicy   sriovnetwork.openshift.io/v1         2s    
sriov-subscription-operator-operator-sriov-sriov-network-node-policy-mh-sriovnetworknodepolicy   SriovNetworkNodePolicy   sriovnetwork.openshift.io/v1         2s    
sriov-subscription-operator-operator-sriov-sriov-pod-test-deployment                             Deployment               apps/v1                              2s 
```
> :warning: Once we applied the configuration, the worker nodes will need to be configured. So probably you will see them moving from Ready to a non Ready status

Next, move to your **spoke** cluster where SR-IOV configuration is targeted and notice that a three SR-IOV Network Policies are shown. The ones called sriov-network-node-policy-mh and sriov-network-node-policy-fh are the applied ones. See that a SR-IOV Network is created along with a test pod which is in Running state. 

> :exclamation: The sriov-pod-test in Running state allows us to verify quickly that the SR-IOV configuration is set up correctly.

> :warning: In order to run test SR-IOV application we need to add the privileged SCC to default serviceAccount or even better, we can create a new serviceAccount in charge of running test application with privileged permissions

```sh 
$ oc get sriovnetworknodepolicy,sriovnetwork,deployment -n openshift-sriov-network-operator

NAME                                                                            AGE
sriovnetworknodepolicy.sriovnetwork.openshift.io/default                        101m
sriovnetworknodepolicy.sriovnetwork.openshift.io/sriov-network-node-policy-fh   81m
sriovnetworknodepolicy.sriovnetwork.openshift.io/sriov-network-node-policy-mh   81m

NAME                                                      AGE
sriovnetwork.sriovnetwork.openshift.io/sriov-network-fh   81m
sriovnetwork.sriovnetwork.openshift.io/sriov-network-mh   81m

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/sriov-network-operator   1/1     1            1           101m
deployment.apps/sriov-pod-test           1/1     1            1           81m
```

Finally, you can verify that the test pod is connected to both host networks (net1,net2) using the SR-IOV Network Virtual Function. 

```sh
 oc rsh sriov-pod-test-57b458c754-v42gp
sh-4.2$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if292: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:84:02:75 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.132.2.117/23 brd 10.132.3.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::858:aff:fe84:275/64 scope link 
       valid_lft forever preferred_lft forever
162: net2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 4e:59:29:b9:05:78 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::4c59:29ff:feb9:578/64 scope link 
       valid_lft forever preferred_lft forever
229: net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d2:0a:89:de:2c:bc brd ff:ff:ff:ff:ff:ff
    inet6 fe80::d00a:89ff:fede:2cbc/64 scope link 
       valid_lft forever preferred_lft forever
```

> :exclamation: In this case there is no IP since the SR-IOV Network was set to layer-2 only. However, you can modify it to use IP (layer-3) capabilities.

```sh
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetwork
metadata:
  name: sriov-network-mh
  namespace: openshift-sriov-network-operator
spec:
  ipam: |-
    {}
  networkNamespace: openshift-sriov-network-operator
  resourceName: sriovnic0
  vlan: 101
  capabilities: '{ "mac": true, "ips": false }'
  ```
