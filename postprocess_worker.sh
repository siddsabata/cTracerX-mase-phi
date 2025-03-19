#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=24:00:00

# This script runs the aggregation and markers steps after PhyloWGS is complete

# Exit on error
set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting post-processing for ${TIMEPOINT_NAME}"

# Initialize conda
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Create markers directory if it doesn't exist
mkdir -p "${TIMEPOINT_DIR}/.markers"

# Verify all PhyloWGS bootstraps are complete
for bootstrap_num in $(seq 1 $NUM_BOOTSTRAPS); do
    marker_file="${TIMEPOINT_DIR}/bootstrap_${bootstrap_num}/.markers/phylowgs_complete"
    if [ ! -f "${marker_file}" ]; then
        echo "ERROR: Bootstrap $bootstrap_num PhyloWGS not complete!"
        echo "Missing marker: ${marker_file}"
        exit 1
    fi
done

# Function to run a step
run_step() {
    local step=$1
    
    # Skip if step is already completed
    if [ -f "${TIMEPOINT_DIR}/.markers/${step}_complete" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step '$step' already completed"
        return 0
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running step '$step'"
    
    case "$step" in
        "aggregation")
            conda activate aggregation_env || {
                echo "Failed to activate aggregation_env"
                exit 1
            }
            
            # Create aggregation directory
            mkdir -p "${TIMEPOINT_DIR}/aggregation"
            
            # Generate bootstrap list
            bootstrap_list=$(seq -s ' ' 1 $NUM_BOOTSTRAPS)
            
            echo "Running aggregation with bootstrap list: $bootstrap_list"
            python 3-aggregation/process_tracerx_bootstrap.py "$TIMEPOINT_NAME" \
                --bootstrap-list $bootstrap_list \
                --base-dir "$(dirname "$TIMEPOINT_DIR")"
            ;;
            
        "markers")
            conda activate markers_env || {
                echo "Failed to activate markers_env"
                exit 1
            }
            
            # Create markers directory
            mkdir -p "${TIMEPOINT_DIR}/markers"
            
            echo "Running marker selection with ${NUM_BOOTSTRAPS} bootstraps"
            python 4-markers/run_data.py "$TIMEPOINT_NAME" \
                --bootstrap-list $(seq 1 $NUM_BOOTSTRAPS) \
                --read-depth "${READ_DEPTH}"
            ;;
            
        *)
            echo "Unknown step: $step"
            return 1
            ;;
    esac
    
    # Mark as complete
    touch "${TIMEPOINT_DIR}/.markers/${step}_complete"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully completed step '$step'"
}

# Run aggregation and markers steps
run_step "aggregation"
run_step "markers"

# Mark all processing as complete
touch "${TIMEPOINT_DIR}/.markers/processing_complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All post-processing completed for ${TIMEPOINT_NAME}" 