# cTracerX-mase-phi: Multi-Timepoint Tumor Evolution Analysis Pipeline

Analyzing tumor evolution across multiple timepoints from TRACERx study data.

This is an automated pipeline built from [Mase-phi](https://github.com/CMUSchwartzLab/Mase-phi)

Methods described in [Fu et al.](https://pubmed.ncbi.nlm.nih.gov/38586041/)

Fu, X., Luo, Z., Deng, Y., LaFramboise, W., Bartlett, D., & Schwartz, R. (2024). Marker selection strategies for circulating tumor DNA guided by phylogenetic inference. bioRxiv : the preprint server for biology, 2024.03.21.585352. https://doi.org/10.1101/2024.03.21.585352

## Pipeline Overview

A multi-stage pipeline for analyzing tumor evolution across different timepoints:
1. **Preprocessing**: Process mutation data for each timepoint and perform bootstrapping
2. **PhyloWGS**: Reconstruct subclonal structure for each timepoint
3. **Aggregation**: Combine PhyloWGS results across bootstraps for each timepoint
4. **Marker Selection**: Identify optimal mutation markers for each timepoint

## Requirements

### Conda
Miniconda or Anaconda must be installed on your system. If you don't have it installed, follow the instructions at [Miniconda's website](https://docs.conda.io/en/latest/miniconda.html).

### GNU Scientific Library (GSL)
The PhyloWGS step requires GSL for its C++ components. Install GSL from [the official GNU website](https://www.gnu.org/software/gsl/). GSL provides essential mathematical routines used in the analysis.

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
2. Count the number of patients in your data
3. Submit SLURM jobs to process each patient (one job per patient)
4. Each job will process all timepoints for that patient

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

### 2. SLURM Job Processing (`slurm_jobs.sh`)
For each patient, for each timepoint:

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

## Troubleshooting

### Common Issues
- **Missing input file**: Verify the path to your input CSV
- **Conda environment errors**: Run `conda info --envs` to check if environments exist
- **SLURM job failures**: Check logs in the `logs/` directory
- **PhyloWGS errors**: Ensure GSL is properly installed
- **No timepoint directories**: Check your input CSV format

### Restarting Failed Jobs
The pipeline includes checkpoint files to track completed steps. If a job fails:
1. Check the error logs to identify the issue
2. Fix the root cause
3. Remove the checkpoint file for the failed step (`.preprocess_complete`, etc.)
4. Resubmit the job

## Advanced Configuration

### Customizing Run Parameters
You can adjust these parameters in `main.sh`:
- `NUM_BOOTSTRAPS`: Higher values give better statistical confidence (default: 100)
- `NUM_CHAINS`: More chains improve MCMC sampling (default: 5)
- `READ_DEPTH`: Simulation read depth for marker selection (default: 1500)

### Running Individual Pipeline Steps
If needed, you can run individual steps for a timepoint:
```bash
# Run just bootstrapping
./0-preprocess/run_preprocess.sh /path/to/timepoint_dir 100

# Run just PhyloWGS
./1-phylowgs/run_phylowgs.sh /path/to/timepoint_dir 5 100
```
