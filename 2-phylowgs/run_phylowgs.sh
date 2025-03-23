#!/bin/bash
# --------------------------------------------------
# This script runs PhyloWGS for a single bootstrap iteration
#
# Usage:
#   ./run_phylowgs.sh <timepoint_dir> <bootstrap_num> <num_chains>
#
# Example:
#   ./run_phylowgs.sh /path/to/data/CRUK0044_baseline_2014-11-28 1 5
# --------------------------------------------------

set -e

# Check if required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <timepoint_dir> <bootstrap_num> <num_chains>"
    exit 1
fi

# Extract arguments
timepoint_dir="$1"
bootstrap_num="$2"
num_chains="$3"

echo "---------------------------------------"
echo "Running PhyloWGS for timepoint: $(basename "${timepoint_dir}")"
echo "Bootstrap: ${bootstrap_num}"
echo "Number of chains: ${num_chains}"
echo "---------------------------------------"

# Define input and output directories - convert to absolute paths
input_dir=$(realpath "${timepoint_dir}/bootstrap${bootstrap_num}")  # Input dir (absolute path)
output_dir=$(realpath "${timepoint_dir}/bootstrap${bootstrap_num}") # Output dir (absolute path)

# Create output directories
mkdir -p "${output_dir}/chains" "${output_dir}/.tmp"

# Find SSM and CNV files
ssm_file="${input_dir}/ssm.txt"
cnv_file="${input_dir}/cnv.txt"

# Check if SSM file exists
if [ ! -f "${ssm_file}" ]; then
    echo "Error: SSM file not found at ${ssm_file}"
    exit 1
fi

# Create empty CNV file if it doesn't exist
if [ ! -f "${cnv_file}" ]; then
    echo "Creating empty CNV file at ${cnv_file}"
    echo "chr	start	end	major_cn	minor_cn	cellular_prevalence" > "${cnv_file}"
fi

# Get the PhyloWGS installation directory (assuming we're in the cTracerX-mase-phi directory)
phylowgs_dir="$(pwd)/2-phylowgs/phylowgs"
multievolve="${phylowgs_dir}/multievolve.py"
write_results="${phylowgs_dir}/write_results.py"

# Print paths for debugging
echo "Input directory: ${input_dir}"
echo "Output directory: ${output_dir}" 
echo "SSM file: ${ssm_file}"
echo "CNV file: ${cnv_file}"

# Run PhyloWGS
echo "Running multievolve.py for bootstrap ${bootstrap_num} from $(pwd)"
cd "${phylowgs_dir}"
python2 "${multievolve}" --num-chains "${num_chains}" \
    --ssms "${ssm_file}" \
    --cnvs "${cnv_file}" \
    --output-dir "${output_dir}/chains" \
    --tmp-dir "${output_dir}/.tmp"

# Process results with write_results.py
echo "Running write_results.py for bootstrap ${bootstrap_num}"
python2 "${write_results}" --include-ssm-names result \
    "${output_dir}/chains/trees.zip" \
    "${output_dir}/result.summ.json.gz" \
    "${output_dir}/result.muts.json.gz" \
    "${output_dir}/result.mutass.zip"

# Return to original directory
cd - > /dev/null

echo "PhyloWGS analysis completed for bootstrap ${bootstrap_num}" 