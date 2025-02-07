# Pipeline for Patient Data Processing

This project implements a multi-step data processing pipeline using SLURM and Conda environments. The pipeline consists of the following steps:

1. **Preprocessing (Step 0)**  
   Prepares each patient's input data.

2. **PhyloWGS (Step 1)**  
   Runs the PhyloWGS analysis (which requires a Python 2.7 environment).

3. **Aggregation (Step 2)**  
   Aggregates results from PhyloWGS.

4. **Marker Selection (Step 3)**  
   Performs marker selection analysis on the aggregated data.

Each step runs in its own Conda environment with the dependencies defined in its respective `requirements.txt` file.

---

## Prerequisites

- **Cluster Environment:**  
  On the cluster you must use Python 3.6. Load the module using:
  ```bash
  module add python36
  ```

- **Conda:**  
  Ensure that Miniconda or Anaconda is installed and available on the cluster.

- **System Dependencies:**  
  Make sure that system libraries (e.g., GSL, build-essential) are installed—especially needed for the PhyloWGS step.

---

## Initialization

Before running the pipeline, set up the necessary Conda environments by executing the initialization script:
```bash
bash init.sh
```

The `init.sh` script performs the following:
- **Preprocessing, Aggregation, and Marker Selection:**  
  Creates three Python 3 environments named `preprocess_env`, `aggregation_env`, and `markers_env` and installs the required packages from their respective `requirements.txt` files.
- **PhyloWGS:**  
  Creates a Python 2.7 environment named `phylowgs_env`, installs legacy packages (NumPy, SciPy, ETE2), clones the PhyloWGS repository from [morrislab/phylowgs](https://github.com/morrislab/phylowgs.git) into the `1-phylowgs` folder, and compiles the necessary C++ code.

---

## Running the Pipeline

The entire pipeline is orchestrated by a SLURM script (which you can rename to `main.sh` if desired). This script:

- Determines the patient ID by reading the subdirectories under the data directory (`DATA_DIR`).
- Runs each step sequentially (Preprocessing, PhyloWGS, Aggregation, and Marker Selection).
- Activates the appropriate Conda environment for each step.
- Uses hidden marker files in each patient directory (e.g., `.preprocess_completed`, `.phylowgs_completed`, etc.) to track completed steps so that re-processing is avoided.

### To Submit a Job

1. **Ensure Your Data is Organized:**  
   Your base data directory (specified via `DATA_DIR`) should contain a subdirectory for each patient.

2. **Submit the SLURM Job:**  
   For example, if your SLURM script is named `main.sh`, submit the job using:
   ```bash
   sbatch main.sh
   ```
   This will process each patient based on the SLURM array configuration.

3. **Monitor Job Progress:**  
   - Check the job queue:
     ```bash
     squeue -u $USER
     ```
   - Review logs in the `logs/` directory.

---

## Directory Structure

- **0-preprocess/** – Contains preprocessing scripts and `requirements.txt`.
- **1-phylowgs/** – Contains PhyloWGS scripts and the cloned repository.
- **2_aggregation/** – Contains aggregation scripts and `requirements.txt`.
- **3_markers/** – Contains marker selection scripts and `requirements.txt`.
- **init.sh** – Initializes and sets up all Conda environments.
- **main.sh** (formerly `process_patients.sh`) – SLURM job script that orchestrates the pipeline.
- **README.md** – This documentation file.

---

## Important Notes

- **Python Versions:**  
  Steps 0, 2, and 3 use Python 3. The PhyloWGS step (Step 1) requires Python 2.7 due to its legacy dependencies.

- **Module Requirements:**  
  Remember to load the Python 3.6 module on your cluster:
  ```bash
  module add python36
  ```

- **Re-running the Pipeline:**  
  Marker files (e.g., `.preprocess_completed`) are used to indicate a completed step. If you need to re-run a step, remove the corresponding marker file from the patient directory.

---

## Summary

1. **Load the Required Module:**
   ```bash
   module add python36
   ```

2. **Initialize the Environment:**
   ```bash
   bash init.sh
   ```

3. **Set the DATA_DIR:**
   Ensure that the `DATA_DIR` variable (in your configuration, e.g. in `main.sh` or a separate config file) is updated to point to your data directory.
   For example:
   ```bash
   export DATA_DIR="/path/to/your/data"
   ```

4. **Submit the Pipeline Job:**
   ```bash
   sbatch main.sh
   ```

The pipeline will then process each patient's data through all steps, logging progress in the `logs/` directory.

Happy Processing!
