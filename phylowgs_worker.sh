#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=48:00:00

# This script processes a specific chunk of bootstraps for PhyloWGS

# Exit on error
set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting PhyloWGS worker for ${TIMEPOINT_NAME}"
echo "Processing chunk ${SLURM_ARRAY_TASK_ID} of bootstraps"

# Calculate bootstrap range for this chunk
start_bootstrap=$((SLURM_ARRAY_TASK_ID * CHUNK_SIZE + 1))
end_bootstrap=$((start_bootstrap + CHUNK_SIZE - 1))
if [ $end_bootstrap -gt $NUM_BOOTSTRAPS ]; then
    end_bootstrap=$NUM_BOOTSTRAPS
fi

echo "Will process bootstraps $start_bootstrap through $end_bootstrap"

# Initialize conda
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Activate phylowgs environment - hardcoded environment name for simplicity
conda activate phylowgs_env || {
    echo "Failed to activate phylowgs_env"
    exit 1
}

# Create marker directories
mkdir -p "${TIMEPOINT_DIR}/.markers/phylowgs_chunks"

# Process each bootstrap in this chunk
for bootstrap_num in $(seq $start_bootstrap $end_bootstrap); do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing bootstrap $bootstrap_num"
    
    # Define directories
    input_bootstrap_dir="${TIMEPOINT_DIR}/bootstrap${bootstrap_num}"  # Input directory (no underscore)
    bootstrap_dir="${TIMEPOINT_DIR}/bootstrap_${bootstrap_num}"       # Output directory (with underscore)
    results_dir="${bootstrap_dir}/phylowgs"
    marker_dir="${bootstrap_dir}/.markers"
    
    # Skip if this bootstrap's PhyloWGS is already complete
    if [ -f "${marker_dir}/phylowgs_complete" ]; then
        echo "Bootstrap $bootstrap_num already processed, skipping"
        continue
    fi
    
    # Make required directories
    mkdir -p "${results_dir}" "${marker_dir}"
    
    # Find SSM and CNV files
    ssm_file="${input_bootstrap_dir}/ssm.txt"
    cnv_file="${input_bootstrap_dir}/cnv.txt"
    
    if [ ! -f "${ssm_file}" ]; then
        echo "ERROR: SSM file not found for bootstrap $bootstrap_num"
        exit 1
    fi
    
    # Create empty CNV file if it doesn't exist
    if [ ! -f "${cnv_file}" ]; then
        echo "CNV file not found for bootstrap $bootstrap_num, creating empty file"
        touch "${cnv_file}"
    fi
    
    # Run PhyloWGS
    echo "Running PhyloWGS for bootstrap $bootstrap_num"
    
    # Set the working directory for phylowgs
    cd 2-phylowgs/phylowgs
    
    # Run with multiple chains
    for chain in $(seq 1 $NUM_CHAINS); do
        chain_dir="${results_dir}/chain${chain}"
        mkdir -p "${chain_dir}"
        
        echo "Running chain $chain for bootstrap $bootstrap_num"
        
        # Run PhyloWGS (using temp dir to avoid file conflicts)
        TMPDIR=$(mktemp -d)
        python2 multievolve.py --num-chains 1 --ssms "${ssm_file}" --cnvs "${cnv_file}" \
            --output-dir "${TMPDIR}" --seed $((bootstrap_num * 100 + chain))
        
        # Move results to final location
        mv ${TMPDIR}/* "${chain_dir}/"
        rmdir ${TMPDIR}
        
        echo "Completed chain $chain for bootstrap $bootstrap_num"
    done
    
    # Mark this bootstrap as complete
    touch "${marker_dir}/phylowgs_complete"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed bootstrap $bootstrap_num"
done

# Mark this chunk as complete
touch "${TIMEPOINT_DIR}/.markers/phylowgs_chunks/chunk_${SLURM_ARRAY_TASK_ID}_complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] PhyloWGS worker completed chunk ${SLURM_ARRAY_TASK_ID}" 