# Deploy and configure CNF operators the gitops way with ACM

The aim of this work is using **Advanced Cluster Management for Kubernetes** (ACM) to automate the installation of the CNF operators and their specific configuration in the target clusters.

The process is basically summed up in:

* The **installation** of CNF operators is done using ACM policies. 
* The **configuration** of CNF operators is done using ACM GitOps approach where the configuration is applied from a Git repository. Therefore, we will make use of Channels, Subscriptions, Applications and PlacementRules objects to tell ACM to configure our CNF components.

## Prerequisities

* ACM installed in a OpenShift cluster. In my tests we run the following versions:

| Component | Version |
| --------- | ------- |
| OpenShift | 4.6.0-0.nightly-2020-10-03-051134 (nightly build) |
| ACM | 2.1.0 (no GA) |

```sh
$ oc get nodes -o wide
NAME       STATUS   ROLES            AGE   VERSION           INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                                                       KERNEL-VERSION                     CONTAINER-RUNTIME
eko6       Ready    worker           8d    v1.19.0+db1fc96   10.19.139.35   <none>        Red Hat Enterprise Linux CoreOS 46.82.202010022240-0 (Ootpa)   4.18.0-193.24.1.el8_2.dt1.x86_64   cri-o://1.19.0-20.rhaos4.6.git97d715e.el8
eko7       Ready    worker           9d    v1.19.0+db1fc96   10.19.139.36   <none>        Red Hat Enterprise Linux CoreOS 46.82.202010022240-0 (Ootpa)   4.18.0-193.24.1.el8_2.dt1.x86_64   cri-o://1.19.0-20.rhaos4.6.git97d715e.el8
master-0   Ready    master,virtual   9d    v1.19.0+db1fc96   10.19.140.20   <none>        Red Hat Enterprise Linux CoreOS 46.82.202010022240-0 (Ootpa)   4.18.0-193.24.1.el8_2.dt1.x86_64   cri-o://1.19.0-20.rhaos4.6.git97d715e.el8
master-1   Ready    master,virtual   9d    v1.19.0+db1fc96   10.19.140.21   <none>        Red Hat Enterprise Linux CoreOS 46.82.202010022240-0 (Ootpa)   4.18.0-193.24.1.el8_2.dt1.x86_64   cri-o://1.19.0-20.rhaos4.6.git97d715e.el8
master-2   Ready    master,virtual   9d    v1.19.0+db1fc96   10.19.140.22   <none>        Red Hat Enterprise Linux CoreOS 46.82.202010022240-0 (Ootpa)   4.18.0-193.24.1.el8_2.dt1.x86_64   cri-o://1.19.0-20.rhaos4.6.git97d715e.el8
```

* As target or remote clusters I imported an OpenShift cluster installed with the same nightly build

> :exclamation: Importing a cluster can be done using the ACM web user interface or using the CLI in a more scripted way. Take a look to the following [notes](https://github.com/alosadagrande/acm-cnf/tree/master/auto-import-clusters) on how to import clusters from command line.

```sh
$ oc get nodes
NAME                                              STATUS   ROLES               AGE     VERSION
cnf10-master-0.cnf10.kni.lab.eng.bos.redhat.com   Ready    master,virtual      9d      v1.19.0+db1fc96
cnf10-master-1.cnf10.kni.lab.eng.bos.redhat.com   Ready    master,virtual      9d      v1.19.0+db1fc96
cnf10-master-2.cnf10.kni.lab.eng.bos.redhat.com   Ready    master,virtual      9d      v1.19.0+db1fc96
cnf10-worker-0.dev5.kni.lab.eng.bos.redhat.com    Ready    worker,worker-cnf   6d17h   v1.19.0+db1fc96
cnf11-worker-0.dev5.kni.lab.eng.bos.redhat.com    Ready    worker,worker-cnf   9d      v1.19.0+db1fc96
```
> :warning: The imported cluster must have worker nodes SR-IOV and PTP capables otherwise the operators deployed won't actually configure the hardware appropiately. If they are not, you still can install the different operators but you won't be able to configure them.

## Scenario

In our scenario we have an ACM hub cluster installed and a spoke cluster running OpenShift already imported in ACM. So, ACM is ready to manage the spoke cluster. Before digging into how to install and configure each of the CNF operators we need to define the structure of this repository. Following GitOps best practices it is divided into different branches:

> :exclamation: The branch you are on now is master :)

* Master branch. In this branch it is stored all the ACM specific manifests. This means: policies, placement rules, applications... ,i.e. all the resources that ACM understand-
* Stage branch. Here, we can find all the Kubernetes native objects or specific CNF custom resources required to configure the different operators. This includes for instance the ptpconfig files, performance profiles for the Performance Addon Operator, SRIOV network definitions, etc. Another key point is that they are stored in a branch called stage, which means that this is going to be the configuration for each CNF operator that is going to be applied to all staging OpenShift clusters. 

> :warning: See that you can create new branches for clusters in development, production or even per hardware vendor or model. It is up to you how you group your different clusters. The only thing you need to take into account is that clusters grouped will share the same CNF configuration.

* Config branch. This branch is used to store the default CNF configuration for each operator. Then, using kustomize we can replace or change parts of the default configuration in order to set exactly the right configuration for each environment. For instance, we can have a basic PTP configuration in the config branch and when applying it for stage clusters some parts of this configuration is updated.

> :exclamation: Not all CNF operators require a default or base configuration. SCTP for instance is using a base configuration stored in the config branch, which applies a replacement depending on the environment where the cluster is grouped.











## Performance addon operator

Performance Addon Operator installation is done using ACM policies: policy-pao-operator.yaml which ensures the following objects are installed in the spoke cluster:

* Create the namespace where the operator will be executed
* Installs the operator: operatorgroup and subscription objects
* Creates a specific machineconfigpool for CNF workers

Configuration of the PAO is done using RHACM gitOps approach. The performance profile is located in a Git repository and RHACM applies it on a regular basis. Therefore, in order to change the performance profile it must be done through a Git workflow.

## PTP

The installation of PTP operator is done using RHACM policies: policy-ptp-operator.yaml which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Currently openshift-ptp
* Installs the operator: operatorgroup and subscription objects
* Configures the PTP operator so that it only runs PTP on capable PTP nodes. Currently the ones labelled as worker-cnf.

Specific configuration of PTP grandmaster and slaves are done using RHACM gitOps approach. The grandmaster profile and slave profile are stored and applied from Git.

## SRIOV

The installation of SRIOV Network Operator is done using RHACM policies: policy-sriov-operator.yaml which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Currently openshift-sriov-network-operator
* Installs the operator: operatorgroup and subscription objects
* Configures SRIOV Network operator to discover SRIOV devices on SRIOV capable nodes, which currently are the ones labelled as worker-cnf.

Specific SRIOV configuration is done using RHACM gitOps approach: 
* [SRIOV Network object](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network.yaml)
* [SRIOV Network Node Policy](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network-node-policy-netdevice.yaml)
* Test executing a [pod](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-pod-test.yaml) requesting a VFS from a SRIOV capable node.

