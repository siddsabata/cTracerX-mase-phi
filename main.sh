#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --array=0-3%50             
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
export DATA_DIR="/home/ssabata/patient_data/mafs_test"  # <-- Replace with your actual data path
export INPUT_FILE="${DATA_DIR}/patients_n3_t5.csv"      # <-- Add this line for consolidated input file
export NUM_BOOTSTRAPS=5
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

# Function to mark a step as completed
mark_step_completed() {
    local step=$1
    touch "${DATA_DIR}/${patient_id}/.${step}_complete"
}

# Function to check if a step is completed
is_step_completed() {
    local step=$1
    [ -f "${DATA_DIR}/${patient_id}/.${step}_complete" ]
}

# Function to run a pipeline step
run_step() {
    local step=$1
    
    # Skip if step is already completed
    if is_step_completed "$step"; then
        echo "[$(date)] Step '$step' already completed for patient $patient_id"
        return 0
    }
    
    echo "[$(date)] Running step '$step' for patient $patient_id"
    
    case "$step" in
        "preprocess")
            conda activate preprocess_env
            python 0-preprocess/bootstrap.py \
                -i "${DATA_DIR}/${patient_id}/common/patient_${patient_id}.csv" \
                -o "${DATA_DIR}/${patient_id}/common" \
                -n "${NUM_BOOTSTRAPS}" || return $?
            ;;
            
        "phylowgs")
            conda activate phylowgs_env
            python 1-phylowgs/run_phylowgs.py \
                "${patient_id}" "${NUM_CHAINS}" "${NUM_BOOTSTRAPS}" || return $?
            ;;
            
        "aggregation")
            conda activate aggregation_env
            python 2-aggregation/process_tracerx_bootstrap.py \
                "${patient_id}" \
                --bootstrap-list $(seq 1 ${NUM_BOOTSTRAPS}) \
                --num-blood 0 \
                --num-tissue 5 \
                --base-dir "${DATA_DIR}" || return $?
            ;;
            
        "markers")
            conda activate markers_env
            python 3-markers/run_data.py \
                "${patient_id}" \
                --bootstrap-list $(seq 1 ${NUM_BOOTSTRAPS}) \
                --read-depth "${READ_DEPTH}" \
                --base-dir "${DATA_DIR}" || return $?
            ;;
            
        *)
            echo "Unknown step: $step"
            return 1
            ;;
    esac
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        mark_step_completed "$step"
        echo "[$(date)] Successfully completed step '$step' for patient $patient_id"
        return 0
    else
        if [ "$step" == "phylowgs" ] && [ $exit_code -eq 1 ]; then
            echo "[$(date)] PhyloWGS failed for patient $patient_id (likely no viable mutations)"
            exit 0
        else
            echo "[$(date)] Error in step '$step' for patient $patient_id (exit code: $exit_code)"
            return 1
        fi
    fi
}

# Process each step
STEPS=("preprocess" "phylowgs" "aggregation" "markers")
for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        echo "[$(date)] Failed at step '$step' for patient $patient_id"
        exit 1
    fi
done

echo "[$(date)] Successfully completed all steps for patient $patient_id" 