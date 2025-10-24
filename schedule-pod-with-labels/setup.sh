#!/bin/bash
set -euo pipefail

kubectl label no controlplane disktype=ssd region=east

kubectl label no node01 region=east
