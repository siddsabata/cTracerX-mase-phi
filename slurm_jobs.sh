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

# IMPORTANT! Don't take timepoint list from command line argument
# Instead, read it from a hardcoded path that matches main.sh
timepoint_list_file="${DATA_DIR}/timepoint_list.txt"

echo "Starting job. DATA_DIR=${DATA_DIR}"
echo "Reading timepoint list from: ${timepoint_list_file}"

# Check if the timepoint list file exists
if [ ! -f "${timepoint_list_file}" ]; then
    echo "ERROR: Timepoint list file not found: ${timepoint_list_file}"
    exit 1
fi

# Activate conda base environment after checking file, before processing content
echo "Activating conda base environment..."
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Read the timepoint directory for this array task
timepoint_dir=$(sed -n "$((SLURM_ARRAY_TASK_ID+1))p" "${timepoint_list_file}")
if [ -z "${timepoint_dir}" ]; then
    echo "ERROR: No timepoint directory found for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Extract timepoint name
timepoint_name=$(basename "${timepoint_dir}")
echo "[$(date)] Processing timepoint: ${timepoint_name} (${timepoint_dir})"

# Pass through environment variables from main script
# These should come from main.sh via the sbatch --export option
: ${NUM_BOOTSTRAPS:=100}
: ${NUM_CHAINS:=5}
: ${READ_DEPTH:=1500}

echo "Using configuration:"
echo "  NUM_BOOTSTRAPS=${NUM_BOOTSTRAPS}"
echo "  NUM_CHAINS=${NUM_CHAINS}"
echo "  READ_DEPTH=${READ_DEPTH}"

# Function to mark a step as completed for this timepoint
mark_step_completed() {
    local step=$1
    touch "${timepoint_dir}/.${step}_complete"
}

# Function to check if a step is completed for this timepoint
is_step_completed() {
    local step=$1
    [ -f "${timepoint_dir}/.${step}_complete" ]
}

# Function to run a pipeline step
run_step() {
    local step=$1
    
    # Skip if step is already completed
    if is_step_completed "$step"; then
        echo "[$(date)] Step '$step' already completed for timepoint $timepoint_name"
        return 0
    fi
    
    echo "[$(date)] Running step '$step' for timepoint $timepoint_name"
    
    case "$step" in
        "preprocess")
            conda activate preprocess_env
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
            
            # Extract just the bootstrap numbers
            bootstrap_list=$(seq -s ' ' 1 $NUM_BOOTSTRAPS)
            
            # Create aggregation directory
            mkdir -p "${timepoint_dir}/aggregation"
            
            echo "Running aggregation with bootstrap list: $bootstrap_list"
            python 2-aggregation/process_tracerx_bootstrap.py "$timepoint_name" \
                --bootstrap-list $bootstrap_list \
                --base-dir "$(dirname "$timepoint_dir")"
            ;;
            
        "markers")
            conda activate markers_env
            
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
        mark_step_completed "$step" 
        echo "[$(date)] Successfully completed step '$step' for timepoint $timepoint_name"
        return 0
    else
        if [ "$step" == "phylowgs" ] && [ $exit_code -eq 1 ]; then
            echo "[$(date)] PhyloWGS failed for timepoint (likely no viable mutations)"
            exit 0
        else
            echo "[$(date)] Error in step '$step' for timepoint $timepoint_name (exit code: $exit_code)"
            return 1
        fi
    fi
}

# Process each step for this timepoint
STEPS=("preprocess" "phylowgs" "aggregation" "markers")
for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        echo "[$(date)] Failed at step '$step' for timepoint $timepoint_name"
        exit 1
    fi
done

echo "[$(date)] Successfully completed all steps for timepoint $timepoint_name" 