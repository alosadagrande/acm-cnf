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

> :exclamation: Here we are using the operator for OpenShift 4.6. Since it is not released at the time of writing the Subscription object points to an internal catalogSource. You can take a look to policy-pao-operator.yaml which is runnning operator 4.5 to see the differences. Just make sure once OpenShift 4.6 is GA you replace Subscription.spec.source to `redhat-operators` in the policy manifest.


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

Configuration of the Performance Addon Operator (PAO) is done using ACM GitOps approach. Actually, when we talk about PAO configuration we are referring to create or modify the `PerformanceProfile` CRD. This profile is used by PAO to apply CNF specific configuration like real-time kernel installation, hugepages configuration or cpu isolation among others.

The performance profile is stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change the performance profile of a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it. 

First, we need to create the proper ACM manifests to tell ACM where this performance profile (configuration) is located, when it must be applied and who are the target clusters. 

> :exclamation: These files are placed in the master branch since they are ACM specific. 

In order to do that we need to create a `channel` resource that specifies the Git repository where the configuration can be found. The specific Git branch is specified in the `subscription` resource. Then, apply this configuration to target clusters labelled with staging environment using a `placementrule`.


```sh
$ git checkout master
$ cd acm-manifests/performance-operator/stage
```
Connect to the hub cluster:

```sh
$ oc project openshift-performance-addon
$ oc apply -f channel-pao.yaml
$ oc apply -f app-subs-stage.yaml
$ oc apply -f placement-stage-clusters.yaml
```
> :exclamation: Notice that you must have an imported cluster labelled as environment=stage to let ACM which is/are the clusters where the performance profile (configuration) must be applied.

Verify in your hub cluster that those resources are correctly created and propagated:

```sh
$ oc get channel,application,placementrule  -n openshift-performance-addon
NAME                                                         TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/pao-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   8d

NAME                                   TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/pao-app-stage                                    8d

NAME                                                                 AGE   REPLICAS
placementrule.apps.open-cluster-management.io/placement-policy-pao   8d    
placementrule.apps.open-cluster-management.io/stage-clusters         8d    
```
> :exclamation: Notice that there are two placementrules. The one required to install PAO, whose target clusters are labelled as pao=true and the new one, which is required to apply the stage configuration to stage clusters: environment=stage

Lastly we can verify that the `PerformanceProfile` manifest has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployables
NAME                                                                         TEMPLATE-KIND        TEMPLATE-APIVERSION                  AGE   STATUS
pao-subscription-stage-deployable                                            Subscription         apps.open-cluster-management.io/v1   8d    Propagated
pao-subscription-stage-operator-performance-performance-performanceprofile   PerformanceProfile   performance.openshift.io/v1alpha1    8d    
```

Next, move to your **spoke** clusters where PAO configuration is targeted and notice that a new `performanceprofile` manifest is created with the same exact values as the one it is stored in the Git repository. 

```sh
$ oc get performanceprofile
NAME          AGE
performance   7d7h
```

At this point everything is setup. However, you may notice that no changes are being made to worker nodes with role worker-cnf... there are no reboots... nothing is going on. That's because the `machineconfigpool` for worker-cnf is paused. We need to unpaused to let the Machine Config Operator to start applying the configuration to worker-cnf nodes.

Remember that the worker-cnf `machineconfigpool` is controlled by the we applied in the installation section. So, we should not change it from the spoke cluster. Actually, the policy must be edited from the hub cluster and paused must be set to false:

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
