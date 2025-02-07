#!/bin/bash
# --------------------------------------------------
# This script runs PhyloWGS for all bootstrap iterations
# for a single patient.
#
# It performs the following:
#  1. Validates that the patient data and common directories exist.
#  2. Iterates through the bootstrap directories (e.g., bootstrap1, bootstrap2, ...)
#  3. For each bootstrap, checks for the required SSM file.
#  4. Creates directories for chains and temporary files.
#  5. Runs the PhyloWGS multievolve.py script.
#
# Usage:
#   ./run_phylowgs.sh <patient_directory> [num_chains] [num_bootstraps]
#
# Example:
#   ./run_phylowgs.sh ppi_975 5 5
#
# Note:
#   Ensure that your PhyloWGS installation is setup (e.g., via init.sh)
#   and that python2 and required dependencies are available.
# --------------------------------------------------

set -e

# Check for patient directory argument
if [ -z "$1" ]; then
    echo "Usage: $0 <patient_directory> [num_chains] [num_bootstraps]"
    exit 1
fi

patient_dir="$1"
num_chains="${2:-5}"
num_bootstraps="${3:-5}"
patient_id=$(basename "$patient_dir")

# Define the base directory for your data.
# Update DATA_ROOT if your data is located somewhere else.
DATA_ROOT="$(pwd)/data"
patient_data_dir="${DATA_ROOT}/${patient_dir}"
common_dir="${patient_data_dir}/common"

echo "---------------------------------------"
echo "Running PhyloWGS for patient: ${patient_id}"
echo "Patient data directory: ${patient_data_dir}"
echo "Common directory: ${common_dir}"
echo "Number of chains: ${num_chains}"
echo "Number of bootstraps: ${num_bootstraps}"
echo "---------------------------------------"

# Validate patient data and common directories
if [ ! -d "${patient_data_dir}" ]; then
    echo "Error: Patient data directory ${patient_data_dir} does not exist."
    exit 1
fi

if [ ! -d "${common_dir}" ]; then
    echo "Error: Common directory ${common_dir} does not exist."
    exit 1
fi

# Loop over each bootstrap iteration
for bootstrap in $(seq 1 "$num_bootstraps"); do
    echo "---------------------------------------"
    echo "Processing bootstrap ${bootstrap} for patient ${patient_id}"
    
    BOOTSTRAP_DIR="${common_dir}/bootstrap${bootstrap}"
    SSM_FILE="${BOOTSTRAP_DIR}/ssm_data_bootstrap${bootstrap}.txt"
    CNV_FILE="${BOOTSTRAP_DIR}/cnv_data_bootstrap${bootstrap}.txt"
    
    echo "Bootstrap directory: ${BOOTSTRAP_DIR}"
    echo "SSM file: ${SSM_FILE}"
    echo "CNV file: ${CNV_FILE}"
    
    # Check that the SSM file exists and show its header for debugging
    if [ ! -f "${SSM_FILE}" ]; then
        echo "Error: SSM file ${SSM_FILE} not found."
        echo "Contents of ${BOOTSTRAP_DIR}:"
        ls -la "${BOOTSTRAP_DIR}" || true
        exit 1
    fi
    
    echo "First few lines of SSM file:"
    head -n 5 "${SSM_FILE}"
    
    # Create directories for PhyloWGS output if they do not exist
    mkdir -p "${BOOTSTRAP_DIR}/chains"
    mkdir -p "${BOOTSTRAP_DIR}/tmp"
    
    # Run PhyloWGS multievolve.py with the specified parameters
    echo "Running multievolve.py for bootstrap ${bootstrap}..."
    python2 multievolve.py \
        --num-chains "${num_chains}" \
        --ssms "${SSM_FILE}" \
        --cnvs "${CNV_FILE}" \
        --output-dir "${BOOTSTRAP_DIR}/chains" \
        --tmp-dir "${BOOTSTRAP_DIR}/tmp"
    
    echo "Bootstrap ${bootstrap} completed."
done

echo "All bootstraps for patient ${patient_id} completed successfully." 