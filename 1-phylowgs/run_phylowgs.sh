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

# Get command line arguments
patient_id=$1
num_chains=$2
num_bootstraps=$3

echo "---------------------------------------"
echo "Running PhyloWGS for patient: ${patient_id}"
echo "Number of chains: ${num_chains}"
echo "Number of bootstraps: ${num_bootstraps}"
echo "Patient data directory: ${DATA_DIR}/${patient_id}"
echo "---------------------------------------"

# Get directory paths using dirname
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # Get absolute path
PHYLOWGS_PATH="${SCRIPT_DIR}/phylowgs"
MULTIEVOLVE="${PHYLOWGS_PATH}/multievolve.py"
WRITE_RESULTS="${PHYLOWGS_PATH}/write_results.py"

# Verify PhyloWGS scripts exist
if [ ! -f "$MULTIEVOLVE" ]; then
    echo "Error: multievolve.py not found at $MULTIEVOLVE"
    exit 1
fi

if [ ! -f "$WRITE_RESULTS" ]; then
    echo "Error: write_results.py not found at $WRITE_RESULTS"
    exit 1
fi

# Process each bootstrap
for i in $(seq 1 $num_bootstraps); do
    echo "Processing bootstrap ${i}..."
    
    # Set up paths
    BOOTSTRAP_DIR="${DATA_DIR}/${patient_id}/common/bootstrap${i}"
    SSM_FILE="${BOOTSTRAP_DIR}/ssm_data_bootstrap${i}.txt"
    CNV_FILE="${BOOTSTRAP_DIR}/cnv_data_bootstrap${i}.txt"
    
    # Check if required files exist
    if [ ! -f "$SSM_FILE" ]; then
        echo "Error: SSM file not found at $SSM_FILE"
        exit 1
    fi
    
    if [ ! -f "$CNV_FILE" ]; then
        echo "Error: CNV file not found at $CNV_FILE"
        exit 1
    fi
    
    # Create output directories if they don't exist
    mkdir -p "${BOOTSTRAP_DIR}/chains"
    mkdir -p "${BOOTSTRAP_DIR}/tmp"
    
    # Run PhyloWGS for this bootstrap
    cd "$PHYLOWGS_PATH"
    echo "Running multievolve.py for bootstrap $i from $(pwd)"
    python2 "$MULTIEVOLVE" --num-chains $num_chains \
        --ssms "$SSM_FILE" \
        --cnvs "$CNV_FILE" \
        --output-dir "$BOOTSTRAP_DIR/chains" \
        --tmp-dir "$BOOTSTRAP_DIR/tmp"

    echo "Running write_results.py for bootstrap $i"
    python2 "$WRITE_RESULTS" --include-ssm-names \
        "$BOOTSTRAP_DIR/chains/trees.zip" \
        "$BOOTSTRAP_DIR/result.summ.json.gz" \
        "$BOOTSTRAP_DIR/result.muts.json.gz" \
        "$BOOTSTRAP_DIR/result.mutass.zip"
        
    cd - > /dev/null
done

echo "All bootstraps for patient $patient_id completed successfully." 