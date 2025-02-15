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

### Initial Structure
Your source data is typically provided with this structure:
```
data/
└── patient_id/
    ├── MAFconversion_BC-[id].maf.v4.9.oncoKB.txt  # Blood MAF
    ├── MAFconversion_CF-[id].maf.v4.9.oncoKB.txt  # Cell-free MAF
    └── MAFconversion_ST-[id].maf.v4.9.oncoKB.txt  # Solid tumor MAF
```

The pipeline requires the MAF files to be in a 'mafs' subdirectory. Use the provided `organize_files.sh` script to reorganize your data:

1. Copy organize_files.sh to your source directory:
```bash
cp organize_files.sh /path/to/source_data/
cd /path/to/source_data/
```

2. Run the script to reorganize all patient directories:
```bash
bash organize_files.sh
```

This will create the required structure:
```
data/
└── patient_id/
    └── mafs/
        ├── MAFconversion_BC-[id].maf.v4.9.oncoKB.txt  # Blood MAF
        ├── MAFconversion_CF-[id].maf.v4.9.oncoKB.txt  # Cell-free MAF
        └── MAFconversion_ST-[id].maf.v4.9.oncoKB.txt  # Solid tumor MAF
```

After organizing your data, you can proceed with running the pipeline.

### Final Structure
After running the pipeline, each patient directory will have this structure:
```
data/
└── patient_id/
    ├── common/
    │   ├── patient_[id].csv                           # Combined mutation data
    │   ├── bootstrapped_maf.csv                       # Bootstrapped mutation data
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
    └── mafs/                                        # Original MAF files
        ├── MAFconversion_BC-[id].maf.v4.9.oncoKB.txt  # Blood MAF
        ├── MAFconversion_CF-[id].maf.v4.9.oncoKB.txt  # Cell-free MAF
        └── MAFconversion_ST-[id].maf.v4.9.oncoKB.txt  # Solid tumor MAF
```

## Running the Pipeline

### First Time Setup
1. Run the initialization script to set up conda environments and clone required repositories:
   ```bash
   bash init.sh
   ```

2. Edit `main.sh` to configure:
   - `DATA_DIR`: Path to your data directory
   - `--array=0-N`: Where N is (number_of_patients - 1)
   - Other SLURM parameters as needed

3. Submit the job:
   ```bash
   sbatch main.sh
   ```

### Subsequent Runs
1. Verify conda environments are present:
   ```bash
   conda info --envs
   ```
   You should see: preprocess_env, phylowgs_env, aggregation_env, and markers_env

2. Edit `main.sh` as needed and submit:
   ```bash
   sbatch main.sh
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
