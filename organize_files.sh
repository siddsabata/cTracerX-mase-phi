#!/bin/bash

# Iterate over all subdirectories in the current directory
for dir in */; do
    # Check if it is a directory
    if [ -d "$dir" ]; then
        # Create a "mafs" directory inside the subdirectory
        mkdir -p "${dir}mafs"
        # Move all files from the subdirectory to the "mafs" directory
        mv "${dir}"!("mafs") "${dir}mafs"
    fi
done

