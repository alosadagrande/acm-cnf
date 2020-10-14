#!/bin/bash

oc get nodes -o wide 

export SPOKE_CLUSTER=cnf21

export DEPLOYMENT_IMAGE="quay.io/open-cluster-management/registration-operator@sha256:36f444eb232134a1e94c83dafc848ed82d1b1f8c2ff4148aa8cc83a97deb469d"
export KLUSTERLET_REG_IMAGE="quay.io/open-cluster-management/registration@sha256:be41ba10cb03ff4524c7f243db8da7b602ee7b3328459853d8a54c9d2126a6e8"
export KLUSTERLET_WORK_IMAGE="quay.io/open-cluster-management/work@sha256:98d9e72801b2cf46c70922cfeab9f1b28b60f9c0d06fc94778b291012ce1a6ac"

KUBECONFIG_HUB="/home/alosadag/SYSENG/CNF/cnf20-ocp/auth/kubeconfig"
export KUBECONFIG_HUB_B64=$(cat $KUBECONFIG_HUB | base64 -w 0)
