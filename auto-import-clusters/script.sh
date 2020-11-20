#!/bin/bash
export SPOKE_CLUSTER=$1
HUB_CLUSTER=cnf20

if [[ $# -ne 1 ]] ; then
    echo '[ERROR] Script expects the name of the imported cluster as argument'
    exit 0
fi

# HUB
export KUBECONFIG=/home/alosadag/SYSENG/CNF/${HUB_CLUSTER}-ocp/auth/kubeconfig
envsubst < hub/spoke_definition.yaml | oc create -f -

until oc get secret $SPOKE_CLUSTER-import -n $SPOKE_CLUSTER; do sleep 1; done

oc get secret $SPOKE_CLUSTER-import -o "jsonpath={.data['crds\.yaml']}" -n $SPOKE_CLUSTER | base64 -d > ./spoke/crds-${SPOKE_CLUSTER}.yaml 
oc get secret $SPOKE_CLUSTER-import -o "jsonpath={.data['import\.yaml']}" -n $SPOKE_CLUSTER | base64 -d > ./spoke/import-${SPOKE_CLUSTER}.yaml

# SPOKE CLUSTER
export KUBECONFIG=/home/alosadag/SYSENG/CNF/${SPOKE_CLUSTER}-ocp/auth/kubeconfig
oc apply -f ./spoke/crds-${SPOKE_CLUSTER}.yaml 
oc apply -f ./spoke/import-${SPOKE_CLUSTER}.yaml
