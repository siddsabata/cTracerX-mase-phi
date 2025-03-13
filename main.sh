#!/bin/bash
# --------------------------------------------------
# Main entry script for cTracerX-mase-phi pipeline
#
# This script:
# 1. Processes the input CSV to create timepoint directories
# 2. Counts the number of patients 
# 3. Submits SLURM array jobs to process each patient
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
export DATA_DIR="/path/to/output/directory"   # <-- EDIT THIS
export INPUT_FILE="/path/to/cruk0044.csv"     # <-- EDIT THIS
export NUM_BOOTSTRAPS=100
export NUM_CHAINS=5
export READ_DEPTH=1500

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

# Count number of patients for array job
num_patients=$(tail -n +2 "${INPUT_FILE}" | cut -d',' -f1 | sort -u | wc -l)
echo "Found ${num_patients} patients to process"

# Submit SLURM array job
echo "=========================================================="
echo "STEP 2: Submitting SLURM jobs to process each patient/timepoint"
echo "=========================================================="
echo "Submitting SLURM array job for ${num_patients} patients"
echo "Each job will process all timepoints for one patient"

job_id=$(sbatch --parsable --array=0-$((num_patients-1)) slurm_jobs.sh)

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