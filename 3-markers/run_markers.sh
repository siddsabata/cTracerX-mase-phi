#!/bin/bash
# --------------------------------------------------
# This script runs marker selection analysis 
# for a single patient.
#
# It performs the following:
#  1. Accepts the patient ID and optionally the number of bootstraps and read depth.
#  2. Builds the bootstrap list (default: 1 to 5) and passes these parameters
#     along with the read depth (default: 1500) to the marker selection Python script.
#
# Usage:
#   ./run_markers.sh <patient_id> [num_bootstraps] [read_depth]
#
# Example:
#   ./run_markers.sh ppi_975 5 1500
#
# Note:
#   Ensure that your conda (or system) Python environment with the required 
#   dependencies is activated before running this script.
# --------------------------------------------------

set -e

# Get command line arguments
patient_id=$1
num_bootstraps=$2
read_depth=$3

echo "---------------------------------------"
echo "Running marker selection for patient: ${patient_id}"
echo "Bootstrap numbers: $(seq -s ' ' 1 $num_bootstraps)"
echo "Read depth: ${read_depth}"
echo "---------------------------------------"

# Get directory paths using dirname
SCRIPT_DIR="$(dirname "$0")"
RUN_SCRIPT="${SCRIPT_DIR}/run_data.py"

# Create a list of bootstrap numbers from 1 to num_bootstraps
bootstrap_list=$(seq -s ' ' 1 $num_bootstraps)

# Run the Python script
python "$RUN_SCRIPT" "${patient_id}" \
    --bootstrap-list $bootstrap_list \
    --read-depth $read_depth \
    --base-dir "${DATA_DIR}"

echo "Marker selection completed successfully for patient ${patient_id}." 