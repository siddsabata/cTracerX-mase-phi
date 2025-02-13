#!/bin/bash
#SBATCH --partition=pool1           # Use pool1 partition (3-day time limit)
#SBATCH --array=0-2%50             # Adjust based on number of patients
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=24:00:00
#SBATCH --output=logs/mase_phi_%A_%a_%j.out
#SBATCH --error=logs/mase_phi_%A_%a_%j.err
#SBATCH --job-name=mase_phi

#----------------------------------------------------------------------------
# Adapted SLURM script using separate conda environments for each step
#
# This script will:
#  - Determine the patient ID based on the SLURM_ARRAY_TASK_ID
#  - For each step (preprocess, phylowgs, aggregation, markers):
#     * Activate the step-specific conda environment
#     * Run the corresponding run script with the proper parameters
#     * Mark the step completed by writing a hidden file in the patient folder
#
# Environment variables:
#   DATA_DIR - Base directory containing patient subdirectories.
#   NUM_BOOTSTRAPS (default: 5)
#   NUM_CHAINS (default: 5)
#   READ_DEPTH (default: 1500) used in the markers step.
#
# Each step assumes its run script is located in:
#   0-preprocess/run_preprocess.sh
#   1_phylowgs/run_phylowgs.sh
#   2_aggregation/run_aggregation.sh
#   3_markers/run_markers.sh
#
# Example usage:
#   sbatch process_patients.sh
#----------------------------------------------------------------------------

# Activate conda base environment first
source ~/miniconda3/bin/activate

# Base configuration
export DATA_DIR="${DATA_DIR:-/path/to/data}"
export NUM_BOOTSTRAPS=5
export NUM_CHAINS=5
export READ_DEPTH=1500

# Create logs directory before any operations
mkdir -p logs || exit 1

LOG_FILE="logs/processing_log.txt"
STEPS=("preprocess" "phylowgs" "aggregation" "markers")

# Get patient ID from array index (assumes that patient folders exist under DATA_DIR)
if [ ! -d "${DATA_DIR}" ]; then
    echo "Error: DATA_DIR (${DATA_DIR}) does not exist" | tee -a "$LOG_FILE"
    exit 1
fi

patients=($(ls ${DATA_DIR} | grep -v "\."))
if [ ${#patients[@]} -eq 0 ]; then
    echo "Error: No patient directories found in ${DATA_DIR}" | tee -a "$LOG_FILE"
    exit 1
fi

patient_id=${patients[$SLURM_ARRAY_TASK_ID]}
patient_dir="${DATA_DIR}/${patient_id}"

echo "DEBUG: Script started on $(hostname) at $(date)"
echo "DEBUG: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}"
echo "DEBUG: patient_id=${patient_id}"
echo "DEBUG: Working directory: $(pwd)"

echo "[$(date)] Starting processing for patient $patient_id" | tee -a "$LOG_FILE"

# Function to check if step is completed (marker file exists)
check_step_completed() {
    local step=$1
    local marker_file="${patient_dir}/.${step}_completed"
    if [ -f "$marker_file" ]; then
        return 0  # Step completed
    fi
    return 1      # Not completed
}

# Function to mark a step as completed
mark_step_completed() {
    local step=$1
    touch "${patient_dir}/.${step}_completed"
}

# Function to run a processing step
run_step() {
    local step=$1
    # If the step marker file exists, skip step
    if check_step_completed "$step"; then
        echo "[$(date)] Step '$step' already completed for patient $patient_id, skipping..." \
            | tee -a "$LOG_FILE"
        return 0
    fi

    echo "[$(date)] Running step '$step' for patient $patient_id" | tee -a "$LOG_FILE"

    # Determine the conda environment, script path, and command-line arguments for the step
    case "$step" in
        preprocess)
            STEP_ENV="preprocess_env"
            SCRIPT_CMD="./0-preprocess/run_preprocess.sh"
            # run_preprocess.sh expects: <patient_directory> [num_bootstraps]
            CMD_ARGS="${patient_id} ${NUM_BOOTSTRAPS}"
            ;;
        phylowgs)
            STEP_ENV="phylowgs_env"
            SCRIPT_CMD="./1_phylowgs/run_phylowgs.sh"
            # run_phylowgs.sh expects: <patient_directory> [num_chains] [num_bootstraps]
            CMD_ARGS="${patient_id} ${NUM_CHAINS} ${NUM_BOOTSTRAPS}"
            ;;
        aggregation)
            STEP_ENV="aggregation_env"
            SCRIPT_CMD="./2_aggregation/run_aggregation.sh"
            # run_aggregation.sh expects: <patient_id> [bootstrap numbers]
            CMD_ARGS="${patient_id} ${NUM_BOOTSTRAPS}"
            ;;
        markers)
            STEP_ENV="markers_env"
            SCRIPT_CMD="./3_markers/run_markers.sh"
            # run_markers.sh expects: <patient_id> [num_bootstraps] [read_depth]
            CMD_ARGS="${patient_id} ${NUM_BOOTSTRAPS} ${READ_DEPTH}"
            ;;
        *)
            echo "Unknown step: $step" | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac

    # Activate the conda environment for the step (each step has its own environment)
    conda activate ${STEP_ENV}

    # Execute the step's run script along with its arguments
    if ${SCRIPT_CMD} ${CMD_ARGS}; then
        mark_step_completed "$step"
        echo "[$(date)] Successfully completed step '$step' for patient $patient_id" \
            | tee -a "$LOG_FILE"
        return 0
    else
        local exit_code=$?
        if [ "$step" == "phylowgs" ] && [ $exit_code -eq 1 ]; then
            echo "[$(date)] PhyloWGS failed for patient $patient_id (likely no viable mutations). " \
                 "Skipping remaining steps." | tee -a "$LOG_FILE"
            exit 0
        else
            echo "[$(date)] Error in step '$step' for patient $patient_id (exit code: $exit_code)" \
                | tee -a "$LOG_FILE"
            return 1
        fi
    fi
}

# Process each step sequentially
for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        echo "[$(date)] Failed at step '$step' for patient $patient_id" | tee -a "$LOG_FILE"
        exit 1
    fi
done

echo "[$(date)] Successfully completed all steps for patient $patient_id" | tee -a "$LOG_FILE" 