#!/bin/bash
# --------------------------------------------------
# This initialization script sets up the following conda
# environments required by the pipeline:
#
# 1. preprocess_env   - Python 3 environment for step 0 (preprocess)
# 2. phylowgs_env     - Python 2.7 environment for step 1 (PhyloWGS)
# 3. aggregation_env  - Python 3 environment for step 2 (aggregation)
# 4. markers_env      - Python 3 environment for step 3 (markers)
#
# For steps 0, 2, and 3, the corresponding requirements.txt files
# will be installed. For PhyloWGS, we clone the repository from:
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

echo "=== Setting up preprocess_env (Python 3) ==="
conda create -n preprocess_env python=3 -y
echo "Installing packages for preprocess_env..."
conda run -n preprocess_env pip install -r 0-preprocess/requirements.txt

echo "=== Setting up aggregation_env (Python 3) ==="
conda create -n aggregation_env python=3 -y
echo "Installing packages for aggregation_env..."
conda run -n aggregation_env pip install -r 2-aggregation/requirements.txt

echo "=== Setting up markers_env (Python 3) ==="
conda create -n markers_env python=3 -y
echo "Installing packages for markers_env..."
conda run -n markers_env pip install -r 3-markers/requirements.txt

echo "=== Setting up phylowgs_env (Python 2.7) ==="
conda create -n phylowgs_env python=2.7 -y
echo "Installing pip in phylowgs_env..."
conda install -n phylowgs_env pip=9.0.3 -y

# Activate phylowgs_env to install Python 2 dependencies.
echo "Activating phylowgs_env..."
conda activate phylowgs_env

# Install Python 2 dependencies from requirements.txt
echo "Installing Python 2 dependencies for PhyloWGS from requirements.txt..."
pip install -r 1-phylowgs/requirements.txt

# Clone the PhyloWGS repository if it doesn't exist yet.
if [ ! -d "1-phylowgs/phylowgs" ]; then
    echo "Cloning PhyloWGS repository into 1-phylowgs/phylowgs..."
    git clone https://github.com/morrislab/phylowgs.git 1-phylowgs/phylowgs
else
    echo "PhyloWGS repository already cloned."
fi

# Compile PhyloWGS C++ code
echo "Compiling PhyloWGS C++ code..."
cd 1-phylowgs/phylowgs
g++ -o mh.o -O3 mh.cpp util.cpp `gsl-config --cflags --libs`
cd ../../

echo "Initialization complete. All conda environments have been set up." 