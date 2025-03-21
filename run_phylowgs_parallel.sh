#!/bin/bash
# --------------------------------------------------
# Step 2: Run PhyloWGS in parallel for a timepoint
#
# This script:
# 1. Submits parallel PhyloWGS jobs for a specific timepoint by chunking bootstrap samples
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

# Create marker directories
mkdir -p "${TIMEPOINT_DIR}/.markers/phylowgs_chunks"

# Submit PhyloWGS jobs as an array
sbatch \
    --job-name="phy_${TIMEPOINT_NAME}" \
    --output="logs/phylowgs_${TIMEPOINT_NAME}_%A_%a.out" \
    --error="logs/phylowgs_${TIMEPOINT_NAME}_%A_%a.err" \
    --array=0-$((NUM_CHUNKS-1)) \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=48:00:00 \
    --wrap="#!/bin/bash
    set -e
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Starting PhyloWGS worker for ${TIMEPOINT_NAME}\"
    echo \"Processing chunk \${SLURM_ARRAY_TASK_ID} of bootstraps\"
    
    # Calculate bootstrap range for this chunk
    start_bootstrap=\$((SLURM_ARRAY_TASK_ID * ${CHUNK_SIZE} + 1))
    end_bootstrap=\$((start_bootstrap + ${CHUNK_SIZE} - 1))
    if [ \$end_bootstrap -gt ${NUM_BOOTSTRAPS} ]; then
        end_bootstrap=${NUM_BOOTSTRAPS}
    fi
    
    echo \"Will process bootstraps \$start_bootstrap through \$end_bootstrap\"
    
    # Initialize conda
    source ~/miniconda3/bin/activate
    conda activate phylowgs_env || {
        echo \"Failed to activate phylowgs_env\"
        exit 1
    }
    
    # Process each bootstrap in this chunk
    for bootstrap_num in \$(seq \$start_bootstrap \$end_bootstrap); do
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Processing bootstrap \$bootstrap_num\"
        
        # Skip if this bootstrap's PhyloWGS is already complete
        marker_file=\"${TIMEPOINT_DIR}/bootstrap_\${bootstrap_num}/.markers/phylowgs_complete\"
        if [ -f \"\${marker_file}\" ]; then
            echo \"Bootstrap \$bootstrap_num already processed, skipping\"
            continue
        fi
        
        # Create output directory
        bootstrap_dir=\"${TIMEPOINT_DIR}/bootstrap_\${bootstrap_num}\"
        mkdir -p \"\${bootstrap_dir}/.markers\"
        
        # Run PhyloWGS using the updated run_phylowgs.sh script
        ./2-phylowgs/run_phylowgs.sh \"${TIMEPOINT_DIR}\" \${bootstrap_num} ${NUM_CHAINS}
        
        # Mark this bootstrap as complete
        touch \"\${bootstrap_dir}/.markers/phylowgs_complete\"
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Completed bootstrap \$bootstrap_num\"
    done
    
    # Mark this chunk as complete
    touch \"${TIMEPOINT_DIR}/.markers/phylowgs_chunks/chunk_\${SLURM_ARRAY_TASK_ID}_complete\"
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] PhyloWGS worker completed chunk \${SLURM_ARRAY_TASK_ID}\"
    "

echo "Submitted PhyloWGS jobs"
echo "Monitor with: squeue -u $USER -n phy_${TIMEPOINT_NAME}"
echo
echo "Once all PhyloWGS jobs complete for all timepoints, run the post-processing script." 