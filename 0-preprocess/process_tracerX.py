import pandas as pd
import numpy as np
import argparse
import os
import sys
from pathlib import Path

"""
The purpose of this script is to aggregate meaningful mutation data from multiple MAF files. 

This is the first step in the Mase-phi pipeline, as we are proecessing raw Illumina sequencing data to 
be used in the next file (bootstrap.py). 

This file takes in 3 different MAF files: 
The files are titled `MAFconversion_<sample type>....txt`
1) Blood maf (MAFconversion_CF....txt)
2) Tissue maf (MAFconversion_ST....txt)
3) Germline maf (MAFconversion_BC....txt)

The script will perform an inner join (common) or outer join (union) on the blood and tissue mafs, 
and then perform a set difference between the joined blood and tissue mafs and the germline maf. 

Results will be saved as a .csv file to an inputted directory. 

You can run this script with the following command: 

python maf_agg.py -c <blood(cf) maf> -s <tissue(st) maf> -b <germline(bc) maf> -o <output directory> -m <method>
"""

def create_ssm_file(patient_df, output_dir):
    """
    Creates SSM file from patient data and saves it to the output directory.
    
    Args:
        patient_df (DataFrame): Patient data
        output_dir (Path): Directory to save the SSM file
    """
    ssm_entries = []
    for idx, row in patient_df.iterrows():
        # Skip rows that don't have total depth or allele frequency
        if pd.isna(row["ddp"]) or pd.isna(row["daf"]):
            continue

        # Use gene_name if provided; otherwise, use "chromosome_position"
        if pd.notna(row["gene_name"]) and row["gene_name"] != "":
            gene = row["gene_name"]
        else:
            gene = f"{row['chromosome']}_{row['position']}"

        # Extract total depth and allele frequency
        total_depth = int(row["ddp"])
        allele_frequency = row["daf"]

        # Calculate reference reads
        ref_count = int(round(total_depth * (1 - allele_frequency)))

        ssm_entries.append({
            "id": f"s{idx}",
            "gene": gene,
            "a": str(ref_count),
            "d": str(total_depth),
            "mu_r": 0.999,
            "mu_v": 0.499
        })

    ssm_df = pd.DataFrame(ssm_entries)
    
    # Save SSM file
    ssm_file = output_dir / 'ssm_data_original.txt'
    ssm_df.to_csv(ssm_file, sep='\t', index=False)
    
    # Create empty CNV file (required by PhyloWGS)
    cnv_file = output_dir / 'cnv_data_original.txt'
    cnv_file.touch()

def process_patient_data(patient_df, patient_id, output_dir):
    """
    Process data for a single patient and generate required outputs.
    
    Args:
        patient_df (DataFrame): Data for this patient
        patient_id (str): Patient identifier
        output_dir (Path): Base output directory
    """
    # Create patient directory structure
    patient_dir = output_dir / patient_id
    common_dir = patient_dir / 'common'
    os.makedirs(common_dir, exist_ok=True)
    
    # Convert the data into the expected format
    processed_data = []
    
    for _, row in patient_df.iterrows():
        processed_row = {
            'Hugo_Symbol': row['gene_name'],
            'Chromosome': row['chromosome'],
            'Start_Position': row['position'],
            'End_Position': row['position'],  # Assuming SNVs
            'Variant_Frequencies': row['daf'],
            'Total_Depth': row['ddp'],
            'is_tree_clone': row['is_tree_clone'],
            'DriverMut': row['DriverMut']
        }
        processed_data.append(processed_row)
    
    # Convert to DataFrame and save
    output_df = pd.DataFrame(processed_data)
    output_file = common_dir / f'patient_{patient_id}.csv'
    output_df.to_csv(output_file, index=False)
    
    # Check if any mutations were found
    if output_df.empty:
        empty_flag = common_dir / 'empty.txt'
        with open(empty_flag, 'w') as f:
            f.write("No mutations found for this patient.\n")
        return False
    
    # Create SSM and CNV files
    create_ssm_file(patient_df, common_dir)
    
    return True

def main():
    parser = argparse.ArgumentParser(description='Process TracerX mutation data')
    parser.add_argument('-i', '--input', required=True,
                       help='Input consolidated CSV file')
    parser.add_argument('-o', '--output_dir', required=True,
                       help='Base output directory')
    args = parser.parse_args()

    try:
        # Read input CSV
        df = pd.read_csv(args.input)
        
        # Create output directory
        output_dir = Path(args.output_dir)
        os.makedirs(output_dir, exist_ok=True)
        
        # Process each patient
        processed_patients = 0
        for patient_id in df['PublicationID'].unique():
            print(f"Processing patient: {patient_id}")
            
            # Get data for this patient
            patient_df = df[df['PublicationID'] == patient_id].copy()
            
            # Process patient data
            if process_patient_data(patient_df, patient_id, output_dir):
                processed_patients += 1
                print(f"Successfully processed patient {patient_id}")
            else:
                print(f"No mutations found for patient {patient_id}")
        
        print(f"Completed processing {processed_patients} patients")
        
    except Exception as e:
        print(f"Error processing data: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()