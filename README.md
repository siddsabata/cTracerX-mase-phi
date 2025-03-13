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

## Data Directory Structure

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

### First Time Setup
1. Run the initialization script to set up conda environments and clone required repositories:
   ```bash
   bash init.sh
   ```

2. Process the input data to create timepoint directories:
   ```bash
   python 0-preprocess/process_tracerX.py -i eda/cruk0044.csv -o /path/to/output
   ```
   This creates the timepoint directories for each patient.

3. Run the full pipeline across all timepoints:
   ```bash
   export DATA_DIR="/path/to/output"
   export INPUT_FILE="eda/cruk0044.csv"
   sbatch --array=0-N slurm_jobs.sh
   ```
   Where N is the number of patients minus 1.

### Configuration
Edit parameters in `slurm_jobs.sh`:
- `DATA_DIR`: Path to your data directory
- `INPUT_FILE`: Path to your consolidated CSV file
- `NUM_BOOTSTRAPS`: Number of bootstrap iterations (default: 100)
- `NUM_CHAINS`: Number of PhyloWGS chains (default: 5)
- `READ_DEPTH`: Read depth for marker selection (default: 1500)

### Utility Scripts

#### init_short.sh
Use this for quick reinitialization when conda environments are already set up:
```bash
bash init_short.sh
```
This script:
- Creates necessary directories
- Sets execute permissions
- Clones/compiles PhyloWGS (if needed)

#### purge.sh
Removes all conda environments created by init.sh:
```bash
bash purge.sh
```
Use this when you need to clean up or rebuild environments from scratch.

## Analysis Workflow

1. **Initial Processing** (`process_tracerX.py`):
   - Reads the consolidated CSV file
   - Creates timepoint directories for each patient
   - Generates timepoint CSV files with mutation data

2. **For each timepoint**:
   - **Bootstrapping** (`bootstrap.py`):
     - Performs statistical resampling of mutation data
     - Creates bootstrap directories with SSM/CNV files
   
   - **PhyloWGS** (`run_phylowgs.sh`):
     - Reconstructs evolutionary trees for each bootstrap
     - Produces mutation assignments and summary files
   
   - **Aggregation** (`process_tracerx_bootstrap.py`):
     - Combines results across bootstraps
     - Identifies consensus tree structures
   
   - **Marker Selection** (`run_data.py`):
     - Identifies optimal mutations for tracking
     - Generates visualization plots

This pipeline enables analysis of tumor evolution across different timepoints, providing insight into how the tumor changes over time.
