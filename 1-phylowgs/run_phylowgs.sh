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
#   ./run_phylowgs.sh <timepoint_dir> <num_chains> <num_bootstraps>
#
# Example:
#   ./run_phylowgs.sh ppi_975 5 5
#
# Note:
#   Ensure that your PhyloWGS installation is setup (e.g., via init.sh)
#   and that python2 and required dependencies are available.
# --------------------------------------------------

set -e

# Check if required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <timepoint_dir> <num_chains> <num_bootstraps>"
    exit 1
fi

# Extract arguments
timepoint_dir="$1"
num_chains="$2"
num_bootstraps="$3"

echo "---------------------------------------"
echo "Running PhyloWGS for timepoint directory: ${timepoint_dir}"
echo "Number of chains: ${num_chains}"
echo "Number of bootstraps: ${num_bootstraps}"
echo "---------------------------------------"

# Get the PhyloWGS installation directory
phylowgs_dir="${PWD}/1-phylowgs/phylowgs"

# Process each bootstrap
for bootstrap_num in $(seq 1 "${num_bootstraps}"); do
    echo "Processing bootstrap ${bootstrap_num}..."
    
    # Define files and directories for this bootstrap
    bootstrap_dir="${timepoint_dir}/bootstrap${bootstrap_num}"
    ssm_file="${bootstrap_dir}/ssm_data_bootstrap${bootstrap_num}.txt"
    cnv_file="${bootstrap_dir}/cnv_data_bootstrap${bootstrap_num}.txt"
    
    # Check if SSM file exists
    if [ ! -f "${ssm_file}" ]; then
        echo "Error: SSM file not found at ${ssm_file}"
        exit 1
    fi
    
    # Create bootstrap directory if it doesn't exist
    mkdir -p "${bootstrap_dir}"
    
    # Create chains directory for this bootstrap
    chains_dir="${bootstrap_dir}/chains"
    mkdir -p "${chains_dir}"
    
    # Create tmp directory for this bootstrap
    tmp_dir="${bootstrap_dir}/tmp"
    mkdir -p "${tmp_dir}"
    
    # Run PhyloWGS
    cd "${phylowgs_dir}"
    
    # Check if CNV file exists and is not empty
    if [ -f "${cnv_file}" ] && [ -s "${cnv_file}" ]; then
        echo "Running PhyloWGS with SSM and CNV data..."
        python2 multievolve.py \
            --num-chains "${num_chains}" \
            --ssms "${ssm_file}" \
            --cnvs "${cnv_file}" \
            --output-dir "${chains_dir}" \
            --tmp-dir "${tmp_dir}"
    else
        echo "Running PhyloWGS with SSM data only..."
        python2 multievolve.py \
            --num-chains "${num_chains}" \
            --ssms "${ssm_file}" \
            --output-dir "${chains_dir}" \
            --tmp-dir "${tmp_dir}"
    fi
    
    # Back to original directory
    cd - > /dev/null
    
    # Compress results
    echo "Compressing results for bootstrap ${bootstrap_num}..."
    if [ -f "${chains_dir}/trees.zip" ]; then
        cp "${chains_dir}/trees.zip" "${bootstrap_dir}/result.mutass.zip"
    fi
    if [ -f "${chains_dir}/mutass.zip" ]; then
        cp "${chains_dir}/mutass.zip" "${bootstrap_dir}/result.mutass.zip"
    fi
    if [ -f "${chains_dir}/muts.json.gz" ]; then
        cp "${chains_dir}/muts.json.gz" "${bootstrap_dir}/result.muts.json.gz"
    fi
    if [ -f "${chains_dir}/summ.json.gz" ]; then
        cp "${chains_dir}/summ.json.gz" "${bootstrap_dir}/result.summ.json.gz"
    fi
    
    echo "Completed bootstrap ${bootstrap_num}"
done

echo "PhyloWGS analysis completed for all bootstraps"
exit 0 