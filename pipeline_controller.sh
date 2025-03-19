#!/bin/bash
# Main controller script for parallelized PhyloWGS pipeline

set -e

# Default configuration
: ${DATA_DIR:?"Must specify DATA_DIR"}
: ${NUM_BOOTSTRAPS:=100}
: ${NUM_CHAINS:=5}
: ${READ_DEPTH:=1500}
: ${CHUNK_SIZE:=10}

# Calculate number of chunks
NUM_CHUNKS=$(( (NUM_BOOTSTRAPS + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Log configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pipeline Configuration:"
echo "  DATA_DIR: $DATA_DIR"
echo "  NUM_BOOTSTRAPS: $NUM_BOOTSTRAPS"
echo "  NUM_CHAINS: $NUM_CHAINS"
echo "  READ_DEPTH: $READ_DEPTH"
echo "  CHUNK_SIZE: $CHUNK_SIZE"
echo "  Resulting chunks: $NUM_CHUNKS"

# Read timepoint list
timepoint_list_file="${DATA_DIR}/timepoint_list.txt"
if [ ! -f "${timepoint_list_file}" ]; then
    echo "ERROR: Timepoint list file not found: ${timepoint_list_file}"
    exit 1
fi

# Process each timepoint sequentially
while read -r timepoint_dir; do
    # Extract timepoint name
    timepoint_name=$(basename "${timepoint_dir}")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing timepoint: ${timepoint_name}"
    
    # Check if the bootstrapping is complete
    if [ ! -f "${timepoint_dir}/.markers/bootstrap_complete" ]; then
        echo "ERROR: Bootstrap not completed for ${timepoint_name}"
        echo "Please run the preprocessing and bootstrap steps first"
        exit 1
    fi
    
    # Submit PhyloWGS jobs in chunks
    echo "Submitting ${NUM_CHUNKS} PhyloWGS chunk jobs for ${timepoint_name}..."
    phylowgs_job=$(sbatch \
        --job-name="phy_${timepoint_name}" \
        --output="logs/phylowgs_${timepoint_name}_%A_%a.out" \
        --error="logs/phylowgs_${timepoint_name}_%A_%a.err" \
        --array=0-$((NUM_CHUNKS-1)) \
        --export=ALL,TIMEPOINT_DIR="${timepoint_dir}",TIMEPOINT_NAME="${timepoint_name}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}",NUM_CHAINS="${NUM_CHAINS}",CHUNK_SIZE="${CHUNK_SIZE}" \
        phylowgs_worker.sh)
    
    # Extract job ID
    phylowgs_job_id=$(echo $phylowgs_job | awk '{print $4}' | cut -d'.' -f1)
    echo "Submitted PhyloWGS jobs with array ID ${phylowgs_job_id}"
    
    # Submit post-processing job (depends on all PhyloWGS chunks completing)
    echo "Submitting post-processing job for ${timepoint_name}..."
    postprocess_job=$(sbatch \
        --dependency=afterok:${phylowgs_job_id} \
        --job-name="post_${timepoint_name}" \
        --output="logs/postprocess_${timepoint_name}_%j.out" \
        --error="logs/postprocess_${timepoint_name}_%j.err" \
        --export=ALL,TIMEPOINT_DIR="${timepoint_dir}",TIMEPOINT_NAME="${timepoint_name}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}",READ_DEPTH="${READ_DEPTH}" \
        postprocess_worker.sh)
    
    # Extract job ID
    postprocess_job_id=$(echo $postprocess_job | awk '{print $4}')
    echo "Submitted post-processing job ${postprocess_job_id}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] All jobs submitted for timepoint: ${timepoint_name}"
    echo "-----------------------------------------------------"
    
done < "${timepoint_list_file}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All timepoints have been queued for processing" 