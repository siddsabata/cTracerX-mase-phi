#!/bin/bash
# --------------------------------------------------
# This script performs bootstrapping on mutation data for a timepoint.
#
# It performs:
#  1. Bootstrapping via bootstrap.py on the timepoint CSV file
#  2. Creates bootstrap replicate samples for further analysis
#
# Usage:
#   ./run_bootstrap.sh <timepoint_directory> [num_bootstraps]
#
# Example:
#   ./run_bootstrap.sh /data/CRUK0044_baseline_2014-11-28 100
#
# Note:
#   Ensure the conda environment with the required dependencies 
#   is activated before executing this script.
# --------------------------------------------------

# Enable strict error handling
set -e

# Get the directory containing this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for timepoint directory argument
if [ -z "$1" ]; then
    echo "Usage: $0 <timepoint_directory> [num_bootstraps]"
    exit 1
fi

timepoint_dir="$1"
num_bootstraps="${2:-100}"
timepoint_id=$(basename "$timepoint_dir")

echo "---------------------------------------"
echo "[$(date)] Starting bootstrap process"
echo "Timepoint: ${timepoint_id}"
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

# Create marker file directory if it doesn't exist
mkdir -p "${timepoint_dir}/.markers"

# Run bootstrap processing
echo "[$(date)] Running bootstrap processing with ${num_bootstraps} iterations..."
python "${script_dir}/bootstrap.py" --input "${timepoint_csv}" --output "${timepoint_dir}" --num_bootstraps "${num_bootstraps}"

# Create completion marker
touch "${timepoint_dir}/.markers/bootstrap_complete"

# Count generated bootstrap directories
bootstrap_count=$(find "${timepoint_dir}" -type d -name "bootstrap_*" | wc -l)
echo "[$(date)] Generated ${bootstrap_count} bootstrap samples"

# Verify all bootstrap directories contain required files
echo "Verifying bootstrap outputs..."
missing_files=0
for i in $(seq 1 ${num_bootstraps}); do
    bootstrap_dir="${timepoint_dir}/bootstrap_${i}"
    if [ ! -d "${bootstrap_dir}" ]; then
        echo "Warning: Bootstrap directory ${i} not found"
        missing_files=$((missing_files + 1))
        continue
    fi
    
    if [ ! -f "${bootstrap_dir}/ssm_data.txt" ]; then
        echo "Warning: Missing SSM file in bootstrap ${i}"
        missing_files=$((missing_files + 1))
    fi
done

if [ ${missing_files} -gt 0 ]; then
    echo "Warning: ${missing_files} missing files detected in bootstrap outputs"
else
    echo "All bootstrap outputs verified successfully!"
fi

echo "[$(date)] Bootstrapping for timepoint ${timepoint_id} completed successfully." 