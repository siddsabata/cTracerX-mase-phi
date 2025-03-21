#!/bin/bash
# --------------------------------------------------
# Step 3: Run post-processing for a timepoint
#
# This script:
# 1. Runs aggregation and marker selection for a specific timepoint
#
# Usage: 
#   bash run_postprocessing.sh <timepoint_dir> [num_bootstraps] [read_depth]
# Example:
#   bash run_postprocessing.sh /path/to/data/CRUK0044_baseline_2014-11-28 100 1500
# --------------------------------------------------

set -e

# Process arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <timepoint_dir> [num_bootstraps] [read_depth]"
    exit 1
fi

TIMEPOINT_DIR="$1"
NUM_BOOTSTRAPS="${2:-100}"
READ_DEPTH="${3:-1500}"

# Extract timepoint name
TIMEPOINT_NAME=$(basename "${TIMEPOINT_DIR}")

# Create logs directory
mkdir -p logs

echo "==========================================================="
echo "Running post-processing for timepoint: ${TIMEPOINT_NAME}"
echo "==========================================================="
echo "Timepoint directory: ${TIMEPOINT_DIR}"
echo "Number of bootstraps: ${NUM_BOOTSTRAPS}"
echo "Read depth: ${READ_DEPTH}"
echo "==========================================================="

# Check if PhyloWGS is complete for all bootstraps
incomplete=0
for bootstrap_num in $(seq 1 $NUM_BOOTSTRAPS); do
    marker_file="${TIMEPOINT_DIR}/bootstrap_${bootstrap_num}/.markers/phylowgs_complete"
    if [ ! -f "${marker_file}" ]; then
        echo "WARNING: PhyloWGS not complete for bootstrap ${bootstrap_num}"
        incomplete=$((incomplete + 1))
    fi
done

if [ $incomplete -gt 0 ]; then
    echo "WARNING: ${incomplete} bootstraps are missing PhyloWGS completion markers."
    echo "Proceeding anyway, but aggregation may fail if PhyloWGS results are incomplete."
fi

# Submit post-processing job
postprocess_job=$(sbatch \
    --job-name="post_${TIMEPOINT_NAME}" \
    --output=logs/postprocess_${TIMEPOINT_NAME}_%j.out \
    --error=logs/postprocess_${TIMEPOINT_NAME}_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=24:00:00 \
    --export=ALL,TIMEPOINT_DIR="${TIMEPOINT_DIR}",TIMEPOINT_NAME="${TIMEPOINT_NAME}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}",READ_DEPTH="${READ_DEPTH}" \
    postprocess_worker.sh)

# Extract job ID  
postprocess_job_id=$(echo $postprocess_job | awk '{print $4}')
echo "Submitted post-processing job with ID: ${postprocess_job_id}"
echo "Monitor with: squeue -j ${postprocess_job_id}" 