#!/bin/bash
# --------------------------------------------------
# Step 1: Preprocess and bootstrap
#
# This script:
# 1. Submits a job to run preprocessing to create timepoint directories
# 2. Submits a job to run bootstrapping on all timepoints
#
# Usage: 
#   bash preprocess_bootstrap.sh <input_file> <data_dir> [num_bootstraps]
# Example:
#   bash preprocess_bootstrap.sh /path/to/input.csv /path/to/data/dir 100
# --------------------------------------------------

set -e

# Process arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <input_file> <data_dir> [num_bootstraps]"
    exit 1
fi

INPUT_FILE="$1"
DATA_DIR="$2"
NUM_BOOTSTRAPS="${3:-100}"  # Default 100 if not specified

# Create logs directory
mkdir -p logs

# Check if input file exists
if [ ! -f "${INPUT_FILE}" ]; then
    echo "ERROR: Input file not found: ${INPUT_FILE}"
    exit 1
fi

# Create data directory
mkdir -p "${DATA_DIR}"
echo "Using data directory: ${DATA_DIR}"

echo "==========================================================="
echo "STEP 1A: Submitting preprocessing job"
echo "==========================================================="

# Submit preprocessing job
preprocess_job=$(sbatch \
    --job-name=preprocess \
    --output=logs/preprocess_%j.out \
    --error=logs/preprocess_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=4:00:00 \
    --wrap="#!/bin/bash
    set -e
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Starting preprocessing\"
    
    # Source conda
    source ~/miniconda3/bin/activate
    conda activate preprocess_env
    
    # Run preprocessing
    ./0-preprocess/run_preprocess.sh ${INPUT_FILE} ${DATA_DIR}
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Preprocessing completed\"")

preprocess_job_id=$(echo ${preprocess_job} | awk '{print $4}')
echo "Submitted preprocessing job with ID: ${preprocess_job_id}"

echo "==========================================================="
echo "STEP 1B: Submitting bootstrapping job"
echo "==========================================================="

# Submit bootstrapping job with dependency on preprocessing
bootstrap_job=$(sbatch \
    --job-name=bootstrap_all \
    --output=logs/bootstrap_all_%j.out \
    --error=logs/bootstrap_all_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=72:00:00 \
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
    
    # Process each timepoint sequentially
    total_timepoints=\$(wc -l < \"\${timepoint_list_file}\")
    echo \"Processing \${total_timepoints} timepoints\"
    
    current=1
    while read -r timepoint_dir; do
        timepoint_name=\$(basename \"\${timepoint_dir}\")
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Processing timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        
        # Run bootstrap processing
        ./1-bootstrap/run_bootstrap.sh \"\${timepoint_dir}\" ${NUM_BOOTSTRAPS}
        
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Completed timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        current=\$((current + 1))
    done < \"\${timepoint_list_file}\"
    
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] All timepoints have been bootstrapped successfully\"")

bootstrap_job_id=$(echo ${bootstrap_job} | awk '{print $4}')
echo "Submitted bootstrap job with ID: ${bootstrap_job_id}"
echo "The bootstrap job will start after preprocessing is complete (job ${preprocess_job_id})"
echo "Monitor jobs with: squeue -j ${preprocess_job_id},${bootstrap_job_id}" 