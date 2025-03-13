#!/bin/bash
# --------------------------------------------------
# This script preprocesses mutation data for a timepoint directory.
#
# It performs:
#  1. Bootstrapping via bootstrap.py on the timepoint CSV file
#
# Usage:
#   ./run_preprocess.sh <timepoint_directory> [num_bootstraps]
#
# Example:
#   ./run_preprocess.sh /data/CRUK0044_baseline_2014-11-28 10
#
# Note:
#   Ensure the conda environment with the required dependencies 
#   is activated before executing this script.
# --------------------------------------------------

# Get the directory containing this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for timepoint directory argument
if [ -z "$1" ]; then
    echo "Usage: $0 <timepoint_directory> [num_bootstraps]"
    exit 1
fi

timepoint_dir="$1"
num_bootstraps="${2:-10}"
timepoint_id=$(basename "$timepoint_dir")

echo "---------------------------------------"
echo "Processing timepoint: ${timepoint_id}"
echo "Directory: ${timepoint_dir}"
echo "Number of bootstraps: ${num_bootstraps}"
echo "---------------------------------------"

# Validate timepoint directory exists
if [ ! -d "$timepoint_dir" ]; then
    echo "Error: Timepoint directory ${timepoint_dir} does not exist"
    exit 1
fi

# Find the timepoint CSV file
timepoint_csv=$(find "$timepoint_dir" -name "*.csv" -type f | head -n 1)

if [ -z "$timepoint_csv" ]; then
    echo "Error: No CSV file found in ${timepoint_dir}"
    exit 1
fi

echo "Found CSV file: ${timepoint_csv}"

# Run bootstrap processing
echo "Running bootstrap processing with ${num_bootstraps} iterations..."
python "${script_dir}/bootstrap.py" --input "${timepoint_csv}" --output "${timepoint_dir}" --num_bootstraps "${num_bootstraps}"

echo "Preprocessing for timepoint ${timepoint_id} completed successfully." 