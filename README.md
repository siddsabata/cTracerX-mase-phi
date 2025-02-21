# conda-Mase-phi: Multi-step Analysis of Subclonal Evolution using PhyloWGS and Hierarchical Inference

A pipeline for analyzing patient mutation data through multiple steps:
1. Preprocessing of mutation data
2. PhyloWGS analysis for subclonal reconstruction
3. Aggregation of PhyloWGS results
4. Marker selection for tracking clonal evolution

## Requirements

### Conda
Miniconda or Anaconda must be installed on your system. If you don't have it installed, follow the instructions at [Miniconda's website](https://docs.conda.io/en/latest/miniconda.html).

### GNU Scientific Library (GSL)
The PhyloWGS step requires GSL for its C++ components. Install GSL from [the official GNU website](https://www.gnu.org/software/gsl/). GSL provides essential mathematical routines used in the analysis.

## Data Directory Structure

### Input Data Format
The pipeline expects a consolidated CSV file containing mutation data for all patients with the following columns:
```
PublicationID,tracerx_id,days_post_surgery,chromosome,position,dao,ddp,daf,gene_name,exonic.func,is_tree_clone,DriverMut
```

### Final Structure
After running the pipeline, each patient directory will have this structure:
```
data/
└── patient_id/
    ├── common/
    │   ├── patient_[id].csv                           # Combined mutation data
    │   ├── bootstrapped_ssms.csv                      # Bootstrapped mutation data
    │   ├── cnv_data_original.txt                      # Original CNV data
    │   ├── ssm_data_original.txt                      # Original SSM data
    │   ├── bootstrap[1-5]/                            # Bootstrap directories
    │   │   ├── chains/                               # PhyloWGS chain results
    │   │   ├── tmp/                                  # Temporary files
    │   │   ├── ssm_data_bootstrap[N].txt            # Simple somatic mutations
    │   │   ├── cnv_data_bootstrap[N].txt            # Copy number variations
    │   │   ├── result.mutass.zip                    # Mutation assignments
    │   │   ├── result.muts.json.gz                  # Mutation details
    │   │   └── result.summ.json.gz                  # Summary results
    │   ├── aggregation/                              # Aggregation results
    │   │   ├── phylowgs_bootstrap_aggregation.pkl   # Aggregated data
    │   │   ├── phylowgs_bootstrap_summary.pkl       # Summary statistics
    │   │   ├── [id]_freq_dist[0-2]_common.png      # Frequency distributions
    │   │   ├── [id]_tree_dist[0-2]_common          # Tree distributions
    │   │   ├── [id]_tree_dist[0-2]_common.png      # Tree visualizations
    │   │   └── [id]_results_bootstrap_common_best.json  # Best tree results
    │   └── markers/                                  # Marker selection results
    │       ├── [id]_marker_selection_results.txt    # Selected markers
    │       ├── [id]_tracing_subclones.png          # Subclone tracking
    │       ├── [id]_trees_fractions_[params].png    # Tree fraction plots
    │       └── [id]_trees_structures_[params].png   # Tree structure plots
```

## Running the Pipeline

### First Time Setup
1. Run the initialization script to set up conda environments and clone required repositories:
   ```bash
   bash init.sh
   ```

2. Edit `setup.sh` to configure:
   - `DATA_DIR`: Path to your data directory
   - `INPUT_FILE`: Path to your consolidated CSV file

3. Run the setup script to process input data and launch the pipeline:
   ```bash
   bash setup.sh
   ```
   This will:
   - Create patient directories and process input data
   - Automatically determine the number of patients
   - Submit the main SLURM array job

### Subsequent Runs
1. Verify conda environments are present:
   ```bash
   conda info --envs
   ```
   You should see: preprocess_env, phylowgs_env, aggregation_env, and markers_env

2. If needed, edit pipeline parameters in `main.sh`:
   - `NUM_BOOTSTRAPS`: Number of bootstrap iterations (default: 5)
   - `NUM_CHAINS`: Number of PhyloWGS chains (default: 5)
   - `READ_DEPTH`: Read depth for marker selection (default: 1500)

3. Run setup script again:
   ```bash
   bash setup.sh
   ```

## Utility Scripts

### init_short.sh
Use this for quick reinitialization when conda environments are already set up:
```bash
bash init_short.sh
```
This script:
- Creates necessary directories
- Sets execute permissions
- Clones/compiles PhyloWGS (if needed)

### purge.sh
Removes all conda environments created by init.sh:
```bash
bash purge.sh
```
Use this when you need to clean up or rebuild environments from scratch.
