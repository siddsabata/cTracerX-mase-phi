#!/bin/bash
# --------------------------------------------------
# Main entry script for cTracerX-mase-phi pipeline
#
# This script:
# 1. Processes the input CSV to create timepoint directories
# 2. Counts the total number of timepoint directories
# 3. Submits SLURM array jobs to process each timepoint
#
# Usage: 
#   bash main.sh
# --------------------------------------------------

set -e  # Exit on any error

# Activate conda base environment
echo "Activating conda environment..."
source ~/miniconda3/bin/activate || {
    echo "ERROR: Failed to source conda. Please ensure conda is installed."
    exit 1
}

# Activate preprocess environment
conda activate preprocess_env || {
    echo "ERROR: Failed to activate preprocess_env"
    echo "Please run init.sh to create the conda environments first:"
    echo "  bash init.sh"
    exit 1
}

# Configuration variables - EDIT THESE FOR YOUR ENVIRONMENT
export DATA_DIR="/home/ssabata/patient_data/tracerx_2017/"   # <-- EDIT THIS
export INPUT_FILE="/home/ssabata/patient_data/tracerx_2017/cruk0044.csv"     # <-- EDIT THIS
export NUM_BOOTSTRAPS=100   # Number of bootstrap iterations
export NUM_CHAINS=5         # Number of PhyloWGS chains
export READ_DEPTH=1500      # Read depth for marker selection

# Print configuration
echo "=========================================================="
echo "Pipeline Configuration:"
echo "=========================================================="
echo "Data Directory:    ${DATA_DIR}"
echo "Input File:        ${INPUT_FILE}"
echo "Bootstrap Count:   ${NUM_BOOTSTRAPS}"
echo "PhyloWGS Chains:   ${NUM_CHAINS}"
echo "Read Depth:        ${READ_DEPTH}"
echo "=========================================================="

# Check if input file exists
if [ ! -f "${INPUT_FILE}" ]; then
    echo "ERROR: Input file not found: ${INPUT_FILE}"
    exit 1
fi

# Create data directory
mkdir -p "${DATA_DIR}"
echo "Using data directory: ${DATA_DIR}"

# Run process_tracerX.py to create timepoint directories
echo "=========================================================="
echo "STEP 1: Processing input file to create timepoint directories"
echo "=========================================================="
echo "Running: process_tracerX.py -i ${INPUT_FILE} -o ${DATA_DIR}"

python 0-preprocess/process_tracerX.py -i "${INPUT_FILE}" -o "${DATA_DIR}"

echo "Initial preprocessing complete. Timepoint directories created."

# Find all timepoint directories
echo "Searching for timepoint directories..."
readarray -t all_timepoint_dirs < <(find "${DATA_DIR}" -type d -path "*/[A-Z]*_*_*" -not -path "*/\.*")

# Count total number of timepoint directories
num_timepoints=${#all_timepoint_dirs[@]}
echo "Found ${num_timepoints} total timepoint directories to process"

# Write all timepoint paths to a file for slurm_jobs.sh to read
echo "Writing timepoint paths to file..."
timepoint_list_file="${DATA_DIR}/timepoint_list.txt"
printf "%s\n" "${all_timepoint_dirs[@]}" > "${timepoint_list_file}"
echo "Timepoint list saved to: ${timepoint_list_file}"

# Submit SLURM array job - one job per timepoint
echo "=========================================================="
echo "STEP 2: Submitting SLURM jobs to process each timepoint"
echo "=========================================================="
echo "Submitting SLURM array job for ${num_timepoints} timepoints"
echo "Each job will process one timepoint with ${NUM_BOOTSTRAPS} bootstraps"

job_id=$(sbatch --parsable --export=ALL,DATA_DIR,NUM_BOOTSTRAPS,NUM_CHAINS,READ_DEPTH --array=0-$((num_timepoints-1)) slurm_jobs.sh)

if [ -n "$job_id" ]; then
    echo "Success! SLURM job array submitted with ID: ${job_id}"
    echo "Monitor job progress with:"
    echo "  squeue -u $USER"
    echo "  tail -f logs/mase_phi_${job_id}_*.out"
else
    echo "ERROR: Failed to submit SLURM job"
    exit 1
fi

echo "=========================================================="
echo "Pipeline initiated successfully!"
echo "Results will be available in: ${DATA_DIR}"
echo "==========================================================" 