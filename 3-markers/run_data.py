from optimize import *
from optimize_fraction import *
import pandas as pd
from zipfile import ZipFile
import json
import gzip
import pickle
from pathlib import Path
import argparse
import matplotlib.pyplot as plt
import seaborn as sns
import os
import sys

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Run marker selection analysis.')
    
    parser.add_argument('patient', type=str,
                      help='Patient ID')
    
    parser.add_argument('--bootstrap-list', type=int, nargs='+',
                      help='List of bootstrap numbers to process')
    
    parser.add_argument('--read-depth', type=int, default=1500,
                      help='Read depth for analysis (default: 1500)')
    
    return parser.parse_args()

def main():
    args = parse_args()
    patient = args.patient
    bootstrap_list = args.bootstrap_list
    read_depth = args.read_depth

    # Set up paths using DATA_DIR environment variable
    data_dir = os.environ.get('DATA_DIR', '/data')  # fallback to /data if not set
    patient_dir = os.path.join(data_dir, patient)
    common_dir = os.path.join(patient_dir, 'common')
    aggregation_dir = os.path.join(common_dir, 'aggregation')

    # Define file paths
    tree_distribution_file = os.path.join(aggregation_dir, 'phylowgs_bootstrap_aggregation.pkl')
    csv_file = os.path.join(common_dir, f'patient_{patient}.csv')

    # Verify files exist
    if not os.path.exists(tree_distribution_file):
        print(f"Error: Tree distribution file not found at {tree_distribution_file}")
        sys.exit(1)
    if not os.path.exists(csv_file):
        print(f"Error: CSV file not found at {csv_file}")
        sys.exit(1)

    # Read from CSV first to get total number of mutations
    inter_original = pd.read_csv(csv_file)
    
    # Create gene mappings before filtering
    gene2idx = {'s' + str(i): i for i in range(len(inter_original))}
    gene_list = list(gene2idx.keys())

    # Create gene name list for all mutations
    gene_name_list = []
    gene_count = {}

    for i in range(len(inter_original)):
        gene = inter_original.iloc[i]["Hugo_Symbol"]
        ref = inter_original.iloc[i]["Reference_Allele"]
        alt = inter_original.iloc[i]["Allele"]
        
        if pd.isna(gene) or not isinstance(gene, str):
            chrom = str(inter_original.iloc[i]["Chromosome"])
            pos = str(inter_original.iloc[i]["Start_Position"])
            gene = f"Chr{chrom}:{pos}({ref}>{alt})"
        else:
            mutation = f"({ref}>{alt})"
            gene_with_mut = f"{gene}{mutation}"
            if gene_with_mut in gene_name_list:
                gene_count[gene_with_mut] = gene_count.get(gene_with_mut, 1) + 1
                gene = f"{gene_with_mut}_{gene_count[gene_with_mut]}"
            else:
                gene = gene_with_mut
        gene_name_list.append(gene)

    # Now filter the data for visualization
    inter = inter_original.copy()
    inter = inter[inter["Variant_Frequencies_cf"] < 0.9]  # blood
    inter = inter[inter["Variant_Frequencies_st"] < 0.9]  # tissue
    calls = inter

    # Load tree distribution
    with open(tree_distribution_file, 'rb') as f:
        tree_distribution = pickle.load(f)

    tree_list, node_list, clonal_freq_list, tree_freq_list = tree_distribution['tree_structure'], tree_distribution['node_dict'],tree_distribution['vaf_frac'],tree_distribution['freq']

    #scrub node_list
    node_list_scrub = []
    for node_dict in node_list:
        temp = {}
        for key, values in node_dict.items():
            temp.setdefault(int(key), values)
        node_list_scrub.append(temp)

    clonal_freq_list_scrub = []
    for clonal_freq_dict in clonal_freq_list:
        temp = {}
        for key, values in clonal_freq_dict.items():
            temp.setdefault(int(key), values[0])
        clonal_freq_list_scrub.append(temp)

    # Run marker selection with different methods and parameters
    output_dir = os.path.join(patient_dir, 'common', 'markers')
    os.makedirs(output_dir, exist_ok=True)

    # Save marker selection results to a text file
    results_file = os.path.join(output_dir, f'{patient}_marker_selection_results.txt')
    with open(results_file, 'w') as f:
        f.write(f"Marker Selection Results for Patient {patient}\n")
        f.write("=" * 50 + "\n\n")

    # Method 1: Tracing fractions
    selected_markers1_genename_ordered = []
    obj1_ordered = []

    for n_markers in range(1, len(gene_list) + 1):
        selected_markers1, obj = select_markers_fractions_weighted_overall(gene_list, n_markers, tree_list, node_list_scrub, clonal_freq_list_scrub, gene2idx, tree_freq_list)
        selected_markers1_genename = [gene_name_list[int(i[1:])] for i in selected_markers1]
        obj1_ordered.append(obj)
        if len(selected_markers1_genename) == 1:
            selected_markers1_genename_ordered.append(selected_markers1_genename[0])
        else:
            diff_set = set(selected_markers1_genename).difference(set(selected_markers1_genename_ordered))
            selected_markers1_genename_ordered.append(list(diff_set)[0])
    
    # Save Method 1 results
    with open(results_file, 'a') as f:
        f.write("Method 1 (Tracing Fractions) Results:\n")
        f.write("-" * 40 + "\n")
        for i, (marker, obj) in enumerate(zip(selected_markers1_genename_ordered, obj1_ordered), 1):
            # Get the index of this marker in gene_name_list
            marker_idx = gene_name_list.index(marker)
            # Get position info from original unfiltered data
            chrom = str(inter_original.iloc[marker_idx]["Chromosome"])
            pos = str(inter_original.iloc[marker_idx]["Start_Position"])
            f.write(f"{i}. {marker} [Chr{chrom}:{pos}]: {obj}\n")
        f.write("\n")

    position1 = list(range(len(obj1_ordered)))
    plt.figure(figsize=(8, 5))
    plt.plot(position1, obj1_ordered, 'o-', label='tracing-fractions')
    plt.xticks(position1, selected_markers1_genename_ordered, rotation=30)
    plt.legend()
    plt.savefig(os.path.join(output_dir, f'{patient}_tracing_subclones.png'), format='png', dpi=300, bbox_inches='tight')
    plt.close()

    # Method 2: Tree-based selection with different parameters
    for lam1, lam2 in [(1, 0), (0, 1)]:
        selected_markers2_genename_ordered = []
        obj2_ordered = []
        
        for n_markers in range(1, len(gene_list) + 1):
            selected_markers2, obj_frac, obj_struct = select_markers_tree_gp(
                gene_list, n_markers, tree_list, node_list_scrub, clonal_freq_list_scrub, 
                gene2idx, tree_freq_list, read_depth=read_depth, lam1=lam1, lam2=lam2
            )
            selected_markers2_genename = [gene_name_list[int(i[1:])] for i in selected_markers2]
            obj2_ordered.append((obj_frac, obj_struct))
            if len(selected_markers2_genename) == 1:
                selected_markers2_genename_ordered.append(selected_markers2_genename[0])
            else:
                selected_markers2_genename_ordered.append(
                    list(set(selected_markers2_genename).difference(set(selected_markers2_genename_ordered)))[0])

        # Save Method 2 results
        with open(results_file, 'a') as f:
            f.write(f"\nMethod 2 Results (lam1={lam1}, lam2={lam2}):\n")
            f.write("-" * 40 + "\n")
            for i, (marker, (obj_frac, obj_struct)) in enumerate(zip(selected_markers2_genename_ordered, obj2_ordered), 1):
                # Get the index of this marker in gene_name_list
                marker_idx = gene_name_list.index(marker)
                # Get position info from original unfiltered data
                chrom = str(inter_original.iloc[marker_idx]["Chromosome"])
                pos = str(inter_original.iloc[marker_idx]["Start_Position"])
                f.write(f"{i}. {marker} [Chr{chrom}:{pos}]: fraction={obj_frac}, structure={obj_struct}\n")
            f.write("\n")

        obj2_frac_ordered = [obj2_ordered[i][0] for i in range(len(obj2_ordered))]
        obj2_struct_ordered = [obj2_ordered[i][1] for i in range(len(obj2_ordered))]
        position2 = list(range(len(obj2_ordered)))

        # Plot fractions
        plt.figure(figsize=(8, 5))
        plt.plot(position2, obj2_frac_ordered, 'o-', color='tab:orange', label='trees-fractions')
        plt.xticks(position2, selected_markers2_genename_ordered, rotation=30)
        plt.legend()
        plt.savefig(os.path.join(output_dir, f'{patient}_trees_fractions_{lam1}_{lam2}_{read_depth}.png'), format='png', dpi=300, bbox_inches='tight')
        plt.close()

        # Plot structures
        plt.figure(figsize=(8, 5))
        plt.plot(position2, obj2_struct_ordered, 'o-', color='tab:green', label='trees-structure')
        plt.xticks(position2, selected_markers2_genename_ordered, rotation=30)
        plt.legend()
        plt.savefig(os.path.join(output_dir, f'{patient}_trees_structures_{lam1}_{lam2}_{read_depth}.png'), format='png', dpi=300, bbox_inches='tight')
        plt.close()

if __name__ == "__main__":
    main()
