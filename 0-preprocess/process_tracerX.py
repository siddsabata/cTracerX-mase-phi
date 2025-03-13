import pandas as pd
import numpy as np
import argparse
import os
import sys
from pathlib import Path
from datetime import datetime

"""
The purpose of this script is to aggregate meaningful mutation data from TRACERx data from the supplementary table. 

The script will process mutation data for each timepoint in a patient's longitudinal samples.
For each timepoint, it will create a separate directory and generate SSM files needed for phylogenetic analysis.

Results will be saved as a .csv file to an inputted directory with subdirectories for each timepoint.

You can run this script with the following command: 

python process_tracerX.py -i <input csv> -o <output directory> [-p <patient_id1,patient_id2,...>]
"""

def create_ssm_file(timepoint_df, output_dir):
    """
    Creates SSM file from patient data for a specific timepoint and saves it to the output directory.
    
    Args:
        timepoint_df (DataFrame): Patient data for a specific timepoint
        output_dir (Path): Directory to save the SSM file
    """
    ssm_entries = []
    # Reset index to ensure we start counting from 0 for each timepoint
    for idx, row in timepoint_df.reset_index(drop=True).iterrows():
        # Calculate reference reads from total depth and mutant reads
        total_depth = row["DOR"]
        ref_reads = total_depth - row["MutDOR"]
        
        # Format gene as Hugo_Symbol_Chromosome_Position
        gene = f"{row['Hugo_Symbol']}_{row['Chromosome']}_{row['Position']}"
        
        ssm_entries.append({
            "id": f"s{idx}",
            "gene": gene,
            "a": str(int(ref_reads)),
            "d": str(int(total_depth)),
            "mu_r": 0.999,
            "mu_v": 0.499
        })

    ssm_df = pd.DataFrame(ssm_entries)
    
    # Save SSM file
    ssm_file = output_dir / 'ssm_data.txt'
    ssm_df.to_csv(ssm_file, sep='\t', index=False)
    
    # Create empty CNV file (required by PhyloWGS)
    cnv_file = output_dir / 'cnv_data.txt'
    cnv_file.touch()

def process_patient_data(patient_df, patient_id, output_dir):
    """
    Process data for a single patient and generate required outputs for each timepoint.
    
    Args:
        patient_df (DataFrame): Data for this patient
        patient_id (str): Patient identifier
        output_dir (Path): Base output directory
        
    Returns:
        int: Number of timepoints processed
    """
    # Create patient directory structure
    patient_dir = output_dir / patient_id
    os.makedirs(patient_dir, exist_ok=True)
    
    # Get unique timepoints (date samples)
    timepoints = patient_df[['DateSample', 'Baseline_longitudinal']].drop_duplicates()
    
    processed_timepoints = 0
    
    print(f"  Found {len(timepoints)} timepoints for patient {patient_id}")
    
    # Process each timepoint
    for _, timepoint in timepoints.iterrows():
        date_sample = timepoint['DateSample']
        baseline_longitudinal = timepoint['Baseline_longitudinal'].lower()
        
        print(f"    Processing timepoint: {date_sample} ({baseline_longitudinal})")
        
        # Format date for directory name
        formatted_date = date_sample
        
        # Create directory for this timepoint
        timepoint_dir_name = f"{patient_id}_{baseline_longitudinal}_{formatted_date}"
        timepoint_dir = patient_dir / timepoint_dir_name
        os.makedirs(timepoint_dir, exist_ok=True)
        
        # Get data for this timepoint
        timepoint_data = patient_df[
            (patient_df['DateSample'] == date_sample) & 
            (patient_df['Baseline_longitudinal'] == timepoint['Baseline_longitudinal'])
        ].copy()
        
        # Process data for this timepoint
        if timepoint_data.empty:
            empty_flag = timepoint_dir / 'empty.txt'
            with open(empty_flag, 'w') as f:
                f.write(f"No mutations found for patient {patient_id} at timepoint {date_sample}.\n")
            print(f"    No mutations found for timepoint {date_sample}")
            continue
        
        # Convert the data into the expected format for saving
        processed_data = []
        for _, row in timepoint_data.iterrows():
            processed_row = {
                'Hugo_Symbol': row['Hugo_Symbol'],
                'Chromosome': row['Chromosome'],
                'Position': row['Position'],
                'Ref': row['Ref'],
                'Mut': row['Mut'],
                'RefVAF': row['RefVAF'],
                'MutVAF': row['MutVAF'],
                'DOR': row['DOR'],
                'MutDOR': row['MutDOR']
            }
            processed_data.append(processed_row)
        
        # Save processed data as CSV
        output_df = pd.DataFrame(processed_data)
        output_file = timepoint_dir / f'patient_{patient_id}_{formatted_date}.csv'
        output_df.to_csv(output_file, index=False)
        
        # Create SSM and CNV files for this timepoint
        create_ssm_file(timepoint_data, timepoint_dir)
        
        processed_timepoints += 1
        print(f"    Processed timepoint {date_sample} ({baseline_longitudinal}) - {len(timepoint_data)} mutations")
    
    return processed_timepoints

def filter_patients(df, patient_ids=None):
    """
    Filter dataframe to include only specified patients or all patients if none specified.
    
    Args:
        df (DataFrame): Input dataframe with patient data
        patient_ids (list, optional): List of patient IDs to include. If None, include all.
        
    Returns:
        list: List of patient IDs to process
    """
    all_patient_ids = sorted(df['SampleID'].unique())
    
    if patient_ids is None:
        return all_patient_ids
    
    # Check if specified patient IDs exist in the data
    valid_patient_ids = []
    for pid in patient_ids:
        if pid in all_patient_ids:
            valid_patient_ids.append(pid)
        else:
            print(f"Warning: Patient ID '{pid}' not found in the data.")
    
    if not valid_patient_ids:
        print("No valid patient IDs specified. Using all available patients.")
        return all_patient_ids
    
    return valid_patient_ids

def main():
    parser = argparse.ArgumentParser(description='Process TracerX mutation data by timepoint')
    parser.add_argument('-i', '--input', required=True,
                       help='Input consolidated CSV file')
    parser.add_argument('-o', '--output_dir', required=True,
                       help='Base output directory')
    parser.add_argument('-p', '--patients', 
                       help='Comma-separated list of patient IDs to process (if omitted, process all)')
    args = parser.parse_args()

    try:
        # Read input CSV
        print(f"Reading input file: {args.input}")
        df = pd.read_csv(args.input)
        
        # Create output directory
        output_dir = Path(args.output_dir)
        os.makedirs(output_dir, exist_ok=True)
        
        # Parse patient IDs if provided
        patient_ids = None
        if args.patients:
            patient_ids = [pid.strip() for pid in args.patients.split(',')]
            print(f"Filtering to specified patients: {', '.join(patient_ids)}")
        
        # Get list of patients to process
        patients_to_process = filter_patients(df, patient_ids)
        print(f"Found {len(patients_to_process)} patients to process")
        
        # Process each patient
        total_timepoints = 0
        processed_patients = 0
        
        print("\n--- PROCESSING PATIENTS ---")
        for patient_id in patients_to_process:
            print(f"\nProcessing patient: {patient_id}")
            
            # Get data for this patient
            patient_df = df[df['SampleID'] == patient_id].copy()
            
            # Process patient data
            timepoints = process_patient_data(patient_df, patient_id, output_dir)
            if timepoints > 0:
                processed_patients += 1
                total_timepoints += timepoints
                print(f"  Successfully processed {timepoints} timepoints for patient {patient_id}")
            else:
                print(f"  No valid timepoints found for patient {patient_id}")
        
        print(f"\nCompleted processing {processed_patients} patients with {total_timepoints} total timepoints")
        
    except Exception as e:
        print(f"Error processing data: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()