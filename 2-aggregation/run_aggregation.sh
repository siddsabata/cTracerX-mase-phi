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

# Check for patient ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <patient_id> [bootstrap_list...]"
    exit 1
fi

patient_id="$1"
shift

# If no bootstrap numbers are given, use default values
if [ "$#" -eq 0 ]; then
    bootstrap_list="1 2 3 4 5"
else
    bootstrap_list="$@"
fi

# Define the base directory for your data.
# Update DATA_ROOT if necessary.
DATA_ROOT="${DATA_DIR}"

echo "---------------------------------------"
echo "Aggregating data for patient: ${patient_id}"
echo "Bootstrap numbers: ${bootstrap_list}"
echo "Patient data directory: ${DATA_ROOT}/${patient_id}"
echo "---------------------------------------"

# Run the aggregation Python script with specified parameters
python "$(dirname $0)/process_tracerx_bootstrap.py" "${patient_id}" \
    --bootstrap-list ${bootstrap_list} \
    --num-blood 0 \
    --num-tissue 5 \
    --type common \
    --method phylowgs \
    --num-chain 5 \
    --base-dir "${DATA_ROOT}"

echo "Aggregation completed successfully for patient ${patient_id}." 