#!/bin/bash
# --------------------------------------------------
# This initialization script sets up the following conda
# environments required by the pipeline:
#
# 1. preprocess_env   - Python 3 environment for steps 0-1 (preprocess and bootstrap)
# 2. phylowgs_env     - Python 2.7 environment for step 2 (PhyloWGS)
# 3. aggregation_env  - Python 3 environment for step 3 (aggregation)
# 4. markers_env      - Python 3 environment for step 4 (markers)
#
# For steps 0-1, 3, and 4, the corresponding requirements.txt or environment.yml
# files will be installed. For PhyloWGS, we clone the repository from:
# https://github.com/morrislab/phylowgs.git
# then install the necessary Python 2 dependencies and compile the 
# required C++ code.
#
# Before running this script, ensure that conda is installed and
# that system dependencies (e.g. GSL, build-essential) are available.
#
# Usage:
#   bash init.sh
# --------------------------------------------------

set -e

# Ensure conda commands are available.
source $(conda info --base)/etc/profile.d/conda.sh

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

# Create conda environments from yml files
echo "=== Creating preprocess_env (used for both preprocess and bootstrap) ==="
conda env create -f 0-preprocess/environment.yml

echo "=== Creating phylowgs_env ==="
conda env create -f 2-phylowgs/environment.yml

echo "=== Creating aggregation_env ==="
conda env create -f 3-aggregation/environment.yml

echo "=== Creating markers_env ==="
conda env create -f 4-markers/environment.yml

# Clone the PhyloWGS repository if it doesn't exist yet.
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

echo "Initialization complete. All conda environments have been set up." 