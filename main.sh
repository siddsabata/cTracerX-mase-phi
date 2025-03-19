#!/bin/bash
# --------------------------------------------------
# Main entry script for cTracerX-mase-phi pipeline
#
# This script orchestrates the entire pipeline:
# 1. Initial preprocessing (creating timepoint directories)
# 2. Bootstrapping each timepoint
# 3. Parallelized PhyloWGS processing
# 4. Post-processing (aggregation and markers)
#
# Usage: 
#   bash main.sh
# --------------------------------------------------

set -e  # Exit on any error

# Create logs directory
mkdir -p logs

# Configuration variables - EDIT THESE FOR YOUR ENVIRONMENT
export DATA_DIR="/home/ssabata/patient_data/tracerx_2017/"   # <-- EDIT THIS
export INPUT_FILE="/home/ssabata/patient_data/tracerx_2017/cruk0044.csv"     # <-- EDIT THIS
export NUM_BOOTSTRAPS=100   # Number of bootstrap iterations
export NUM_CHAINS=5         # Number of PhyloWGS chains
export READ_DEPTH=1500      # Read depth for marker selection
export CHUNK_SIZE=10        # Number of bootstraps per PhyloWGS job

# Print configuration
echo "=========================================================="
echo "Pipeline Configuration:"
echo "=========================================================="
echo "Data Directory:    ${DATA_DIR}"
echo "Input File:        ${INPUT_FILE}"
echo "Bootstrap Count:   ${NUM_BOOTSTRAPS}"
echo "PhyloWGS Chains:   ${NUM_CHAINS}"
echo "Read Depth:        ${READ_DEPTH}"
echo "Chunk Size:        ${CHUNK_SIZE} (bootstraps per PhyloWGS job)"
echo "=========================================================="

# Check if input file exists
if [ ! -f "${INPUT_FILE}" ]; then
    echo "ERROR: Input file not found: ${INPUT_FILE}"
    exit 1
fi

# Create data directory
mkdir -p "${DATA_DIR}"
echo "Using data directory: ${DATA_DIR}"

echo "=========================================================="
echo "STEP 1: Starting preprocessing and bootstrapping"
echo "=========================================================="

# Submit the preprocess_worker job to handle initial preprocessing and bootstrapping
preprocess_job=$(sbatch \
    --job-name=preprocess_ctrl \
    --output=logs/preprocess_ctrl_%j.out \
    --error=logs/preprocess_ctrl_%j.err \
    --partition=pool1 \
    --cpus-per-task=2 \
    --mem=8G \
    --time=48:00:00 \
    --export=ALL,DATA_DIR="${DATA_DIR}",INPUT_FILE="${INPUT_FILE}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}" \
    preprocess_worker.sh)

preprocess_job_id=$(echo ${preprocess_job} | awk '{print $4}')
echo "Submitted preprocessing controller job with ID: ${preprocess_job_id}"

echo "=========================================================="
echo "STEP 2: Setting up PhyloWGS processing (will start after bootstrapping completes)"
echo "=========================================================="

# Submit the bootstrap job ourselves with a dependency on the preprocess job
bootstrap_job=$(sbatch \
    --dependency=afterok:${preprocess_job_id} \
    --job-name=bootstrap_all \
    --output=logs/bootstrap_all_%j.out \
    --error=logs/bootstrap_all_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=24:00:00 \
    --wrap="#!/bin/bash
    set -e
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Starting bootstrapping for ALL timepoints\"
    
    # Source conda
    source ~/miniconda3/bin/activate
    conda activate preprocess_env
    
    # Check if timepoint list exists
    timepoint_list_file=\"${DATA_DIR}/timepoint_list.txt\"
    if [ ! -f \"\${timepoint_list_file}\" ]; then
        echo \"ERROR: Timepoint list file not found: \${timepoint_list_file}\"
        exit 1
    fi
    
    # Process each timepoint sequentially in a single job
    total_timepoints=\$(wc -l < \"\${timepoint_list_file}\")
    echo \"Processing \${total_timepoints} timepoints\"
    
    current=1
    while read -r timepoint_dir; do
        timepoint_name=\$(basename \"\${timepoint_dir}\")
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Processing timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        
        # Run bootstrap processing directly 
        ./1-bootstrap/run_bootstrap.sh \"\${timepoint_dir}\" ${NUM_BOOTSTRAPS}
        
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Completed timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        current=\$((current + 1))
    done < \"\${timepoint_list_file}\"
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] All timepoints have been bootstrapped successfully\"")

bootstrap_job_id=$(echo ${bootstrap_job} | awk '{print $4}')
echo "Submitted bootstrap job with ID: ${bootstrap_job_id}"

# Submit the pipeline controller job (depends on bootstrap completion)
phylowgs_job=$(sbatch \
    --dependency=afterok:${bootstrap_job_id} \
    --job-name=phylowgs_ctrl \
    --output=logs/phylowgs_ctrl_%j.out \
    --error=logs/phylowgs_ctrl_%j.err \
    --partition=pool1 \
    --cpus-per-task=2 \
    --mem=8G \
    --time=48:00:00 \
    --export=ALL,DATA_DIR="${DATA_DIR}",NUM_BOOTSTRAPS="${NUM_BOOTSTRAPS}",NUM_CHAINS="${NUM_CHAINS}",READ_DEPTH="${READ_DEPTH}",CHUNK_SIZE="${CHUNK_SIZE}" \
    pipeline_controller.sh)

phylowgs_job_id=$(echo ${phylowgs_job} | awk '{print $4}')
echo "Submitted PhyloWGS controller job with ID: ${phylowgs_job_id}"

echo "=========================================================="
echo "Pipeline initiated successfully!"
echo "=========================================================="
echo "Job dependencies:"
echo " - preprocess_ctrl (${preprocess_job_id}) → bootstrap_all (${bootstrap_job_id}) → phylowgs_ctrl (${phylowgs_job_id})"
echo
echo "Monitor job progress with: squeue -u $USER"
echo "View logs in: logs/ directory"
echo "Results will be available in: ${DATA_DIR}"
echo "==========================================================" 