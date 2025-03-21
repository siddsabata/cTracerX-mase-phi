import pandas as pd
import numpy as np
import os
import argparse
from pathlib import Path

"""
The purpose of this script is to perform bootstrapping on mutation data from TRACERx.

This script takes the processed data from process_tracerX.py and performs bootstrapping
to quantify uncertainty in the variant calls. It creates multiple bootstrap replicates
which can then be analyzed by PhyloWGS.

Usage: 
python bootstrap.py -i <input csv file> -o <output directory> -n <number of bootstraps>
"""

def bootstrap_va_dt(AF_list, Depth_list, bootstrap_num):
    """
    Advanced bootstrapping of both depths and frequencies
    
    Args:
        AF_list: List of allele frequencies
        Depth_list: List of read depths
        bootstrap_num: Number of bootstrap samples
    
    Returns:
        Tuple of (bootstrapped frequencies, bootstrapped depths)
    """
    AF_array = np.array(AF_list)
    Depth_array = np.array(Depth_list)
    total_depth = sum(Depth_list)
    
    count = 0
    while True:
        count += 1
        new_Depth_list = np.random.multinomial(n=total_depth, 
                                             pvals=np.array(Depth_list)/total_depth, 
                                             size=bootstrap_num)
        
        if not np.any(new_Depth_list == 0):
            break
            
        if count >= 10:
            new_Depth_list[np.where(new_Depth_list == 0)] = 1
            break
    
    AF_list_update = np.zeros((len(AF_list), bootstrap_num))
    for i in range(len(AF_list)):
        for j in range(bootstrap_num):
            sample = np.random.binomial(n=new_Depth_list[j, i], 
                                      p=AF_list[i], 
                                      size=1)[0]
            AF_list_update[i, j] = sample / new_Depth_list[j, i]
    
    new_Depth_list = new_Depth_list.T
    return AF_list_update, new_Depth_list

def bootstrap_maf(maf_df, num_bootstraps):
    """
    Performs bootstrapping on mutation data
    
    Args:
        maf_df: DataFrame from process_tracerX.py containing mutation data
        num_bootstraps: Number of bootstrap iterations to perform
    
    Returns:
        DataFrame with original and bootstrapped columns
    """
    df_bootstrap = maf_df.copy()
    
    # Get variant frequency and depth columns - handle both old and new column names
    if "MutVAF" in maf_df.columns:
        af = maf_df["MutVAF"].tolist()
    elif "Variant_Frequencies" in maf_df.columns:
        af = maf_df["Variant_Frequencies"].tolist()
    else:
        raise ValueError("Could not find variant frequency column (MutVAF or Variant_Frequencies)")
    
    if "DOR" in maf_df.columns:
        depth = maf_df["DOR"].tolist()
    elif "Total_Depth" in maf_df.columns:
        depth = maf_df["Total_Depth"].tolist()
    else:
        raise ValueError("Could not find depth column (DOR or Total_Depth)")
    
    af_boot, depth_boot = bootstrap_va_dt(af, depth, num_bootstraps)
    
    # Create column names for bootstrapped results
    af_cols = [f"Variant_Frequencies_bootstrap_{i+1}" for i in range(af_boot.shape[1])]
    depth_cols = [f"Total_Depth_bootstrap_{i+1}" for i in range(depth_boot.shape[1])]
    
    # Add bootstrapped columns
    df_bootstrap = pd.concat([
        df_bootstrap,
        pd.DataFrame(af_boot, columns=af_cols),
        pd.DataFrame(depth_boot, columns=depth_cols)
    ], axis=1)
    
    return df_bootstrap

def write_bootstrap_ssm(bootstrap_df, bootstrap_num, output_dir):
    """
    Write SSM data for a specific bootstrap iteration
    
    Args:
        bootstrap_df: DataFrame with bootstrapped data
        bootstrap_num: The bootstrap iteration number
        output_dir: Directory to write the SSM files
    """
    # Create bootstrap directory
    bootstrap_dir = os.path.join(output_dir, f'bootstrap{bootstrap_num}')
    os.makedirs(bootstrap_dir, exist_ok=True)
    
    # Create SSM file
    ssm_file = os.path.join(bootstrap_dir, f'ssm_data_bootstrap{bootstrap_num}.txt')
    
    # Create phyloWGS input for this bootstrap iteration
    boot_phylowgs = []
    for idx, row in bootstrap_df.iterrows():
        # Handle different column naming conventions
        if "Hugo_Symbol" in bootstrap_df.columns:
            gene_col = "Hugo_Symbol"
        else:
            gene_col = "Gene"
            
        if "Position" in bootstrap_df.columns:
            pos_col = "Position"
        elif "Start_Position" in bootstrap_df.columns:
            pos_col = "Start_Position"
        else:
            pos_col = None
        
        # Get gene name or chromosome_position
        if pd.notna(row[gene_col]) and isinstance(row[gene_col], str):
            gene = row[gene_col]
        elif "Chromosome" in bootstrap_df.columns and pos_col is not None:
            gene = f"{row['Chromosome']}_{row[pos_col]}"
        else:
            gene = f"gene_{idx}"
        
        # Get values for this bootstrap
        boot_vaf_col = f"Variant_Frequencies_bootstrap_{bootstrap_num}"
        boot_depth_col = f"Total_Depth_bootstrap_{bootstrap_num}"
        
        depth = int(row[boot_depth_col])
        vaf = row[boot_vaf_col]
        ref_count = int(np.round(depth * (1 - vaf)))
        
        boot_phylowgs.append({
            'id': f's{idx}',
            'gene': gene,
            'a': str(ref_count),
            'd': str(depth),
            'mu_r': 0.999,
            'mu_v': 0.499
        })
    
    # Save phyloWGS input for this bootstrap iteration
    df_boot = pd.DataFrame(boot_phylowgs)
    df_boot.to_csv(ssm_file, sep='\t', index=False)
    
    # Create empty CNV file with header
    cnv_file = os.path.join(bootstrap_dir, f'cnv.txt')
    with open(cnv_file, 'w') as f:
        f.write("chr\tstart\tend\tmajor_cn\tminor_cn\tcellular_prevalence\n")

def main():
    parser = argparse.ArgumentParser(description='Bootstrap mutation data')
    parser.add_argument('-i', '--input', required=True,
                       help='Input CSV file with mutation data')
    parser.add_argument('-o', '--output', required=True,
                       help='Output directory for bootstrapped files')
    parser.add_argument('-n', '--num_bootstraps', type=int, default=100,
                       help='Number of bootstrap iterations')
    args = parser.parse_args()

    # Ensure output directory exists
    os.makedirs(args.output, exist_ok=True)
    
    # Read input data
    print(f"Reading input file: {args.input}")
    maf_df = pd.read_csv(args.input)
    
    # Perform bootstrapping
    print(f"Performing {args.num_bootstraps} bootstrap iterations...")
    bootstrap_df = bootstrap_maf(maf_df, args.num_bootstraps)
    
    # Save bootstrapped data
    bootstrap_df.to_csv(os.path.join(args.output, 'bootstrapped_ssms.csv'), index=False)

    # Create bootstrap SSM and CNV files
    print("Creating bootstrap files for PhyloWGS...")
    for i in range(1, args.num_bootstraps + 1):
        # Create SSM and CNV files for this bootstrap
        write_bootstrap_ssm(bootstrap_df, i, args.output)
    
    print(f"Bootstrap process completed. Files saved to {args.output}")

if __name__ == "__main__":
    main() 