#!/bin/bash
set -euo pipefail

kubectl create ns database-storage

kubectl label no node01 disktype=ssd region=east
