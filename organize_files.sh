#!/bin/bash

# Iterate over all subdirectories in the current directory
for dir in */; do
    # Check if it is a directory
    if [ -d "$dir" ]; then
        echo "Processing directory: $dir"
        
        # Create a "mafs" directory inside the subdirectory
        mkdir -p "${dir}mafs"
        
        # Move all files (not directories) from the subdirectory to the "mafs" directory
        find "$dir" -maxdepth 1 -type f -exec mv {} "${dir}mafs/" \;
        
        echo "Moved files to ${dir}mafs/"
    fi
done

