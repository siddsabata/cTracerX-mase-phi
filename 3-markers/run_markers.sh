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

# Check for patient ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <patient_id> [num_bootstraps] [read_depth]"
    exit 1
fi

patient_id="$1"
num_bootstraps="${2:-5}"
read_depth="${3:-1500}"

# Build a bootstrap list (space-separated)
bootstrap_list=$(seq -s " " 1 "${num_bootstraps}")

echo "---------------------------------------"
echo "Running marker selection for patient: ${patient_id}"
echo "Bootstrap numbers: ${bootstrap_list}"
echo "Read depth: ${read_depth}"
echo "---------------------------------------"

# Run the marker selection Python script with the provided parameters
python run_data.py "${patient_id}" --bootstrap-list ${bootstrap_list} --read-depth "${read_depth}"

echo "Marker selection completed successfully for patient ${patient_id}." 