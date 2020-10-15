# ACM and the SRIOV Network Operator

## Installation

The installation of SRIOV Network Operator is done using RHACM policies: policy-sriov-operator.yaml which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Currently openshift-sriov-network-operator
* Installs the operator: operatorgroup and subscription objects
* Configures SRIOV Network operator to discover SRIOV devices on SRIOV capable nodes, which currently are the ones labelled as worker-cnf.

## Configuration

Specific SRIOV configuration is done using RHACM gitOps approach: 

* [SRIOV Network object](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network.yaml)
* [SRIOV Network Node Policy](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-network-node-policy-netdevice.yaml)
* Test executing a [pod](https://github.com/alosadagrande/acm-cnf/blob/cnf10/operator/sriov/sriov-pod-test.yaml) requesting a VFS from a SRIOV capable node.

