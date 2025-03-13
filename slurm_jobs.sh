#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=48:00:00
#SBATCH --output=logs/mase_phi_%A_%a_%j.out
#SBATCH --error=logs/mase_phi_%A_%a_%j.err
#SBATCH --job-name=mase_phi

# Redirect stderr to stdout for better error capturing
exec 2>&1

# Create logs directory first (needed for SLURM output)
mkdir -p logs || {
    echo "Failed to create logs directory"
    exit 1
}

# Activate conda base environment
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Base configuration
export DATA_DIR="/home/ssabata/patient_data/tracerx_test"  # <-- Replace with your actual data path
export INPUT_FILE="${DATA_DIR}/patients_n3_t5.csv"      # <-- Add this line for consolidated input file
export NUM_BOOTSTRAPS=100
export NUM_CHAINS=5
export READ_DEPTH=1500

# Get patient ID from array task ID
# Read the unique patient IDs from the CSV file (skip header)
readarray -t patient_ids < <(tail -n +2 "${INPUT_FILE}" | cut -d',' -f1 | sort -u)
patient_id="${patient_ids[$SLURM_ARRAY_TASK_ID]}"

if [ -z "$patient_id" ]; then
    echo "Error: No patient ID found for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

echo "[$(date)] Processing patient: ${patient_id}"

# Function to mark a step as completed for a timepoint
mark_step_completed() {
    local step=$1
    local timepoint_dir=$2
    touch "${timepoint_dir}/.${step}_complete"
}

# Function to check if a step is completed for a timepoint
is_step_completed() {
    local step=$1
    local timepoint_dir=$2
    [ -f "${timepoint_dir}/.${step}_complete" ]
}

# Function to run a pipeline step for a timepoint
run_step() {
    local step=$1
    local timepoint_dir=$2
    local timepoint=$(basename "$timepoint_dir")
    
    # Skip if step is already completed
    if is_step_completed "$step" "$timepoint_dir"; then
        echo "[$(date)] Step '$step' already completed for timepoint $timepoint"
        return 0
    fi
    
    echo "[$(date)] Running step '$step' for timepoint $timepoint in directory $timepoint_dir"
    
    case "$step" in
        "preprocess")
            conda activate preprocess_env
            # For preprocess, use the bootstrap.py directly since process_tracerX.py already ran
            # Find the timepoint CSV file
            timepoint_csv=$(find "$timepoint_dir" -name "*.csv" -type f | head -n 1)
            if [ -z "$timepoint_csv" ]; then
                echo "Error: No CSV file found in $timepoint_dir"
                return 1
            fi
            
            echo "Running bootstrap on $timepoint_csv"
            python 0-preprocess/bootstrap.py -i "$timepoint_csv" -o "$timepoint_dir" -n "${NUM_BOOTSTRAPS}"
            ;;
            
        "phylowgs")
            conda activate phylowgs_env
            ./1-phylowgs/run_phylowgs.sh "${timepoint_dir}" "${NUM_CHAINS}" "${NUM_BOOTSTRAPS}"
            ;;
            
        "aggregation")
            conda activate aggregation_env
            
            # Get timepoint info for process_tracerx_bootstrap.py
            # Extract just the bootstrap numbers
            bootstrap_list=$(seq -s ' ' 1 $NUM_BOOTSTRAPS)
            
            # Extract patient_id and date information from the timepoint directory
            timepoint_name=$(basename "$timepoint_dir")
            
            # Create aggregation directory
            mkdir -p "${timepoint_dir}/aggregation"
            
            echo "Running aggregation with bootstrap list: $bootstrap_list"
            python 2-aggregation/process_tracerx_bootstrap.py "$timepoint_name" \
                --bootstrap-list $bootstrap_list \
                --base-dir "$(dirname "$timepoint_dir")"
            ;;
            
        "markers")
            conda activate markers_env
            
            # Get timepoint info for run_data.py
            timepoint_name=$(basename "$timepoint_dir")
            
            # Create markers directory
            mkdir -p "${timepoint_dir}/markers"
            
            echo "Running marker selection with bootstrap list: $(seq -s ' ' 1 $NUM_BOOTSTRAPS)"
            python 3-markers/run_data.py "$timepoint_name" \
                --bootstrap-list $(seq 1 $NUM_BOOTSTRAPS) \
                --read-depth "${READ_DEPTH}"
            ;;
            
        *)
            echo "Unknown step: $step"
            return 1
            ;;
    esac
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        mark_step_completed "$step" "$timepoint_dir"
        echo "[$(date)] Successfully completed step '$step' for timepoint in $timepoint_dir"
        return 0
    else
        if [ "$step" == "phylowgs" ] && [ $exit_code -eq 1 ]; then
            echo "[$(date)] PhyloWGS failed for timepoint (likely no viable mutations)"
            exit 0
        else
            echo "[$(date)] Error in step '$step' for timepoint in $timepoint_dir (exit code: $exit_code)"
            return 1
        fi
    fi
}

# Find all timepoint directories for this patient
patient_dir="${DATA_DIR}/${patient_id}"
timepoint_dirs=($(find "${patient_dir}" -type d -name "${patient_id}_*" -not -path "*/\.*"))

echo "[$(date)] Found ${#timepoint_dirs[@]} timepoint directories for patient ${patient_id}"
for tp_dir in "${timepoint_dirs[@]}"; do
    echo "  - $tp_dir"
done

# Process each timepoint directory
for timepoint_dir in "${timepoint_dirs[@]}"; do
    echo "[$(date)] Processing timepoint directory: ${timepoint_dir}"
    
    # Process each step for this timepoint
    STEPS=("preprocess" "phylowgs" "aggregation" "markers")
    for step in "${STEPS[@]}"; do
        if ! run_step "$step" "$timepoint_dir"; then
            echo "[$(date)] Failed at step '$step' for timepoint directory $timepoint_dir"
            exit 1
        fi
    done
    
    echo "[$(date)] Successfully completed all steps for timepoint directory $timepoint_dir"
done

echo "[$(date)] Successfully completed all steps for all timepoints of patient $patient_id" 