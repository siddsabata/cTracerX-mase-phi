#!/bin/bash

# Base configuration
export DATA_DIR="/home/ssabata/patient_data/mafs_test"
export INPUT_FILE="${DATA_DIR}/patients_n3_t5.csv"

# Create data directory
mkdir -p "${DATA_DIR}"

# Run initial preprocessing to create patient directories
conda activate preprocess_env
python 0-preprocess/process_tracerX.py \
    -i "${INPUT_FILE}" \
    -o "${DATA_DIR}"

# Count number of patients for array job
num_patients=$(tail -n +2 "${INPUT_FILE}" | cut -d',' -f1 | sort -u | wc -l)
echo "Found ${num_patients} patients to process"

# Submit array job
sbatch --array=0-$((num_patients-1)) main.sh 