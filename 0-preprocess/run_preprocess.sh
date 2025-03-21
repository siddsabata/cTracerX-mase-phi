#!/bin/bash
# --------------------------------------------------
# This script handles the initial preprocessing of mutation data.
#
# It performs:
#  1. Initial preprocessing via process_tracerX.py to create timepoint directories
#
# Usage:
#   ./run_preprocess.sh <input_csv_file> <output_directory>
#
# Example:
#   ./run_preprocess.sh /data/cruk0044.csv /data/tracerx_2017/
#
# Note:
#   Ensure the conda environment with the required dependencies 
#   is activated before executing this script.
# --------------------------------------------------

# Get the directory containing this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for input and output directory arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <input_csv_file> <output_directory>"
    exit 1
fi

input_file="$1"
output_dir="$2"

echo "---------------------------------------"
echo "Running initial preprocessing"
echo "Input file: ${input_file}"
echo "Output directory: ${output_dir}"
echo "---------------------------------------"

# Validate input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file ${input_file} does not exist"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Run process_tracerX.py for initial preprocessing
echo "Running initial preprocessing with process_tracerX.py..."
python "${script_dir}/process_tracerX.py" -i "${input_file}" -o "${output_dir}"

# Count the number of timepoint directories created
num_timepoints=$(find "${output_dir}" -type d -path "*/[A-Z]*_*_*" -not -path "*/\.*" | wc -l)
echo "Created ${num_timepoints} timepoint directories"

# Generate the timepoint list file
echo "Writing timepoint paths to file..."
timepoint_list_file="${output_dir}/timepoint_list.txt"

# Clear the file first
> "${timepoint_list_file}"

# Find all timepoint directories
find "${output_dir}" -type d -path "*/[A-Z]*_*_*" -not -path "*/\.*" | while read -r fullpath; do
    # Convert to relative path
    relpath=$(realpath --relative-to="${output_dir}" "${fullpath}")
    echo "./${relpath}" >> "${timepoint_list_file}"
done

echo "Timepoint list saved to: ${timepoint_list_file}"

echo "Initial preprocessing completed successfully." 