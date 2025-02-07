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

def write_phylowgs_input(bootstrap_df, output_path):
    """
    Converts bootstrapped MAF data to phyloWGS format
    """
    os.makedirs(output_path, exist_ok=True)
    
    # Write non-bootstrapped data first
    phylowgs_format = []
    for idx, row in bootstrap_df.iterrows():
        if pd.isna(row["Total_Depth_st"]) or pd.isna(row["Variant_Frequencies_st"]):
            continue
            
        gene = row["Hugo_Symbol"] if isinstance(row["Hugo_Symbol"], str) else f"{row['Chromosome']}_{row['Start_Position']}"
        
        # Get tissue values
        tissue_depth = int(row["Total_Depth_st"])
        tissue_vaf = row["Variant_Frequencies_st"]
        tissue_ref = int(np.round(tissue_depth * (1 - tissue_vaf)))
        
        # Check if blood data exists
        has_blood = "Total_Depth_cf" in row and "Variant_Frequencies_cf" in row and not pd.isna(row["Total_Depth_cf"])
        
        if has_blood:
            # Get blood values
            blood_depth = int(row["Total_Depth_cf"])
            blood_vaf = row["Variant_Frequencies_cf"]
            blood_ref = int(np.round(blood_depth * (1 - blood_vaf)))
            
            # Combine blood and tissue values with blood first
            ref_count = f"{blood_ref},{tissue_ref}"
            depth = f"{blood_depth},{tissue_depth}"
        else:
            # Use only tissue values
            ref_count = str(tissue_ref)
            depth = str(tissue_depth)
        
        phylowgs_format.append({
            'id': f's{idx}',
            'gene': gene,
            'a': ref_count,
            'd': depth,
            'mu_r': 0.999,
            'mu_v': 0.499
        })
    
    # Save non-bootstrapped data
    df_phylowgs = pd.DataFrame(phylowgs_format)
    df_phylowgs.to_csv(os.path.join(output_path, 'ssm_data_original.txt'), 
                       sep='\t', index=False)
    
    # Process bootstrapped data
    bootstrap_cols = [col for col in bootstrap_df.columns 
                     if col.startswith('Total_Depth_st_bootstrap_')]
    bootstrap_nums = [int(col.split('_')[-1]) for col in bootstrap_cols]
    num_bootstraps = max(bootstrap_nums)
    
    # Create phyloWGS input for each bootstrap iteration
    for i in range(1, num_bootstraps + 1):
        tissue_depth_col = f"Total_Depth_st_bootstrap_{i}"
        tissue_vaf_col = f"Variant_Frequencies_st_bootstrap_{i}"
        blood_depth_col = f"Total_Depth_cf_bootstrap_{i}"
        blood_vaf_col = f"Variant_Frequencies_cf_bootstrap_{i}"
        
        if tissue_depth_col not in bootstrap_df.columns or tissue_vaf_col not in bootstrap_df.columns:
            continue
            
        boot_phylowgs = []
        for idx, row in bootstrap_df.iterrows():
            gene = row["Hugo_Symbol"] if isinstance(row["Hugo_Symbol"], str) else f"{row['Chromosome']}_{row['Start_Position']}"
            
            # Get tissue values
            tissue_depth = int(row[tissue_depth_col])
            tissue_vaf = row[tissue_vaf_col]
            tissue_ref = int(np.round(tissue_depth * (1 - tissue_vaf)))
            
            # Check if blood data exists for this bootstrap
            has_blood = (blood_depth_col in bootstrap_df.columns and 
                        blood_vaf_col in bootstrap_df.columns and 
                        not pd.isna(row[blood_depth_col]))
            
            if has_blood:
                # Get blood values
                blood_depth = int(row[blood_depth_col])
                blood_vaf = row[blood_vaf_col]
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
        
        # Create directory for this bootstrap iteration and save file
        boot_dir = os.path.join(output_path, f'bootstrap{i}')
        os.makedirs(boot_dir, exist_ok=True)
        df_boot = pd.DataFrame(boot_phylowgs)
        df_boot.to_csv(os.path.join(boot_dir, f'ssm_data_bootstrap{i}.txt'), 
                      sep='\t', index=False)

def main():
    parser = argparse.ArgumentParser(description='Bootstrap MAF data and create phyloWGS input')
    parser.add_argument('-i', '--input', required=True,
                       help='Input MAF CSV file (output from maf_agg.py)')
    parser.add_argument('-o', '--output', required=True,
                       help='Output directory for bootstrapped files')
    parser.add_argument('-n', '--num_bootstraps', type=int, default=100,
                       help='Number of bootstrap iterations')
    parser.add_argument('-p', '--phylowgs', action='store_true',
                       help='Generate phyloWGS input files')
    args = parser.parse_args()

    # Read merged MAF data
    maf_df = pd.read_csv(args.input)
    
    # Perform bootstrapping
    bootstrap_df = bootstrap_maf(maf_df, args.num_bootstraps)
    
    # Save bootstrapped data
    os.makedirs(args.output, exist_ok=True)
    bootstrap_df.to_csv(os.path.join(args.output, 'bootstrapped_maf.csv'), index=False)
    
    # Generate phyloWGS input if requested
    if args.phylowgs:
        write_phylowgs_input(bootstrap_df, args.output)

if __name__ == "__main__":
    main() 