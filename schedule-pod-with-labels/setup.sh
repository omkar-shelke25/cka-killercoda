#!/bin/bash
set -euo pipefail

kubectl taint no controlplane  node-role.kubernetes.io/control-plane:NoSchedule-

kubectl create ns database-storage

kubectl label no controlplane disktype=ssd region=east 

kubectl label no node01 region=east
