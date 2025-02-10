#!/bin/bash
# --------------------------------------------------
# This script purges (removes) all conda environments
# used by the pipeline:
#
# 1. preprocess_env
# 2. phylowgs_env
# 3. aggregation_env
# 4. markers_env
#
# Usage:
#   bash purge.sh
# --------------------------------------------------

set -e

# Ensure conda commands are available.
source $(conda info --base)/etc/profile.d/conda.sh

# List of environments to purge
env_list=("preprocess_env" "aggregation_env" "markers_env" "phylowgs_env")

echo "Purging existing conda environments..."
for env in "${env_list[@]}"; do
    if conda env list | grep -q "^$env\s"; then
         echo "Removing existing environment: $env"
         conda remove --name "$env" --all -y
    else
         echo "Environment $env not found, skipping removal."
    fi
done

echo "Purge complete." 