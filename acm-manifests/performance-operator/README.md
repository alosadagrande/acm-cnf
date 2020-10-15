# Performance Addon Operator

## Installation

Performance Addon Operator installation is done using ACM policies: policy-pao-operator.yaml which ensures the following objects are installed in the spoke cluster:

* Create the namespace where the operator will be executed
* Installs the operator: operatorgroup and subscription objects
* Creates a specific machineconfigpool for CNF workers

## Configuration

Configuration of the PAO is done using RHACM gitOps approach. The performance profile is located in a Git repository and RHACM applies it on a regular basis. Therefore, in order to change the performance profile it must be done through a Git workflow.

