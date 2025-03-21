# cTracerX-mase-phi: Multi-Timepoint Tumor Evolution Analysis Pipeline

Analyzing tumor evolution across multiple timepoints from TRACERx study data.

This is an automated pipeline built from [Mase-phi](https://github.com/CMUSchwartzLab/Mase-phi)

Methods described in [Fu et al.](https://pubmed.ncbi.nlm.nih.gov/38586041/)

Fu, X., Luo, Z., Deng, Y., LaFramboise, W., Bartlett, D., & Schwartz, R. (2024). Marker selection strategies for circulating tumor DNA guided by phylogenetic inference. bioRxiv : the preprint server for biology, 2024.03.21.585352. https://doi.org/10.1101/2024.03.21.585352

## Pipeline Overview

A multi-stage pipeline for analyzing tumor evolution across different timepoints:
1. **Preprocessing & Bootstrapping**: Process mutation data for each timepoint and perform bootstrapping
2. **PhyloWGS**: Reconstruct subclonal structure for each timepoint (parallelized for performance)
3. **Aggregation & Marker Selection**: Combine PhyloWGS results across bootstraps and identify optimal mutation markers

## Requirements

### Conda
Miniconda or Anaconda must be installed on your system. If you don't have it installed, follow the instructions at [Miniconda's website](https://docs.conda.io/en/latest/miniconda.html).

### GNU Scientific Library (GSL)
The PhyloWGS step requires GSL for its C++ components. Install GSL from [the official GNU website](https://www.gnu.org/software/gsl/). GSL provides essential mathematical routines used in the analysis.

### SLURM Job Scheduler
This pipeline is designed to run on high-performance computing clusters with the SLURM job scheduler.

## Data Format and Directory Structure

### Input Data Format
The pipeline expects a consolidated CSV file containing mutation data for all patients and timepoints with the following columns:
```
PublicationID,tracerx_id,days_post_surgery,chromosome,position,dao,ddp,daf,gene_name,exonic.func,is_tree_clone,DriverMut
```

### Directory Structure
After running the pipeline, each patient will have multiple timepoint directories:
```
data/
└── patient_id/
    ├── patient_id_baseline_YYYY-MM-DD/             # Timepoint directory 1
    │   ├── timepoint_data.csv                     # Timepoint mutation data
    │   ├── bootstrapped_ssms.csv                  # Bootstrapped mutation data
    │   ├── bootstrap[1-N]/                        # Bootstrap directories
    │   │   ├── ssm_data_bootstrap[N].txt         # Simple somatic mutations
    │   │   ├── cnv_data_bootstrap[N].txt         # Copy number variations
    │   │   ├── chains/                           # PhyloWGS chain results
    │   │   ├── tmp/                              # Temporary files
    │   │   ├── result.mutass.zip                # Mutation assignments
    │   │   ├── result.muts.json.gz              # Mutation details
    │   │   └── result.summ.json.gz              # Summary results
    │   ├── aggregation/                          # Aggregation results
    │   │   ├── phylowgs_bootstrap_aggregation.pkl
    │   │   ├── phylowgs_bootstrap_summary.pkl
    │   │   └── [timepoint]_results_bootstrap_common_best.json
    │   └── markers/                              # Marker selection results
    │       ├── [timepoint]_marker_selection_results.txt
    │       ├── [timepoint]_tracing_subclones.png
    │       └── [timepoint]_trees_[params].png
    │
    ├── patient_id_followup1_YYYY-MM-DD/           # Timepoint directory 2
    │   ├── (similar structure as above)
    │
    └── patient_id_followup2_YYYY-MM-DD/           # Timepoint directory 3
        └── (similar structure as above)
```

## Running the Pipeline

### Step 1: Initial Setup
First, set up the conda environments and dependencies:
```bash
# Clone the repository
git clone https://github.com/siddsabata/cTracerX-mase-phi.git
cd cTracerX-mase-phi

# Full setup (first time only)
bash init.sh

# OR for quick setup if environments already exist
bash init_short.sh
```

### Step 2: Configure the Pipeline
Edit the configuration section in `main.sh`:
```bash
# Configuration variables - EDIT THESE FOR YOUR ENVIRONMENT
export DATA_DIR="/path/to/output/directory"   # <-- EDIT THIS
export INPUT_FILE="/path/to/cruk0044.csv"     # <-- EDIT THIS
export NUM_BOOTSTRAPS=100   # Number of bootstrap iterations
export NUM_CHAINS=5         # Number of PhyloWGS chains
export READ_DEPTH=1500      # Read depth for marker selection
```

### Step 3: Run the Pipeline
Simply execute the main script:
```bash
bash main.sh
```

This will:
1. Process your input CSV file to create timepoint directories
2. Find all timepoint directories across all patients
3. Submit a SLURM array job with one task per timepoint
4. Each task processes one timepoint through all pipeline stages

### Step 4: Monitor Progress
Check the status of your jobs:
```bash
# View job status
squeue -u $USER

# Check job logs
tail -f logs/mase_phi_JOBID_*.out
```

## Pipeline Workflow

### 1. Initial Processing (`main.sh` → `process_tracerX.py`)
- Reads the input CSV file 
- Creates patient directories with timepoint subdirectories
- Each timepoint directory contains a CSV file with mutation data
- Creates a list of all timepoint directories

### 2. Parallel Timepoint Processing (`slurm_jobs.sh`)
For each timepoint (running as a separate SLURM array task):

**Preprocessing:**
- Runs `bootstrap.py` on the timepoint CSV file
- Creates bootstrap directories with SSM/CNV files for PhyloWGS

**PhyloWGS:**
- Runs `run_phylowgs.sh` to reconstruct evolutionary trees
- Creates chains and results for each bootstrap

**Aggregation:**
- Runs `process_tracerx_bootstrap.py` to combine bootstrap results
- Identifies consensus trees and clonal frequencies  

**Marker Selection:**
- Runs `run_data.py` to select optimal marker mutations
- Generates visualizations and reports

## Performance Considerations

The pipeline is designed for high-performance computing environments:

- **Highly Parallel**: Each timepoint runs as a separate SLURM job
- **Efficient Resource Use**: Processes can be distributed across many nodes
- **Checkpoint-Based**: Each completed step is marked to allow resuming after failure
- **High-Throughput**: Can process dozens or hundreds of timepoints simultaneously

For large datasets with many timepoints, consider:
- Adjusting the number of bootstrap samples based on your computational resources
- Setting reasonable time limits in the SLURM configuration
- Using resource-appropriate partitions for your cluster

## Installation

### Prerequisites

- SLURM job scheduler
- Conda/Miniconda
- Required dependencies (GSL, build-essential)

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/cTracerX-mase-phi.git
   cd cTracerX-mase-phi
   ```

2. Run the initialization script to set up the required environments:
   ```bash
   bash init.sh
   ```

3. Make the scripts executable:
   ```bash
   chmod +x *.sh
   chmod +x */*.sh
   ```

## Pipeline Workflow

The pipeline now consists of three main stages, each with its own script:

### 1. Preprocessing and Bootstrapping

Processes raw input data and generates bootstrap samples for each timepoint.

```bash
bash preprocess_bootstrap.sh <input_file> <data_dir> [num_bootstraps]
```

**Example:**
```bash
bash preprocess_bootstrap.sh /path/to/cruk0044.csv /path/to/data/dir 100
```

This script:
- Takes a CSV input file and processes it to create timepoint directories
- Submits a SLURM job to perform bootstrapping on all timepoints
- Generates bootstrap samples for PhyloWGS analysis

### 2. PhyloWGS Processing (Parallelized)

Runs PhyloWGS analysis on bootstrap samples for a specific timepoint, using parallelization to improve speed.

```bash
bash run_phylowgs_parallel.sh <timepoint_dir> [num_bootstraps] [num_chains] [chunk_size]
```

**Example:**
```bash
bash run_phylowgs_parallel.sh /path/to/data/CRUK0044_baseline_2014-11-28 100 5 10
```

This script:
- Takes a timepoint directory and runs PhyloWGS on its bootstrap samples
- Divides bootstrap samples into chunks (default: 10 per chunk) for parallel processing
- Submits SLURM array jobs to process each chunk
- Must be run for each timepoint you want to process

### 3. Post-processing

There are two options for post-processing:

#### Option A: Process a Single Timepoint

```bash
bash run_postprocessing.sh <timepoint_dir> [num_bootstraps] [read_depth]
```

**Example:**
```bash
bash run_postprocessing.sh /path/to/data/CRUK0044_baseline_2014-11-28 100 1500
```

#### Option B: Process All Timepoints for a Patient

```bash
bash run_all_postprocessing.sh <data_dir> [patient_id] [num_bootstraps] [read_depth]
```

**Example:**
```bash
bash run_all_postprocessing.sh /path/to/data CRUK0044 100 1500
```

Post-processing:
- Performs aggregation of PhyloWGS results from all bootstrap iterations
- Runs marker selection with specified read depth
- Creates final output files in the timepoint directories

## Complete Example Workflow

Here's an example of running the complete pipeline for patient CRUK0044:

```bash
# Step 1: Preprocess and bootstrap
bash preprocess_bootstrap.sh /path/to/cruk0044.csv /path/to/data 100

# Wait for bootstrapping to complete (check with: squeue -u $USER)

# Step 2: Run PhyloWGS for each timepoint (run these in parallel or sequence)
bash run_phylowgs_parallel.sh /path/to/data/CRUK0044_baseline_2014-11-28 100 5 10
bash run_phylowgs_parallel.sh /path/to/data/CRUK0044_relapse_2016-01-15 100 5 10

# Wait for PhyloWGS jobs to complete (check with: squeue -u $USER)

# Step 3: Run post-processing for all timepoints
bash run_all_postprocessing.sh /path/to/data CRUK0044 100 1500
```

## Monitoring Jobs

Monitor your SLURM jobs with:
```bash
squeue -u $USER
```

Check job logs in the `logs/` directory:
```bash
ls -la logs/
```

## Handling Failed Jobs

If a job fails, you can:

1. Check the logs in the `logs/` directory
2. Fix any issues that caused the failure
3. Rerun the appropriate script for that stage

The pipeline uses marker files to track completion of each step, so it will skip previously completed steps when possible.

## Notes About PhyloWGS

- PhyloWGS requires Python 2.7 (automatically handled by the phylowgs_env conda environment)
- Processing time varies based on the number of mutations in each timepoint
- PhyloWGS jobs are memory-intensive and can take up to 48 hours for complex samples

## Troubleshooting

- **Job fails immediately**: Check if you have access to the requested SLURM partition
- **Bootstrap job times out**: Increase the time limit in the `preprocess_bootstrap.sh` script
- **PhyloWGS memory errors**: Increase the memory allocation in `run_phylowgs_parallel.sh`
- **Missing timepoints**: Verify your input CSV file format matches what `process_tracerX.py` expects

For more detailed troubleshooting, check the SLURM job output in the `logs/` directory.
