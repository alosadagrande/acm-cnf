# ACM & Performance Addon Operator

## Installation

Performance Addon Operator installation is done using ACM policies which ensures the following objects must exist in the spoke or imported cluster:

* A namespace (openshift-performance-addon) where the operator will be executed 
* Operator installation by creating the  `operatorgroup` and `subscription` objects
* A specific `machineconfigpool` for CNF capable workers. This pool will match workers with role cnf-worker but can be whatever suits you best.
* Proper CNF capable nodes labelled as role worker-cnf.

In order to apply the policy named policy-pao-operator a `PlacementRule` is required so that we can target from all our imported clusters the ones that require this policy to be install or said differently, the ones that requires the Performance Addon operator installed. In our case we will target clusters that contain the label **pao=true** added.

First thing, in our hub cluster create the openshift-performance-addon-operator namespace:

```sh
$ oc create ns openshift-performance-addon-operator
namespace/openshift-performance-addon-operator created
```
Then, inside the openshift-performance-addon namespace, apply the policy which will create the placementrule and placementrulebinding as well.

> :exclamation: Here we are using the operator for OpenShift 4.6 which is the General Available (GA) version at the moment of writing. This should be adapted once OpenShift 4.7 is released.

```sh
$ oc create -f policy-pao-operator.yaml 
policy.policy.open-cluster-management.io/policy-pao-operator created
placementbinding.policy.open-cluster-management.io/binding-policy-pao created
placementrule.apps.open-cluster-management.io/placement-policy-pao created
```

Verify the policy is created:

```sh
$ oc get policy -n openshift-performance-addon-operator
NAME                  AGE
policy-pao-operator   28s
```

> :warning: If you go to the spoke cluster you will notice the operator is not installed. Even the namespace was not created. That's because we forgot to label our spoke cluster in ACM to match the placementRule label (pao=true)

Next, let's label the imported cluster by connecting to the ACM user interface and add a label to a cluster or via CLI into the managedClusters object. Remember to set label as pao=true. This step can be executed from the UI or editing the proper cluster managedCluster object.

```sh
$ oc patch managedClusters cnf10 --type=merge -p '{"metadata":{"labels":{"pao":"true"}}}'
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
$ oc get pods,operatorgroup,subscription.operators.coreos.com,mcp -n openshift-performance-addon-operator

NAME                                        READY   STATUS    RESTARTS   AGE
pod/performance-operator-697445d55b-4djrd   1/1     Running   0          59s

NAME                                                                      AGE
operatorgroup.operators.coreos.com/openshift-performance-addon-operator   107s

NAME                                                                                  PACKAGE                      SOURCE             CHANNEL
subscription.operators.coreos.com/openshift-performance-addon-operator-subscription   performance-addon-operator   redhat-operators   4.6

NAME                                                             CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
machineconfigpool.machineconfiguration.openshift.io/master       rendered-master-2301d97983c56caa3cb1a81fd01ca987   True      False      False      3              3                   3                     0                      20h
machineconfigpool.machineconfiguration.openshift.io/worker       rendered-worker-7f3e6ca051823c54a693c681699754b6   True      False      False      2              2                   2                     0                      20h
machineconfigpool.machineconfiguration.openshift.io/worker-cnf                                                      False     True       False      2              0                   0                     0                      87s
```

> :exclamation: Notice the machineconfigpool was created but there is not any node matching the role worker-cnf. This will be addressed in the configuration part.

## Configuration

Configuration of the Performance Addon Operator (PAO) is done using ACM GitOps approach. Actually, when we talk about PAO configuration we are referring to create or modify the `PerformanceProfile` CRD. This profile is used by PAO to apply CNF specific configuration like real-time kernel installation, hugepages configuration or cpu isolation among others.

The performance profile is stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change the performance profile of a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it. 

First thing that must be done is label the CNF capable worker nodes as role worker-cnf since the `machineconfigpool` we created during the PAO installation target them to apply the performance profile. This can be done manually or using a policy targetting one cluster at a time:

```sh
$ oc create -f policy-label-cnf10-worker-nodes.yaml 
policy.policy.open-cluster-management.io/policy-clustercnf10-tag-workers created
placementbinding.policy.open-cluster-management.io/binding-policy-clustercnf10-tag-workers created
placementrule.apps.open-cluster-management.io/cluster-cnf10 created
```
> :warning: This a very specific policy since we need to know the name of nodes in advance or get that information from ACM. Basically, applies the mentioned label to the nodes explicitly included in the policy. Also specifically targets one cluster, since usually the name of the nodes are different among clusters. 

We can verify that the proper nodes are labelled accordingly by executing the following command in the imported cluster:

```sh
oc get nodes -lnode-role.kubernetes.io/worker-cnf
NAME                                             STATUS   ROLES               AGE   VERSION
cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com   Ready    worker,worker-cnf   19h   v1.19.0+d59ce34
cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com   Ready    worker,worker-cnf   19h   v1.19.0+d59ce34
```
Next, we need to create the proper ACM manifests to tell ACM where this performance profile (configuration) is located, when it must be applied and who are the target clusters. 

> :exclamation: These files are placed in the master branch since they are ACM specific. 

In order to do that we need to create a `channel` resource that specifies the Git repository where the configuration can be found. The specific Git branch is specified in the `subscription` resource. Then, apply this configuration to target clusters labelled with staging environment using a `placementrule`.


```sh
$ git checkout master
$ cd acm-manifests/performance-operator/stage
```
Connect to the hub cluster:

```sh
$ oc project openshift-performance-addon-operator

$ oc apply -f channel-pao.yaml
channel.apps.open-cluster-management.io/pao-channel-github created

$ oc apply -f app-subs-stage.yaml
application.app.k8s.io/pao-app-stage created
subscription.apps.open-cluster-management.io/pao-subscription-stage created

$ oc apply -f placement-stage-clusters.yaml
placementrule.apps.open-cluster-management.io/stage-clusters created
```
> :exclamation: Notice that you must have an imported cluster labelled as environment=stage to let ACM know which is/are the clusters where the performance profile (configuration) must be applied.

Verify in your hub cluster that those resources are correctly created and propagated:

```sh
$ oc get channel,application,placementrule  -n openshift-performance-addon-operator

NAME                                                         TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/pao-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   3m41s

NAME                                   TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/pao-app-stage                                    3m12s

NAME                                                                 AGE     REPLICAS
placementrule.apps.open-cluster-management.io/cluster-cnf10          11m     
placementrule.apps.open-cluster-management.io/placement-policy-pao   30m     
placementrule.apps.open-cluster-management.io/stage-clusters         2m57s   
```

> :exclamation: Notice that there are two placementrules. The one required to install PAO, whose target clusters are labelled as pao=true and the new one, which is required to apply the stage configuration to stage clusters: environment=stage. There is no need to have two, it is simply an exercise of learning. One `placementRule` might be enough for your case.

Lastly we can verify that the `PerformanceProfile` manifest has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployables
NAME                                                                         TEMPLATE-KIND        TEMPLATE-APIVERSION                  AGE     STATUS
pao-subscription-stage-deployable                                            Subscription         apps.open-cluster-management.io/v1   2m25s   Propagated
pao-subscription-stage-operator-performance-performance-performanceprofile   PerformanceProfile   performance.openshift.io/v1alpha1    2m24s   
```

Next, move to your **spoke** clusters where PAO configuration is targeted and notice that a new `performanceprofile` manifest is created with the same exact values as the one it is stored in the Git repository. 

```sh
$ oc get performanceprofile
NAME          AGE
performance   86s
```

At this point everything is setup. However, you may notice that no changes are being made to worker nodes with role worker-cnf... there are no reboots... nothing is going on. That's because the `machineconfigpool` for worker-cnf is paused. We need to unpaused to let the Machine Config Operator start applying the configuration to worker-cnf nodes.

Remember that the worker-cnf `machineconfigpool` is the one we applied in the installation section. So, we should not change it from the spoke cluster. Actually, the policy must be edited from the hub cluster and paused must be set to false:

```yaml
        - complianceType: musthave
          objectDefinition:
            apiVersion: machineconfiguration.openshift.io/v1
            kind: MachineConfigPool
            metadata:
              labels:
                machineconfiguration.openshift.io/role: worker-cnf
              name: worker-cnf
            spec:
              machineConfigSelector:
                matchExpressions:
                - key: machineconfiguration.openshift.io/role
                  operator: In
                  values:
                  - worker
                  - worker-cnf
              nodeSelector:
                matchLabels:
                  node-role.kubernetes.io/worker-cnf: ""
              paused: false
        remediationAction: enforce
        severity: low
  remediationAction: enforce
```

At this point your worker-cnf nodes will start rebooting and configuring towards the desired state. 

> :warning: If you need to modify the performance profile remember that it must be modified in the proper Git branch and not in the imported or spoke clusters. From now on you must follow a Git workflow.
