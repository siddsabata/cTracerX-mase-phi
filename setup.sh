#!/bin/bash

# Base configuration
export DATA_DIR="/home/ssabata/patient_data/tracerx_test"
export INPUT_FILE="${DATA_DIR}/patients_n3_t5.csv"

# Check if input file exists
if [ ! -f "${INPUT_FILE}" ]; then
    echo "Error: Input file not found: ${INPUT_FILE}"
    exit 1
fi

# Create data directory
mkdir -p "${DATA_DIR}"
echo "Using data directory: ${DATA_DIR}"

# Run initial preprocessing to create patient directories
conda activate preprocess_env
echo "Processing input file: ${INPUT_FILE}"
python 0-preprocess/process_tracerX.py \
    -i "${INPUT_FILE}" \
    -o "${DATA_DIR}"

# Count number of patients for array job
num_patients=$(tail -n +2 "${INPUT_FILE}" | cut -d',' -f1 | sort -u | wc -l)
echo "Found ${num_patients} patients to process"

# Submit array job
echo "Submitting SLURM array job for ${num_patients} patients"
sbatch --array=0-$((num_patients-1)) main.sh 