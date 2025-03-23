#!/bin/bash
# --------------------------------------------------
# Step 3: Run post-processing for all timepoints of a patient
#
# This script:
# 1. Reads the timepoint_list.txt file to find all timepoints 
# 2. Submits a separate job to run post-processing for each timepoint in parallel
#
# Usage: 
#   bash run_all_postprocessing.sh <data_dir> [patient_id] [num_bootstraps] [read_depth]
# Example:
#   bash run_all_postprocessing.sh /path/to/data/dir CRUK0044 100 1500
# --------------------------------------------------

set -e

# Process arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <data_dir> [patient_id] [num_bootstraps] [read_depth]"
    exit 1
fi

# Convert to absolute path
DATA_DIR=$(realpath "$1")
PATIENT_ID="${2:-}"  # Optional - if omitted, will process all timepoints in DATA_DIR
NUM_BOOTSTRAPS="${3:-100}"
READ_DEPTH="${4:-1500}"

# Create logs directory
mkdir -p logs

echo "==========================================================="
echo "Submitting parallel post-processing jobs for timepoints"
echo "==========================================================="
echo "Data directory: ${DATA_DIR}"
if [ -n "${PATIENT_ID}" ]; then
    echo "Patient ID: ${PATIENT_ID}"
fi
echo "Number of bootstraps: ${NUM_BOOTSTRAPS}"
echo "Read depth: ${READ_DEPTH}"
echo "==========================================================="

# Check if timepoint list exists
timepoint_list_file="${DATA_DIR}/timepoint_list.txt"
if [ ! -f "${timepoint_list_file}" ]; then
    echo "ERROR: Timepoint list file not found: ${timepoint_list_file}"
    exit 1
fi

# Read timepoints and filter by patient ID if specified
selected_timepoints=()
while read -r rel_timepoint_path; do
    # Handle relative paths
    if [[ "${rel_timepoint_path}" == ./* ]]; then
        # Remove leading ./
        rel_timepoint_path=$(echo "${rel_timepoint_path}" | sed 's|^\./||')
    fi
    
    # Construct absolute path
    timepoint_dir="${DATA_DIR}/${rel_timepoint_path}"
    
    # Extract timepoint name
    timepoint_name=$(basename "${timepoint_dir}")
    
    # Filter by patient ID if specified
    if [ -n "${PATIENT_ID}" ]; then
        if [[ "${timepoint_name}" == ${PATIENT_ID}_* ]]; then
            selected_timepoints+=("${timepoint_dir}")
        fi
    else
        selected_timepoints+=("${timepoint_dir}")
    fi
done < "${timepoint_list_file}"

# Check if we found any timepoints
if [ ${#selected_timepoints[@]} -eq 0 ]; then
    if [ -n "${PATIENT_ID}" ]; then
        echo "ERROR: No timepoints found for patient ${PATIENT_ID} in ${timepoint_list_file}"
    else
        echo "ERROR: No timepoints found in ${timepoint_list_file}"
    fi
    exit 1
fi

echo "Found ${#selected_timepoints[@]} timepoints to process:"
for dir in "${selected_timepoints[@]}"; do
    echo "  - $(basename "$dir")"
done
echo ""

# Submit a job for each timepoint
job_ids=()
for timepoint_dir in "${selected_timepoints[@]}"; do
    timepoint_name=$(basename "${timepoint_dir}")
    
    echo "Submitting job for timepoint: ${timepoint_name}"
    
    # Extract patient ID from timepoint name
    patient_id=$(echo "${timepoint_name}" | cut -d'_' -f1)
    
    # Submit post-processing job for this timepoint
    postprocess_job=$(sbatch \
        --job-name="post_${timepoint_name}" \
        --output="logs/post_${timepoint_name}_%j.out" \
        --error="logs/post_${timepoint_name}_%j.err" \
        --partition=pool1 \
        --cpus-per-task=5 \
        --mem=16G \
        --time=24:00:00 \
        --wrap="#!/bin/bash
        set -e
        
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Starting post-processing for ${timepoint_name}\"
        
        # Source conda
        source ~/miniconda3/bin/activate
        
        # Check if PhyloWGS is complete for all bootstraps
        incomplete=0
        for bootstrap_num in \$(seq 1 ${NUM_BOOTSTRAPS}); do
            marker_file=\"${timepoint_dir}/bootstrap_\${bootstrap_num}/.markers/phylowgs_complete\"
            if [ ! -f \"\${marker_file}\" ]; then
                echo \"WARNING: PhyloWGS not complete for bootstrap \${bootstrap_num}\"
                incomplete=\$((incomplete + 1))
            fi
        done
        
        if [ \$incomplete -gt 0 ]; then
            echo \"WARNING: \${incomplete} bootstraps are missing PhyloWGS completion markers.\"
            echo \"Proceeding anyway, but aggregation may fail if PhyloWGS results are incomplete.\"
        fi
        
        # Run aggregation
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Running aggregation for ${timepoint_name}\"
        conda activate aggregation_env || {
            echo \"Failed to activate aggregation_env\"
            exit 1
        }
        
        # Set required environment variables for aggregation
        export DATA_DIR=\"${DATA_DIR}\"
        
        echo \"Running aggregation with patient ID: ${patient_id}, bootstraps: ${NUM_BOOTSTRAPS}\"
        ./3-aggregation/run_aggregation.sh \"${patient_id}\" ${NUM_BOOTSTRAPS}
        
        # Run markers
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Running marker selection for ${timepoint_name}\"
        conda activate markers_env || {
            echo \"Failed to activate markers_env\"
            exit 1
        }
        
        echo \"Running marker selection with patient ID: ${patient_id}, bootstraps: ${NUM_BOOTSTRAPS}, read depth: ${READ_DEPTH}\"
        ./4-markers/run_markers.sh \"${patient_id}\" ${NUM_BOOTSTRAPS} ${READ_DEPTH}
        
        # Create marker to indicate completion
        mkdir -p \"${timepoint_dir}/.markers\"
        touch \"${timepoint_dir}/.markers/processing_complete\"
        
        echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Completed post-processing for ${timepoint_name}\"")
    
    # Extract job ID and add to list
    job_id=$(echo ${postprocess_job} | awk '{print $4}')
    job_ids+=("${job_id}")
    
    echo "Submitted job ${job_id} for timepoint ${timepoint_name}"
done

# Display job monitoring information
echo "==========================================================="
echo "Submitted ${#job_ids[@]} post-processing jobs"
echo "Monitor with: squeue -u $USER -n 'post_*'"
if [ ${#job_ids[@]} -lt 10 ]; then
    job_list=$(IFS=,; echo "${job_ids[*]}")
    echo "Or with: squeue -j ${job_list}"
fi
echo "===========================================================" 