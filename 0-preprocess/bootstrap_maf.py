import pandas as pd
import numpy as np
import os
import argparse
from pathlib import Path

"""
The purpose of this script is to perform bootstrapping on the aggregated MAF data. 

This is the second step in the Mase-phi pipeline, as we are processing the aggregated MAF data to 
be used in PhyloWGS (or whatever other model we want to use). 

The script will take in the aggregated MAF data (from maf_agg.py). 

This script will then output an original SSM file given by the inputted MAF file, a CSV file with the bootstrapped data, 
and n directories, each containing a bootstrapped SSM file to be used by PhyloWGS. 

example: usage 
python bootstrap_maf.py -i <merged csv file> -o <output directory> -n <number of bootstraps> -p <generate phylowgs input>

NOTE: for -p you don't have to add anything after the flag. If you want phylowgs output, you must add the flag. 

The bootstrapping process:
1. First resamples read depths while maintaining total coverage
2. Then resamples variant frequencies using the new depths
3. Repeats this process n times to create bootstrap replicates

TODO: is there a better way to do this? scipy.stats.bootstrap?
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
    Performs bootstrapping on aggregated MAF data
    
    Args:
        maf_df: DataFrame from maf_agg.py containing merged mutation data
        num_bootstraps: Number of bootstrap iterations to perform
    
    Returns:
        DataFrame with original and bootstrapped columns
    """
    df_bootstrap = maf_df.copy()
    
    # Process tissue data
    tissue_af = maf_df["Variant_Frequencies_st"].tolist()
    tissue_depth = maf_df["Total_Depth_st"].tolist()
    
    tissue_af_boot, tissue_depth_boot = bootstrap_va_dt(tissue_af, tissue_depth, num_bootstraps)
    
    # Create column names for bootstrapped results
    tissue_af_cols = [f"Variant_Frequencies_st_bootstrap_{i+1}" for i in range(tissue_af_boot.shape[1])]
    tissue_depth_cols = [f"Total_Depth_st_bootstrap_{i+1}" for i in range(tissue_depth_boot.shape[1])]
    
    # Add bootstrapped tissue columns
    df_bootstrap = pd.concat([
        df_bootstrap,
        pd.DataFrame(tissue_af_boot, columns=tissue_af_cols),
        pd.DataFrame(tissue_depth_boot, columns=tissue_depth_cols)
    ], axis=1)
    
    # Process blood data if present
    if "Variant_Frequencies_cf" in maf_df.columns:
        blood_af = maf_df["Variant_Frequencies_cf"].tolist()
        blood_depth = maf_df["Total_Depth_cf"].tolist()
        
        blood_af_boot, blood_depth_boot = bootstrap_va_dt(blood_af, blood_depth, num_bootstraps)
        
        blood_af_cols = [f"Variant_Frequencies_cf_bootstrap_{i+1}" for i in range(blood_af_boot.shape[1])]
        blood_depth_cols = [f"Total_Depth_cf_bootstrap_{i+1}" for i in range(blood_depth_boot.shape[1])]
        
        df_bootstrap = pd.concat([
            df_bootstrap,
            pd.DataFrame(blood_af_boot, columns=blood_af_cols),
            pd.DataFrame(blood_depth_boot, columns=blood_depth_cols)
        ], axis=1)
    
    return df_bootstrap

def write_bootstrap_ssm(bootstrap_df, bootstrap_num, output_dir):
    """
    Write SSM data for a specific bootstrap iteration
    """
    # Create SSM file
    ssm_file = os.path.join(output_dir, f'ssm_data_bootstrap{bootstrap_num}.txt')
    os.makedirs(output_dir, exist_ok=True)
    
    # Create phyloWGS input for this bootstrap iteration
    boot_phylowgs = []
    for idx, row in bootstrap_df.iterrows():
        gene = row["Hugo_Symbol"] if isinstance(row["Hugo_Symbol"], str) else f"{row['Chromosome']}_{row['Start_Position']}"
        
        # Get tissue values
        tissue_depth = int(row[f"Total_Depth_st_bootstrap_{bootstrap_num}"])
        tissue_vaf = row[f"Variant_Frequencies_st_bootstrap_{bootstrap_num}"]
        tissue_ref = int(np.round(tissue_depth * (1 - tissue_vaf)))
        
        # Check if blood data exists for this bootstrap
        has_blood = (f"Total_Depth_cf_bootstrap_{bootstrap_num}" in bootstrap_df.columns and 
                    f"Variant_Frequencies_cf_bootstrap_{bootstrap_num}" in bootstrap_df.columns and 
                    not pd.isna(row[f"Total_Depth_cf_bootstrap_{bootstrap_num}"]))
        
        if has_blood:
            # Get blood values
            blood_depth = int(row[f"Total_Depth_cf_bootstrap_{bootstrap_num}"])
            blood_vaf = row[f"Variant_Frequencies_cf_bootstrap_{bootstrap_num}"]
            blood_ref = int(np.round(blood_depth * (1 - blood_vaf)))
            
            # Combine blood and tissue values with blood first
            ref_count = f"{blood_ref},{tissue_ref}"
            depth = f"{blood_depth},{tissue_depth}"
        else:
            # Use only tissue values
            ref_count = str(tissue_ref)
            depth = str(tissue_depth)
        
        boot_phylowgs.append({
            'id': f's{idx}',
            'gene': gene,
            'a': ref_count,
            'd': depth,
            'mu_r': 0.999,
            'mu_v': 0.499
        })
    
    # Save phyloWGS input for this bootstrap iteration
    df_boot = pd.DataFrame(boot_phylowgs)
    df_boot.to_csv(ssm_file, sep='\t', index=False)
    
    # Create empty CNV file (completely empty)
    cnv_file = os.path.join(output_dir, f'cnv_data_bootstrap{bootstrap_num}.txt')
    open(cnv_file, 'w').close()  # Creates an empty file

def main():
    parser = argparse.ArgumentParser(description='Bootstrap MAF data')
    parser.add_argument('-i', '--input', required=True,
                       help='Input MAF CSV file (output from maf_agg.py)')
    parser.add_argument('-o', '--output', required=True,
                       help='Output directory for bootstrapped files')
    parser.add_argument('-n', '--num_bootstraps', type=int, default=100,
                       help='Number of bootstrap iterations')
    args = parser.parse_args()

    # Read merged MAF data
    maf_df = pd.read_csv(args.input)
    
    # Perform bootstrapping
    bootstrap_df = bootstrap_maf(maf_df, args.num_bootstraps)
    
    # Save bootstrapped data
    os.makedirs(args.output, exist_ok=True)
    bootstrap_df.to_csv(os.path.join(args.output, 'bootstrapped_maf.csv'), index=False)

    # Create bootstrap SSM and CNV files
    for i in range(1, args.num_bootstraps + 1):
        boot_dir = os.path.join(args.output, f'bootstrap{i}')
        os.makedirs(boot_dir, exist_ok=True)
        
        # Create SSM and CNV files for this bootstrap
        write_bootstrap_ssm(bootstrap_df, i, boot_dir)

if __name__ == "__main__":
    main() 