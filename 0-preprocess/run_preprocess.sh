#!/bin/bash
# --------------------------------------------------
# This script preprocesses a single patient's data.
#
# It performs:
#  1. MAF file aggregation by calling maf_agg.py.
#  2. Bootstrapping (and phyloWGS file generation) via bootstrap_maf.py.
#
# Usage:
#   ./run_preprocess.sh <patient_directory> [num_bootstraps]
#
# Example:
#   ./run_preprocess.sh ppi_975 5
#
# Note:
#   Ensure the conda environment with the required dependencies 
#   is activated (e.g., via `conda activate your_env`) before 
#   executing this script.
# --------------------------------------------------

# Check for patient directory argument
if [ -z "$1" ]; then
    echo "Usage: $0 <patient_directory> [num_bootstraps]"
    exit 1
fi

patient_dir="$1"
num_bootstraps="${2:-10}"
patient_id=$(basename "$patient_dir")

# Define the base directory for your data.
# Update DATA_ROOT if your data is located somewhere else.
DATA_ROOT="${DATA_DIR}"
input_dir="${DATA_ROOT}/${patient_dir}"
mafs_dir="${input_dir}/mafs"
common_dir="${input_dir}/common"
output_csv="${common_dir}/patient_${patient_id}.csv"

echo "---------------------------------------"
echo "Processing patient: ${patient_id}"
echo "Input directory: ${input_dir}"
echo "MAFs directory: ${mafs_dir}"
echo "Output directory: ${common_dir}"
echo "---------------------------------------"

# Optional: Activate conda environment
# Uncomment and update if needed:
# source /path/to/miniconda3/etc/profile.d/conda.sh
# conda activate your_env_name

# Validate required directories
if [ ! -d "$input_dir" ]; then
    echo "Error: Patient directory ${input_dir} does not exist"
    exit 1
fi

if [ ! -d "$mafs_dir" ]; then
    echo "Error: MAFs directory ${mafs_dir} does not exist"
    exit 1
fi

# Create common directory if it doesn't exist
mkdir -p "${common_dir}"

# Identify required MAF files
echo "Searching for required MAF files..."
cf_maf=$(find "${mafs_dir}" -name "*CF-*.maf.*" -type f)
st_maf=$(find "${mafs_dir}" -name "*ST-*.maf.*" -type f)
bc_maf=$(find "${mafs_dir}" -name "*BC-*.maf.*" -type f)

if [ -z "$cf_maf" ] || [ -z "$st_maf" ] || [ -z "$bc_maf" ]; then
    echo "Error: Missing one or more required MAF files in ${mafs_dir}"
    echo "CF MAF: ${cf_maf:-not found}"
    echo "ST MAF: ${st_maf:-not found}"
    echo "BC MAF: ${bc_maf:-not found}"
    exit 1
fi

echo "Found MAF files:"
echo "  CF MAF: ${cf_maf}"
echo "  ST MAF: ${st_maf}"
echo "  BC MAF: ${bc_maf}"

# Run MAF aggregation, creating the output CSV file
echo "Running MAF aggregation..."
python "$(dirname $0)/maf_agg.py" --cf_maf "$cf_maf" --st_maf "$st_maf" --bc_maf "$bc_maf" --output_dir "$output_csv" --method "inner"

# Check for empty.txt flag
if [ -f "${common_dir}/empty.txt" ]; then
    echo "No common mutations found for patient ${patient_id}. Skipping bootstrap step."
    exit 0
fi

if [ ! -f "$output_csv" ]; then
    echo "Error: MAF aggregation did not produce the expected output: ${output_csv}"
    exit 1
fi

# Run bootstrap processing with PhyloWGS output
echo "Running bootstrap processing with ${num_bootstraps} iterations..."
python "$(dirname $0)/bootstrap_maf.py" --input "$output_csv" --output "${common_dir}" --num_bootstraps "$num_bootstraps" --phylowgs

echo "Preprocessing for patient ${patient_id} completed successfully." 