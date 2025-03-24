#!/bin/bash
# --------------------------------------------------
# This script runs PhyloWGS for a single bootstrap iteration
#
# Usage:
#   ./run_phylowgs.sh <timepoint_dir> <bootstrap_num> <num_chains>
#
# Example:
#   ./run_phylowgs.sh /path/to/data/CRUK0044_baseline_2014-11-28 1 5
# --------------------------------------------------

set -e

# Check if required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <timepoint_dir> <bootstrap_num> <num_chains>"
    exit 1
fi

# Extract arguments
timepoint_dir="$1"
bootstrap_num="$2"
num_chains="$3"

echo "---------------------------------------"
echo "Running PhyloWGS for timepoint: $(basename "${timepoint_dir}")"
echo "Bootstrap: ${bootstrap_num}"
echo "Number of chains: ${num_chains}"
echo "---------------------------------------"

# Define directories - we're using the same directory for input and output
bootstrap_dir=$(realpath "${timepoint_dir}/bootstrap${bootstrap_num}")

# Create output directories
mkdir -p "${bootstrap_dir}/chains" "${bootstrap_dir}/.tmp"

# Find SSM and CNV files
ssm_file="${bootstrap_dir}/ssm.txt"
cnv_file="${bootstrap_dir}/cnv.txt"

# Check if SSM file exists
if [ ! -f "${ssm_file}" ]; then
    echo "Error: SSM file not found at ${ssm_file}"
    exit 1
fi

# Create empty CNV file if it doesn't exist
if [ ! -f "${cnv_file}" ]; then
    echo "Creating empty CNV file at ${cnv_file}"
    echo "chr	start	end	major_cn	minor_cn	cellular_prevalence" > "${cnv_file}"
fi

# Get the PhyloWGS installation directory (assuming we're in the cTracerX-mase-phi directory)
phylowgs_dir="$(pwd)/2-phylowgs/phylowgs"
multievolve="${phylowgs_dir}/multievolve.py"
write_results="${phylowgs_dir}/write_results.py"

# Print paths for debugging
echo "Bootstrap directory: ${bootstrap_dir}"
echo "SSM file: ${ssm_file}"
echo "CNV file: ${cnv_file}"

# Run PhyloWGS
echo "Running multievolve.py for bootstrap ${bootstrap_num} from $(pwd)"
cd "${phylowgs_dir}"
python2 "${multievolve}" --num-chains "${num_chains}" \
    --ssms "${ssm_file}" \
    --cnvs "${cnv_file}" \
    --output-dir "${bootstrap_dir}/chains" \
    --tmp-dir "${bootstrap_dir}/.tmp"

# Process results with write_results.py
echo "Running write_results.py for bootstrap ${bootstrap_num}"

# Check multiple potential locations for trees.zip
TREES_ZIP=""
POTENTIAL_LOCATIONS=(
    "${bootstrap_dir}/chains/trees.zip"
    "${bootstrap_dir}/chains/merged/trees.zip"
)

for location in "${POTENTIAL_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        TREES_ZIP="$location"
        echo "Found trees.zip at: $TREES_ZIP"
        break
    fi
done

# If trees.zip is found, process it
if [ -n "$TREES_ZIP" ]; then
    python2 "${write_results}" --include-ssm-names result \
        "$TREES_ZIP" \
        "${bootstrap_dir}/result.summ.json.gz" \
        "${bootstrap_dir}/result.muts.json.gz" \
        "${bootstrap_dir}/result.mutass.zip"
    echo "Results processed successfully"
else
    echo "ERROR: trees.zip not found in any expected location"
    echo "Contents of chains directory:"
    find "${bootstrap_dir}/chains/" -type f | sort
    
    # Check if multievolve.py completed successfully
    echo "Checking for error logs:"
    find "${bootstrap_dir}/.tmp/" -name "*.stderr" -exec cat {} \;
    
    # Try running with explicit chain inclusion factor
    echo "Attempting to manually merge chains..."
    python2 "${multievolve}" --num-chains 0 \
        --ssms "${ssm_file}" \
        --cnvs "${cnv_file}" \
        --output-dir "${bootstrap_dir}/chains" \
        --tmp-dir "${bootstrap_dir}/.tmp" \
        --chain-inclusion-factor inf
        
    # Check again for trees.zip
    if [ -f "${bootstrap_dir}/chains/trees.zip" ] || [ -f "${bootstrap_dir}/chains/merged/trees.zip" ]; then
        echo "Manual chain merging successful, trees.zip created"
        # Re-run the check for trees.zip
        for location in "${POTENTIAL_LOCATIONS[@]}"; do
            if [ -f "$location" ]; then
                TREES_ZIP="$location"
                echo "Found trees.zip at: $TREES_ZIP after manual merge"
                break
            fi
        done
        
        # Process the trees.zip if found
        if [ -n "$TREES_ZIP" ]; then
            python2 "${write_results}" --include-ssm-names result \
                "$TREES_ZIP" \
                "${bootstrap_dir}/result.summ.json.gz" \
                "${bootstrap_dir}/result.muts.json.gz" \
                "${bootstrap_dir}/result.mutass.zip"
            echo "Results processed successfully after manual merge"
        else
            echo "ERROR: trees.zip still not found after manual merge attempt"
            exit 1
        fi
    else
        echo "ERROR: Failed to create trees.zip even after manual merge attempt"
        exit 1
    fi
fi

# Return to original directory
cd - > /dev/null

echo "PhyloWGS analysis completed for bootstrap ${bootstrap_num}" 