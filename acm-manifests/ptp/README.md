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

Configuration of the PTP Operator (PTP) is done using ACM GitOps approach. Actually, when we talk about PTP configuration we are referring to create or modify the `PTPConfig CRD` and creating two profiles: the grandmaster and the slave. Those PTP profiles are used by the linuxptp-daemon pods, which are actually deployed as a daemonSet, to set which node will perform the PTP master clock role and what nodes (slaves) are going to sync against the master clock.

Both `ptpConfig` profile is stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change the PTP profile of a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it.

> :warning: If you already installed the Performance Addon Operator then you already have the worker-cnf machineconfigpool in place.

First thing that must be done is label the PTP capable worker nodes as ptp/grandmaster and ptp/slaves. This can be done manually or using a policy targetting one cluster at a time:

```sh
$ oc create -f policy-label-cnf10-worker-nodes.yaml
```
> :exclamation: Note that the name of the nodes labelled in the policy will probably differ from yours. Note that this is a very specific policy since we need to know the name of nodes in advance or get that information from ACM. 

Next, we need to create the proper ACM manifests to tell ACM where the `ptpConfig` files are locate and which cluster will be targetted. Note that these files are placed in the master branch since they are ACM specific.

```sh
$ git checkout master
$ cd acm-manifests/ptp/stage
```
Connect to the hub cluster:

```sh
$ oc project openshift-ptp
$ oc apply -f channel-ptp.yaml
$ oc apply -f app-subs-ptp.yaml
$ oc apply -f placement-stage-clusters.yaml
```
> :exclamation: Notice that you must have an imported cluster labelled as environment=stage to let ACM which is/are the clusters where the PTP configuration files must be applied.

Verify in your hub cluster that those resources are correctly created and propagated:

```sh
$ oc get channel,application,placementrule  -n openshift-ptp

NAME                                                         TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/ptp-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   11d

NAME                                   TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/ptp-app-stage                                    11d

NAME                                                                 AGE    REPLICAS
placementrule.apps.open-cluster-management.io/placement-policy-ptp   119m   
placementrule.apps.open-cluster-management.io/stage-clusters         11d    
```
Notice that there are two placementrules. The one required to install PTP whose target clusters are labelled as pao=true and the new one which is required to apply the stage configuration to stage clusters actually labelled as environment=stage.

Lastly we can verify that the `ptpConfig` manifest has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployables
NAME                                                        TEMPLATE-KIND   TEMPLATE-APIVERSION                  AGE   STATUS
ptp-subscription-stage-deployable                           Subscription    apps.open-cluster-management.io/v1   11d   Propagated
ptp-subscription-stage-operator-ptp-grandmaster-ptpconfig   PtpConfig       ptp.openshift.io/v1                  11d   
ptp-subscription-stage-operator-ptp-slave-ptpconfig         PtpConfig       ptp.openshift.io/v1                  11d   
```

Next, move to your **spoke** cluster where PTP configuration is targeted and notice that a two PTP configuration profiles are created with the same exact values as the one it is stored in the Git repository.

```sh 
$ oc get ptpconfig -n openshift-ptp
NAME          AGE
grandmaster   10d
slave         10d
```

Finally you can verify that the slave profile is run by worker-cnf nodes labelled as ptp/slave (cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com), while the grandmaster ptp profile is run by the unique node labelled as ptp/grandmaster (cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com).

```sh
$ oc get nodes --show-labels | grep ptp
cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com    Ready    worker,worker-cnf   10d   v1.19.0+db1fc96   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com,kubernetes.io/os=linux,node-role.kubernetes.io/worker-cnf=,node-role.kubernetes.io/worker=,node.openshift.io/os_id=rhcos,ptp/grandmaster=

cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com    Ready    worker,worker-cnf   13d   v1.19.0+db1fc96   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com,kubernetes.io/os=linux,node-role.kubernetes.io/worker-cnf=,node-role.kubernetes.io/worker=,node.openshift.io/os_id=rhcos,ptp/slave=
```
Here you can see the linuxptp pod names running on each node. So the `linuxptp-daemon-2pdvf` pod must run as the PTP grandmaster while `linuxptp-daemon-7v6rk` run as a PTP slave:

```sh
 oc get pods -o wide -n openshift-ptp
NAME                          READY   STATUS    RESTARTS   AGE   IP              NODE                                              NOMINATED NODE   READINESS GATES
linuxptp-daemon-2pdvf         2/2     Running   0          10d   10.19.135.105   cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com    <none>           <none>
linuxptp-daemon-7v6rk         2/2     Running   0          10d   10.19.135.106   cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com    <none>           <none>


$ oc logs linuxptp-daemon-2pdvf -c linuxptp-daemon-container | grep master
phc2sys[719189.909]: selecting CLOCK_REALTIME as the master clock
ptp4l[719211.167]: selected local clock 98039b.fffe.618048 as best master
ptp4l[719211.167]: assuming the grand master role
```








