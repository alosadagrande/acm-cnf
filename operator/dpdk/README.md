DPDK
===================================================
sh-4.4# cat /sys/fs/cgroup/cpuset/cpuset.cpus
0
sh-4.4# testpmd  -l 4,6,44,46 -w 0000:19:00.3 --iova-mode=va --log-level="*:debug" -- -i --portmask=0x1 --nb-cores=2 --forward-mode=mac --port-topology=loop --no-mlockall
