#!/bin/bash
#SBATCH --partition=pool1           
#SBATCH --cpus-per-task=5
#SBATCH --mem=16G
#SBATCH --time=8:00:00
#SBATCH --output=logs/preprocess_controller_%j.out
#SBATCH --error=logs/preprocess_controller_%j.err
#SBATCH --job-name=preprocess_controller

# This script manages the preprocessing workflow:
# 1. Submits a job for initial preprocessing (run_preprocess.sh)
# 2. After completion, submits a single job for bootstrapping all timepoints

set -e

# Required environment variables check
: ${DATA_DIR:?"DATA_DIR must be set"}
: ${INPUT_FILE:?"INPUT_FILE must be set"}
: ${NUM_BOOTSTRAPS:=100}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting preprocessing workflow controller"
echo "DATA_DIR: ${DATA_DIR}"
echo "INPUT_FILE: ${INPUT_FILE}"
echo "NUM_BOOTSTRAPS: ${NUM_BOOTSTRAPS}"

# Initialize conda
source ~/miniconda3/bin/activate || {
    echo "Failed to source conda"
    exit 1
}

# Activate preprocessing environment
conda activate preprocess_env || {
    echo "Failed to activate preprocess_env"
    exit 1
}

# Submit initial preprocessing job
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Submitting initial preprocessing job"
preprocess_job=$(sbatch \
    --job-name=preprocess \
    --output=logs/preprocess_%j.out \
    --error=logs/preprocess_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=4:00:00 \
    --wrap="./0-preprocess/run_preprocess.sh ${INPUT_FILE} ${DATA_DIR}")

# Extract job ID
preprocess_job_id=$(echo ${preprocess_job} | awk '{print $4}')
echo "Submitted preprocessing job with ID: ${preprocess_job_id}"

# Submit a single job for bootstrapping all timepoints
bootstrap_job=$(sbatch \
    --job-name=bootstrap_all \
    --output=logs/bootstrap_all_%j.out \
    --error=logs/bootstrap_all_%j.err \
    --partition=pool1 \
    --cpus-per-task=5 \
    --mem=16G \
    --time=24:00:00 \
    --dependency=afterok:${preprocess_job_id} \
    --wrap="
    #!/bin/bash
    set -e
    
    echo '[$(date \"+%Y-%m-%d %H:%M:%S\")] Starting bootstrapping for ALL timepoints'
    
    # Source conda
    source ~/miniconda3/bin/activate
    conda activate preprocess_env
    
    # Check if timepoint list exists
    timepoint_list_file=\"${DATA_DIR}/timepoint_list.txt\"
    if [ ! -f \"\${timepoint_list_file}\" ]; then
        echo \"ERROR: Timepoint list file not found: \${timepoint_list_file}\"
        exit 1
    fi
    
    # Process each timepoint sequentially in a single job
    total_timepoints=\$(wc -l < \"\${timepoint_list_file}\")
    echo \"Processing \${total_timepoints} timepoints\"
    
    current=1
    while read -r timepoint_dir; do
        timepoint_name=\$(basename \"\${timepoint_dir}\")
        echo \"[$(date \"+%Y-%m-%d %H:%M:%S\")] Processing timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        
        # Run bootstrap processing directly 
        ./1-bootstrap/run_bootstrap.sh \"\${timepoint_dir}\" ${NUM_BOOTSTRAPS}
        
        echo \"[$(date \"+%Y-%m-%d %H:%M:%S\")] Completed timepoint \${current}/\${total_timepoints}: \${timepoint_name}\"
        current=\$((current + 1))
    done < \"\${timepoint_list_file}\"
    
    echo '[$(date \"+%Y-%m-%d %H:%M:%S\")] All timepoints have been bootstrapped successfully'
    ")

# Extract job ID
bootstrap_job_id=$(echo ${bootstrap_job} | awk '{print $4}')
echo "Submitted bootstrap job with ID: ${bootstrap_job_id}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preprocessing workflow controller completed"
echo "Monitor progress with: squeue -u $USER" 