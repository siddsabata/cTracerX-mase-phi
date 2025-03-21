#!/bin/bash
# --------------------------------------------------
# Step 2: Run PhyloWGS in parallel for a timepoint
#
# This script:
# 1. Submits parallel PhyloWGS jobs for a specific timepoint
#
# Usage: 
#   bash run_phylowgs_parallel.sh <timepoint_dir> [num_bootstraps] [num_chains] [chunk_size]
# Example:
#   bash run_phylowgs_parallel.sh /path/to/data/CRUK0044_baseline_2014-11-28 100 5 10
# --------------------------------------------------

set -e

# Process arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <timepoint_dir> [num_bootstraps] [num_chains] [chunk_size]"
    exit 1
fi

TIMEPOINT_DIR="$1"
NUM_BOOTSTRAPS="${2:-100}"
NUM_CHAINS="${3:-5}"
CHUNK_SIZE="${4:-10}"

# Extract timepoint name
TIMEPOINT_NAME=$(basename "${TIMEPOINT_DIR}")

# Calculate number of chunks
NUM_CHUNKS=$(( (NUM_BOOTSTRAPS + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Create logs directory
mkdir -p logs

echo "==========================================================="
echo "Running parallelized PhyloWGS for timepoint: ${TIMEPOINT_NAME}"
echo "==========================================================="
echo "Timepoint directory: ${TIMEPOINT_DIR}"
echo "Number of bootstraps: ${NUM_BOOTSTRAPS}"
echo "Number of chains: ${NUM_CHAINS}"
echo "Chunk size: ${CHUNK_SIZE}"
echo "Total chunks: ${NUM_CHUNKS}"
echo "==========================================================="

# Check if bootstrap is complete by looking for the marker
if [ ! -f "${TIMEPOINT_DIR}/.markers/bootstrap_complete" ]; then
    echo "WARNING: Bootstrap marker file not found. Make sure bootstrapping is complete."
    echo "Proceeding anyway, but you may encounter errors if bootstrapping is incomplete."
fi

# Submit PhyloWGS jobs as an array
phylowgs_job=$(sbatch \
    --job-name="phy_${TIMEPOINT_NAME}" \
    --output="logs/phylowgs_${TIMEPOINT_NAME}_%A_%a.out" \
    --error="logs/phylowgs_${TIMEPOINT_NAME}_%A_%a.err" \
    --array=0-$((NUM_CHUNKS-1)) \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=48:00:00 \
    --export=ALL,TIMEPOINT_DIR="${TIMEPOINT_DIR}",TIMEPOINT_NAME="${TIMEPOINT_NAME}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}",NUM_CHAINS="${NUM_CHAINS}",CHUNK_SIZE="${CHUNK_SIZE}" \
    phylowgs_worker.sh)

# Extract job ID
phylowgs_job_id=$(echo $phylowgs_job | awk '{print $4}' | cut -d'.' -f1)
echo "Submitted PhyloWGS jobs with array ID: ${phylowgs_job_id}"
echo "Monitor with: squeue -j ${phylowgs_job_id}"
echo
echo "Once all PhyloWGS jobs complete for all timepoints, run the post-processing script." 