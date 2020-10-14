# acm-cnf

The idea is to use Advance Cluster Management for Kubernetes (ACM) to automate the installation of the CNF operators and their specific configuration in the target clusters.

Installation of CNF operators are done using ACM policies. Configuration of CNF operators are done using RHACM gitOps approach where the configuration is applied from a Git repository.

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
* Specific SRIOV configuration is done using RHACM gitOps approach:

[SRIOV Network object](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network.yaml)
[SRIOV Network Node Policy](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network-node-policy-netdevice.yaml)
Test executing a [pod](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-pod-test.yaml) requesting a VFS from a SRIOV capable node.

