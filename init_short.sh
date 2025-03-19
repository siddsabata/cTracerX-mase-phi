#!/bin/bash
# --------------------------------------------------
# This initialization script performs minimal setup,
# assuming conda environments already exist:
#
# 1. Creates logs directory for SLURM output
# 2. Sets execute permissions for run scripts
# 3. Clones PhyloWGS (if needed) and compiles C++ code
#
# Note: The pipeline uses these conda environments:
# - preprocess_env: For preprocess and bootstrap steps
# - phylowgs_env: For PhyloWGS processing
# - aggregation_env: For aggregation step
# - markers_env: For marker selection step
#
# Usage:
#   bash init_short.sh
# --------------------------------------------------

set -e

echo "=== Starting minimal initialization ==="

# Create logs directory (needed for SLURM job output)
echo "Creating logs directory..."
mkdir -p logs
echo "Logs directory created successfully."

# Make all run scripts executable
echo "Setting execute permissions for run scripts..."
chmod +x 0-preprocess/run_preprocess.sh
chmod +x 1-bootstrap/run_bootstrap.sh
chmod +x 2-phylowgs/run_phylowgs.sh
chmod +x 3-aggregation/run_aggregation.sh
chmod +x 4-markers/run_markers.sh
chmod +x preprocess_worker.sh
chmod +x phylowgs_worker.sh
chmod +x postprocess_worker.sh
chmod +x pipeline_controller.sh
echo "Execute permissions set successfully."

# Clone the PhyloWGS repository if it doesn't exist yet
if [ ! -d "2-phylowgs/phylowgs" ]; then
    echo "Cloning PhyloWGS repository into 2-phylowgs/phylowgs..."
    git clone https://github.com/morrislab/phylowgs.git 2-phylowgs/phylowgs
else
    echo "PhyloWGS repository already cloned."
fi

# Compile PhyloWGS C++ code
echo "Compiling PhyloWGS C++ code..."
cd 2-phylowgs/phylowgs
g++ -o mh.o -O3 mh.cpp util.cpp `gsl-config --cflags --libs`
cd ../../

echo "=== Minimal initialization complete ==="
echo "Note: This script assumes conda environments are already set up."
echo "If they're not, please run the full init.sh instead." 