#!/bin/bash
# --------------------------------------------------
# This script processes the tracerx bootstrap aggregation 
# for a single patient.
#
# It performs the following:
#  1. Accepts the patient ID and a list of bootstrap numbers.
#  2. Sets default parameters for the number of blood (0) and tissue (5) samples,
#     analysis type, method, number of chains, and the data base directory.
#  3. Invokes the process_tracerx_bootstrap.py script with the provided parameters.
#
# Usage:
#   ./run_aggregation.sh <patient_id> [bootstrap_number1 bootstrap_number2 ...]
#
# Example:
#   ./run_aggregation.sh 256 1 2 3 4 5
#
# Note:
#   Ensure that the required conda or system Python environment is activated
#   before running this script.
# --------------------------------------------------

set -e

# Get command line arguments
patient_id=$1
num_bootstraps=$2  # This is the total number of bootstraps

echo "---------------------------------------"
echo "Aggregating data for patient: ${patient_id}"
echo "Bootstrap numbers: ${num_bootstraps}"
echo "Patient data directory: ${DATA_DIR}/${patient_id}"
echo "---------------------------------------"

# Create a list of bootstrap numbers from 1 to num_bootstraps
bootstrap_list=$(seq -s ' ' 1 $num_bootstraps)

# Run the Python script with all bootstrap numbers
python ./2-aggregation/process_tracerx_bootstrap.py "${patient_id}" \
    --bootstrap-list $bootstrap_list \
    --base-dir "${DATA_DIR}"

echo "Aggregation completed successfully for patient ${patient_id}." 