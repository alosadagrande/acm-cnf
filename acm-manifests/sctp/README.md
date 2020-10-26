# ACM & SCTP

## Installation

There is actually no installation of SCTP because it is not an operator, but a kernel module (SCTP) installed as a `machineConfig` resource. 


## Configuration

Configuration or better said loading SCTP kernel module is done using ACM GitOps approach. Actually, when we talk about SCTP configuration we are referring to create or modify a `machineConfig` manifest.

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: load-sctp-module
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
        - contents:
            source: data:,
            verification: {}
          filesystem: root
          mode: 420
          path: /etc/modprobe.d/sctp-blacklist.conf
        - contents:
            source: data:text/plain;charset=utf-8,sctp
          filesystem: root
          mode: 420
          path: /etc/modules-load.d/sctp-load.conf
```

> :exclamation: Notice that basically we are enabling the SCTP kernel module by adding sctp to the /etc/modules-load of the proper OpenShift nodes.

The machineConfig manifest is stored in a Git branch (stage) in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change the configuration of a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it.

> :warning: If you already installed the Performance Addon Operator then you already have the worker-cnf machineconfigpool in place. If not, please take a look at the PAO policy.

We need to create the proper ACM manifests to tell ACM where the `machineConfig` file is located and which cluster will be targetted. Note that these files are placed in the master branch since they are ACM specific.

```sh
$ git checkout master
$ cd acm-manifests/sctp/stage
```
Connect to the hub cluster and create a namespace to store all the ACM manifests:

```sh
$ oc project sctp-gitops
$ oc create -f channel-sctp.yaml 
$ oc create -f app-subs-stage.yaml 
$ oc create -f placement-stage-clusters.yaml
```

Notice that we are not creating a placementrule since it is already created when configuring SRIOV operator. Verify in your hub cluster that those resources are correctly created and propagated. Now, we expect to co-exist both SRIOV and DPDK manifests:

```sh
$ oc get channel,application,placementrule 
NAME                                                          TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/sctp-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   11d

NAME                                    TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/sctp-app-stage                                    11d

NAME                                                           AGE   REPLICAS
placementrule.apps.open-cluster-management.io/stage-clusters   11d   
```

Lastly we can verify that the SCTP object has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployable -n sctp-gitops
NAME                                                                   TEMPLATE-KIND   TEMPLATE-APIVERSION                    AGE   STATUS
sctp-subscription-stage-deployable                                     Subscription    apps.open-cluster-management.io/v1     11d   Propagated
sctp-subscription-stage-operator-sctp-load-sctp-module-machineconfig   MachineConfig   machineconfiguration.openshift.io/v1   11d   
```

Next, move to your **spoke** cluster where SCTP is targeted and notice that a new `machineConfig` pointing to worker-cnf role is created:

```sh
oc get mc load-sctp-module 
NAME               GENERATEDBYCONTROLLER   IGNITIONVERSION   AGE
load-sctp-module                           2.2.0             2d10h
```

: warning: A new rendered-worker-cnf machineConfig must be created as well and will be applied to worker-cnf role nodes. This can cause these nodes to be rebooted.

Finally, we can verify that the SCTP kernel module is installed by listing the enabled modules of any worker-cnf role node:

```sh
$ oc get nodes -l node-role.kubernetes.io/worker-cnf
NAME                                             STATUS   ROLES               AGE   VERSION
cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com   Ready    worker,worker-cnf   11d   v1.19.0+db1fc96
cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com   Ready    worker,worker-cnf   14d   v1.19.0+db1fc96

$ oc debug node/cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com 
Starting pod/cnf11-worker-0dev5knilabengbosredhatcom-debug ...
To use host binaries, run `chroot /host`
Pod IP: 10.19.135.106
If you don't see a command prompt, try pressing enter.

sh-4.4# chroot /host

sh-4.4# lsmod | grep sctp
xt_sctp                16384  0
sctp                  401408  84
libcrc32c              16384  5 nf_conntrack,nf_nat,openvswitch,xfs,sctp
```






