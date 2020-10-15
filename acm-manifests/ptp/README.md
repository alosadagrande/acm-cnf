# PTP Operator

## Installation

The installation of PTP operator is done using RHACM policies: policy-ptp-operator.yaml which ensures the following objects exist in the spoke clusters:

* The namespace where the operator will be executed. Currently openshift-ptp
* Installs the operator: operatorgroup and subscription objects
* Configures the PTP operator so that it only runs PTP on capable PTP nodes. Currently the ones labelled as worker-cnf.

## Configuration

Specific configuration of PTP grandmaster and slaves are done using RHACM gitOps approach. The grandmaster profile and slave profile are stored and applied from Git.



