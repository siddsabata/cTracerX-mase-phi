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
export NUM_BOOTSTRAPS=5
export NUM_CHAINS=5
export READ_DEPTH=1500

# Print debug info
echo "[$(date)] Job started"
echo "Running on host: $(hostname)"
echo "Working directory: $(pwd)"
echo "DATA_DIR: ${DATA_DIR}"
echo "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID}"

# Verify data directory exists
if [ ! -d "${DATA_DIR}" ]; then
    echo "Error: DATA_DIR (${DATA_DIR}) does not exist"
    exit 1
fi

# Get patient ID from array index
patients=($(ls ${DATA_DIR} | grep -v "\."))
if [ ${#patients[@]} -eq 0 ]; then
    echo "Error: No patient directories found in ${DATA_DIR}"
    exit 1
fi

patient_id=${patients[$SLURM_ARRAY_TASK_ID]}
patient_dir="${DATA_DIR}/${patient_id}"

echo "[$(date)] Processing patient: ${patient_id}"

# Function to check if step is completed
check_step_completed() {
    local step=$1
    local marker_file="${patient_dir}/.${step}_completed"
    [ -f "$marker_file" ]
}

# Function to mark step as completed
mark_step_completed() {
    local step=$1
    touch "${patient_dir}/.${step}_completed"
}

# Function to run a processing step
run_step() {
    local step=$1
    if check_step_completed "$step"; then
        echo "[$(date)] Step '$step' already completed for patient $patient_id, skipping..."
        return 0
    fi

    echo "[$(date)] Running step '$step' for patient $patient_id"

    case "$step" in
        preprocess)
            conda activate preprocess_env
            ./0-preprocess/run_preprocess.sh "${patient_id}" "${NUM_BOOTSTRAPS}"
            # Check for empty.txt after preprocess step
            if [ -f "${patient_dir}/common/empty.txt" ]; then
                echo "[$(date)] No common mutations found for patient ${patient_id}. Stopping processing."
                exit 0
            fi
            ;;
        phylowgs)
            conda activate phylowgs_env
            ./1-phylowgs/run_phylowgs.sh "${patient_id}" "${NUM_CHAINS}" "${NUM_BOOTSTRAPS}"
            ;;
        aggregation)
            conda activate aggregation_env
            ./2-aggregation/run_aggregation.sh "${patient_id}" "${NUM_BOOTSTRAPS}"
            ;;
        markers)
            conda activate markers_env
            ./3-markers/run_markers.sh "${patient_id}" "${NUM_BOOTSTRAPS}" "${READ_DEPTH}"
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