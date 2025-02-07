#!/usr/bin/env python

import os
import sys
import subprocess
import logging

def check_input_file(patient_id):
    """Check if input SSM file exists and has content"""
    ssm_file = f"/data/{patient_id}/common/ssm_data_original.txt"
    
    print(f"Checking input file: {ssm_file}")
    
    if not os.path.exists(ssm_file):
        print(f"ERROR: Input file not found: {ssm_file}")
        sys.exit(1)
        
    # Check if file has content (more than just header)
    with open(ssm_file, 'r') as f:
        lines = f.readlines()
        if len(lines) <= 1:  # Only header or empty
            print(f"ERROR: No mutations found in {ssm_file}")
            print("File contents:")
            print(''.join(lines))
            sys.exit(1)
            
    print(f"Found {len(lines)-1} mutations in input file")
    print("First few lines:")
    print(''.join(lines[:5]))

def main():
    if len(sys.argv) != 4:
        print("Usage: run_phylowgs.py <patient_id> <num_chains> <num_bootstraps>")
        sys.exit(1)

    patient_id = sys.argv[1]
    num_chains = int(sys.argv[2])
    num_bootstraps = int(sys.argv[3])

    # Check input file first
    check_input_file(patient_id)

    # Rest of the phylowgs code... 