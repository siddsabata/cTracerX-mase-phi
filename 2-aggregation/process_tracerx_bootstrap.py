import pandas as pd
import pickle
import json
import numpy as np
import argparse
from pathlib import Path
from visualize import *
from analyze import *
from optimize import *
import os

def process_bootstrap_data(
    patient: str,
    bootstrap_list: list[int],
    num_blood: int = 0,
    num_tissue: int = 5,
    type: str = 'common',
    method: str = 'phylowgs',
    num_chain: int = 5,
    base_dir: Path = Path('data')
) -> None:
    """
    Process bootstrap data for a given patient.
    
    Args:
        patient (str): Patient ID
        bootstrap_list (list[int]): List of bootstrap numbers to process
        num_blood (int): Number of blood samples
        num_tissue (int): Number of tissue samples
        type (str): Analysis type ('common' or other)
        method (str): Method used ('phylowgs' or other)
        num_chain (int): Number of chains
        base_dir (Path): Base directory for data
    """
    # Setup paths
    patient_dir = Path(base_dir) / str(patient)
    analysis_dir = patient_dir / 'common'
    aggregation_dir = analysis_dir / 'aggregation'
    
    # Add debug output at the start
    print(f"\nProcessing patient directory: {patient_dir}")
    print(f"Looking for {len(bootstrap_list)} bootstrap directories")
    
    for i in bootstrap_list:
        bootstrap_dir = analysis_dir / f'bootstrap{i}'
        print(f"\nChecking bootstrap directory: {bootstrap_dir}")
        if bootstrap_dir.exists():
            print(f"Found files in {bootstrap_dir}:")
            print("\n".join(os.listdir(bootstrap_dir)))
        else:
            print(f"Directory not found: {bootstrap_dir}")
    
    # Create aggregation directory if it doesn't exist
    aggregation_dir.mkdir(exist_ok=True)
    
    # Read mutation data from CSV
    csv_file = patient_dir / 'common' / f"patient_{patient}.csv"
    print(f"Looking for CSV file at: {csv_file}")
    df = pd.read_csv(csv_file)
    
    # Create gene mappings
    gene2idx = {'s' + str(i): i for i in range(len(df))}
    idx2gene = {i: 's' + str(i) for i in range(len(df))}
    
    # Initialize storage dictionaries
    tree_distribution = {
        'cp_tree': [], 'node_dict': [], 'node_dict_name': [], 
        'node_dict_re': [], 'tree_structure': [], 'freq': [], 
        'clonal_freq': [], 'vaf_frac': []
    }
    tree_aggregation = {
        'cp_tree': [], 'node_dict': [], 'node_dict_name': [], 
        'node_dict_re': [], 'tree_structure': [], 'freq': [], 
        'clonal_freq': [], 'vaf_frac': []
    }
    
    # Process each bootstrap from the list
    processed_bootstraps = 0
    for bootstrap_idx in bootstrap_list:
        print(f"\nProcessing bootstrap {bootstrap_idx}")
        
        # Setup file paths for this bootstrap
        bootstrap_dir = analysis_dir / f"bootstrap{bootstrap_idx}"
        summ_file = bootstrap_dir / "result.summ.json.gz"
        muts_file = bootstrap_dir / "result.muts.json.gz"
        mutass_file = bootstrap_dir / "result.mutass.zip"
        
        # Check if all required files exist
        required_files = [summ_file, muts_file, mutass_file]
        missing_files = [f for f in required_files if not f.exists()]
        if missing_files:
            print(f"Skipping bootstrap {bootstrap_idx} - missing files:")
            for f in missing_files:
                print(f"  - {f}")
            continue
        
        processed_bootstraps += 1
        # Process PhyloWGS output
        tree_structure, node_dict, node_dict_name, node_dict_re, final_tree_cp, prev_mat, clonal_freq, vaf_frac = process_phylowgs_output(
            summ_file, muts_file, mutass_file
        )
        
        # Combine trees
        tree_distribution = combine_tree(
            node_dict, node_dict_name, node_dict_re, tree_structure, 
            final_tree_cp, clonal_freq, vaf_frac, method, tree_distribution
        )
        
        # Update aggregation
        tree_aggregation['tree_structure'].append(tree_structure)
        tree_aggregation['cp_tree'].append(final_tree_cp)
        tree_aggregation['node_dict'].append(node_dict)
        tree_aggregation['node_dict_re'].append(node_dict_re)
        tree_aggregation['node_dict_name'].append(node_dict_name)
        tree_aggregation['freq'].append(1)
        tree_aggregation['clonal_freq'].append(clonal_freq)
        tree_aggregation['vaf_frac'].append(vaf_frac)
    
    print(f"\nSuccessfully processed {processed_bootstraps} out of {len(bootstrap_list)} bootstraps")
    
    # Analyze and save results to aggregation directory
    analyze_tree_distribution(tree_distribution, aggregation_dir, patient, type, fig=True)
    
    # Check if we have any valid bootstraps
    if not tree_distribution or len(tree_distribution.get('freq', [])) == 0:
        print(f"No valid bootstrap data found for patient in {patient_dir}")
        print("This could be because:")
        print("1. PhyloWGS did not generate output files")
        print("2. No mutations passed the filtering criteria")
        print("3. The bootstrap files are in unexpected locations")
        return 1

    best_bootstrap_idx = np.argmax(tree_distribution['freq'])
    results_dict = {
        'node_dict_name': tree_distribution['node_dict'][best_bootstrap_idx],
        'tree_structure': tree_distribution['tree_structure'][best_bootstrap_idx]
    }
    
    with open(aggregation_dir / f"{patient}_results_bootstrap_{type}_best.json", 'w') as f:
        json.dump(results_dict, f)
    
    # Save distribution and aggregation results
    with open(aggregation_dir / f'{method}_bootstrap_summary.pkl', 'wb') as g:
        pickle.dump(tree_distribution, g)
    
    with open(aggregation_dir / f'{method}_bootstrap_aggregation.pkl', 'wb') as g:
        pickle.dump(tree_aggregation, g)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Process bootstrap data for phylogenetic analysis.')
    
    parser.add_argument('patient', type=str,
                      help='Patient ID')
    
    parser.add_argument('--bootstrap-list', type=int, nargs='+',
                      help='List of bootstrap numbers to process')
    
    parser.add_argument('--num-blood', type=int, default=0,
                      help='Number of blood samples (default: 0)')
    
    parser.add_argument('--num-tissue', type=int, default=5,
                      help='Number of tissue samples (default: 5)')
    
    parser.add_argument('--type', type=str, default='common',
                      help='Analysis type (default: common)')
    
    parser.add_argument('--method', type=str, default='phylowgs',
                      help='Method used (default: phylowgs)')
    
    parser.add_argument('--num-chain', type=int, default=5,
                      help='Number of chains (default: 5)')
    
    parser.add_argument('--base-dir', type=str, default='data',
                      help='Base directory for data (default: data)')
    
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    
    # Convert base_dir string to Path
    base_dir = Path(args.base_dir)
    
    # Run the processing function with command line arguments
    process_bootstrap_data(
        patient=args.patient,
        bootstrap_list=args.bootstrap_list,
        num_blood=args.num_blood,
        num_tissue=args.num_tissue,
        type=args.type,
        method=args.method,
        num_chain=args.num_chain,
        base_dir=base_dir
    )

"""
to run: 
python process_tracerx_bootstrap.py 256 \
    --bootstrap-list 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 \
    --num-blood 0 \
    --num-tissue 5 \
    --type common \
    --method phylowgs \
    --num-chain 5 \
    --base-dir /path/to/data
"""