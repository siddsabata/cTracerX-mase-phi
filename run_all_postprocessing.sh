#!/bin/bash
# --------------------------------------------------
# Step 3 (alternative): Run post-processing for all timepoints of a patient
#
# This script:
# 1. Finds all timepoints for a given patient
# 2. Runs post-processing for each timepoint in sequence
#
# Usage: 
#   bash run_all_postprocessing.sh <data_dir> [patient_id] [num_bootstraps] [read_depth]
# Example:
#   bash run_all_postprocessing.sh /path/to/data/dir CRUK0044 100 1500
# --------------------------------------------------

set -e

# Process arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <data_dir> [patient_id] [num_bootstraps] [read_depth]"
    exit 1
fi

DATA_DIR="$1"
PATIENT_ID="${2:-}"  # Optional - if omitted, will process all timepoints in DATA_DIR
NUM_BOOTSTRAPS="${3:-100}"
READ_DEPTH="${4:-1500}"

# Create logs directory
mkdir -p logs

echo "==========================================================="
echo "Running post-processing for all timepoints"
echo "==========================================================="
echo "Data directory: ${DATA_DIR}"
if [ -n "${PATIENT_ID}" ]; then
    echo "Patient ID: ${PATIENT_ID}"
fi
echo "Number of bootstraps: ${NUM_BOOTSTRAPS}"
echo "Read depth: ${READ_DEPTH}"
echo "==========================================================="

# Find all timepoint directories
if [ -n "${PATIENT_ID}" ]; then
    # If patient ID specified, find only timepoints for that patient
    timepoint_dirs=($(find "${DATA_DIR}" -type d -path "*/${PATIENT_ID}_*" -not -path "*/\.*"))
else
    # Otherwise process all timepoints in the data directory
    timepoint_dirs=($(find "${DATA_DIR}" -type d -path "*/[A-Z]*_*_*" -not -path "*/\.*"))
fi

# Check if we found any timepoints
if [ ${#timepoint_dirs[@]} -eq 0 ]; then
    if [ -n "${PATIENT_ID}" ]; then
        echo "ERROR: No timepoints found for patient ${PATIENT_ID} in ${DATA_DIR}"
    else
        echo "ERROR: No timepoints found in ${DATA_DIR}"
    fi
    exit 1
fi

echo "Found ${#timepoint_dirs[@]} timepoints to process:"
for dir in "${timepoint_dirs[@]}"; do
    echo "  - $(basename "$dir")"
done
echo ""

# Process each timepoint
for ((i=0; i<${#timepoint_dirs[@]}; i++)); do
    timepoint_dir="${timepoint_dirs[$i]}"
    timepoint_name=$(basename "${timepoint_dir}")
    
    echo "[$((i+1))/${#timepoint_dirs[@]}] Processing timepoint: ${timepoint_name}"
    
    # Run the post-processing script for this timepoint
    ./run_postprocessing.sh "${timepoint_dir}" "${NUM_BOOTSTRAPS}" "${READ_DEPTH}"
    
    echo "Submitted post-processing job for ${timepoint_name}"
    echo "---------------------------------------------------------------"
done

echo "==========================================================="
echo "Post-processing jobs submitted for all ${#timepoint_dirs[@]} timepoints"
echo "Monitor jobs with: squeue -u $USER"
echo "===========================================================" 