import pandas as pd
import numpy as np
import argparse

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

def merge_mafs(cf, st, bc, method="inner"):
    """
    This function takes in the 3 maf dataframes and merges them together based on the inputted how argument. 
    It then performs a set difference between the joined blood and tissue mafs and the germline maf. 
    The result is returned as a dataframe. 

    cf: liquid biopsy maf dataframe 
    st: tissue maf dataframe 
    bc: germline maf dataframe 
    method: how to merge the dataframes. inner is default. 
    """
    
    # columns to identify a mutation 
    mut_cols = ['Hugo_Symbol',"Entrez_Gene_Id","NCBI_Build","Chromosome","Start_Position","End_Position","Reference_Allele","Allele"]

    if method == "inner":
        # merge cf and st on mutation columns. inner join (set intersection)
        common = cf.merge(st, on = mut_cols, how = "inner", suffixes = ("_cf","_st"))
    
        # merge common with bc on mutation columns
        outer = common.merge(bc, on = mut_cols,indicator = True, how = "outer")
    elif method == "outer":
        # merge cf and st on mutation columns. outer join (set union)
        common = cf.merge(st, on = mut_cols, how = "outer", suffixes = ("_cf","_st"))
    
        # merge common with bc on mutation columns
        outer = common.merge(bc, on = mut_cols,indicator = True, how = "outer")
    else: 
        raise ValueError("Invalid method argument. Please use 'inner' or 'outer'.")
    
    # get rid of all mutations that are in the germline (bc)
    anti_join = outer[(outer._merge=="left_only")].drop("_merge", axis = 1)

    # reset index 
    anti_join = anti_join.reset_index(drop=True)

    # return relevant columns for bootstrapping 
    return anti_join[['Hugo_Symbol',"Entrez_Gene_Id","NCBI_Build","Chromosome","Start_Position","End_Position","Reference_Allele","Allele",
                      "Variant_Frequencies_st","Variant_Frequencies_cf", "Total_Depth_st", "Total_Depth_cf"]]

def main():
    # parse arguments 
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--cf_maf", type=str, required=True)
    parser.add_argument("-s", "--st_maf", type=str, required=True)
    parser.add_argument("-b", "--bc_maf", type=str, required=True)
    parser.add_argument("-o", "--output_dir", type=str, required=True)
    parser.add_argument("-m", "--method", type=str, default="inner", 
                       choices=["inner", "outer"])
    args = parser.parse_args()

    # read in mafs 
    cf = pd.read_csv(args.cf_maf, sep="\t")
    st = pd.read_csv(args.st_maf, sep="\t")
    bc = pd.read_csv(args.bc_maf, sep="\t")

    # merge mafs 
    maf_agg = merge_mafs(cf, st, bc, method=args.method)

    # save to csv 
    maf_agg.to_csv(args.output_dir, index=False)

if __name__ == "__main__":
    main()