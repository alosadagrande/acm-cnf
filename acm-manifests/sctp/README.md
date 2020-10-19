# ACM & DPDK

## Installation

There is actually installation of DPDK because it is not an operator. However, it requires SRIOV and Hugepages to be properly configured. SRIOV Network is handled by the SRIOV Network Operator while Hugepages can be easily managed by the Performance Addon Operator. Then, as a prequisite install PAO and SRIOV Operator first.

Once the operators are running and the requirements detailed previously in place it is time to run the pod that contains `testpmd` application which leverages DPDK libraries included in the container image. The container image quay.io/alosadag/testpmd:tekton was already built with testpmd and DPDK libraries, so it is ready just to be executed. Further information on how to build DPDK images can be found in this article: [Building CNF applications with OpenShift Pipelines
](https://www.openshift.com/blog/building-cnf-applications-with-openshift-pipelines)

## Configuration

Configuration or best said running a DPDK application is done using ACM GitOps approach. Actually, when we talk about DPDK configuration we are referring to create or modify the testpmd `deployment` manifest.

```yaml
      containers:
        - image: quay.io/alosadag/testpmd:tekton
          command:
          - /bin/bash
          - -c
          - sleep INF
          securityContext:
            runAsUser: 0
            capabilities:
              add: ["IPC_LOCK","SYS_RESOURCE"]
          imagePullPolicy: Always
          env:
            - name: RUN_TYPE
              value: "testpmd"
          name: testpmd
          resources:
            limits:
              cpu: "4"
              hugepages-1Gi: 1Gi
              memory: 1000Mi
            requests:
              cpu: "4"
              hugepages-1Gi: 1Gi
              memory: 1000Mi
          volumeMounts:
            - mountPath: /mnt/huge
              name: hugepage
```

> :exclamation: Notice that QoS is guaranteed, hugepages are required and elevated privileges are required to execute the application.


The deployment manifest is stored in a Git branch in this repository. ACM is in charge of making sure the configuration stored in Git is applied properly. Therefore, in order to change the configuration of a particular environment or group of clusters, it must be done through a Git workflow.

Let's get into it.

We need to create the proper ACM manifests to tell ACM where the `deployment` file is located and which cluster will be targetted. Note that these files are placed in the master branch since they are ACM specific.

> :exclamation: Since DPDK application are very dependant on SRIOV configuration, the application is expected to run in the same namespace: openshift-sriov-network-operator.

```sh
$ git checkout master
$ cd acm-manifests/dpdk/stage
```
Connect to the hub cluster:

```sh
$ oc project openshift-sriov-network-operator

$ oc create -f channel-dpdk.yaml 
channel.apps.open-cluster-management.io/dpdk-channel-github created

$ oc create -f app-subs-stage.yaml 
application.app.k8s.io/dpdk-app-stage created
```

Notice that we are not creating a placementrule since it is already created when configuring SRIOV operator. Verify in your hub cluster that those resources are correctly created and propagated. Now, we expect to co-exist both SRIOV and DPDK manifests:

```sh
$ oc get channel,application,placementrule -n openshift-sriov-network-operator

NAME                                                           TYPE   PATHNAME                                       AGE
channel.apps.open-cluster-management.io/dpdk-channel-github    Git    https://github.com/alosadagrande/acm-cnf.git   107s
channel.apps.open-cluster-management.io/sriov-channel-github   Git    https://github.com/alosadagrande/acm-cnf.git   11d

NAME                                     TYPE   VERSION   OWNER   READY   AGE
application.app.k8s.io/dpdk-app-stage                                     103s
application.app.k8s.io/sriov-app-stage                                    11d

NAME                                                                   AGE   REPLICAS
placementrule.apps.open-cluster-management.io/placement-policy-sriov   81m   
placementrule.apps.open-cluster-management.io/stage-clusters           11d   
```

Lastly we can verify that the DPDK object has been propagated correctly as well from the Git branch repository to the target clusters.

```sh
$ oc get deployables 

NAME                                                                     TEMPLATE-KIND            TEMPLATE-APIVERSION                  AGE    STATUS
dpdk-subscription-stage-deployable                                       Subscription             apps.open-cluster-management.io/v1   4m6s   Propagated
dpdk-subscription-stage-operator-dpdk-testpmd-deployment                  Deployment               apps/v1                              4m6s   
sriov-subscription-operator-deployable                                                        Subscription             apps.open-cluster-management.io/v1   11d    Propagated
sriov-subscription-operator-operator-sriov-sriov-network-node-policy-sriovnetworknodepolicy   SriovNetworkNodePolicy   sriovnetwork.openshift.io/v1         11d    
sriov-subscription-operator-operator-sriov-sriov-network-sriovnetwork                         SriovNetwork             sriovnetwork.openshift.io/v1         11d    
sriov-subscription-operator-operator-sriov-sriov-pod-test-deployment                          Deployment               apps/v1                              11d   
```

Next, move to your **spoke** cluster where DPDK is targeted and notice that the pod is not available:

```sh
$ oc get deployment testpmd -n openshift-sriov-network-operator
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
testpmd                  0/1     0            0           5m29s
```
If we check the status we can see that the deployment is lacking permissions:

```sh
$ oc get -o json deployment testpmd | jq -r '.status.conditions[] | .message'

Deployment does not have minimum availability.
pods "testpmd-869bccdd77-" is forbidden: unable to validate against any security context constraint: [spec.containers[0].securityContext.runAsUser: Invalid value: 0: must be in the ranges: [1000650000, 1000659999] spec.containers[0].securityContext.capabilities.add: Invalid value: "IPC_LOCK": capability may not be added spec.containers[0].securityContext.capabilities.add: Invalid value: "SYS_RESOURCE": capability may not be added]
ReplicaSet "testpmd-869bccdd77" has timed out progressing.
```

If we add the privileged SCC to default serviceAccount or even better, if we add a new serviceAccount in charge of running DPDK with that permissions we will see the testpmd pod running:

```sh
$ oc get pods -l app=testpmd

NAME                                      READY   STATUS    RESTARTS   AGE
testpmd-869bccdd77-ql7zr                  1/1     Running   0          5m1s

$ oc rsh testpmd-869bccdd77-ql7zr 

sh-4.4# cat /sys/fs/cgroup/cpuset/cpuset.cpus
6,8,10,12

sh-4.4# env | grep PCI
PCIDEVICE_OPENSHIFT_IO_SRIOVNIC=0000:19:00.3

sh-4.4# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if233: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:86:02:7d brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.134.2.125/23 brd 10.134.3.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::858:aff:fe86:27d/64 scope link 
       valid_lft forever preferred_lft forever
28: net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 76:53:df:83:35:aa brd ff:ff:ff:ff:ff:ff
    inet 172.22.0.221/24 brd 172.22.0.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::7453:dfff:fe83:35aa/64 scope link 
       valid_lft forever preferred_lft forever
```







