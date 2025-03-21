#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=8:00:00
#SBATCH --output=logs/preprocess_controller_%j.out
#SBATCH --error=logs/preprocess_controller_%j.err
#SBATCH --job-name=preprocess_controller

# This script manages the preprocessing workflow:
# 1. Runs initial preprocessing (run_preprocess.sh)
# 2. This prepares for the bootstrap stage

set -e

# Required environment variables check
: ${DATA_DIR:?"DATA_DIR must be set"}
: ${INPUT_FILE:?"INPUT_FILE must be set"}
: ${NUM_BOOTSTRAPS:=100}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting preprocessing"
echo "DATA_DIR: ${DATA_DIR}"
echo "INPUT_FILE: ${INPUT_FILE}"
echo "NUM_BOOTSTRAPS: ${NUM_BOOTSTRAPS}"

# Create logs directory if it doesn't exist
mkdir -p logs

# Initialize conda
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Activate preprocessing environment
conda activate preprocess_env || {
    echo "Failed to activate preprocess_env"
    exit 1
}

# Run preprocessing directly (without submitting another job)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running initial preprocessing"
./0-preprocess/run_preprocess.sh ${INPUT_FILE} ${DATA_DIR}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preprocessing completed" 