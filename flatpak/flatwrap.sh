#!/usr/bin/env bash



#  WIP


# Run flatpak install interactively and capture output
output=$(flatpak install --user Browse 2>&1 | tee /dev/tty)

# Check if the installation was successful
if [ $? -eq 0 ]; then
    # Extract the installed package name
    package_name=$(echo "$output" | grep "Installing" | awk '{print $2}')
    
    if [ -n "$package_name" ]; then
        # Write the package name to a file
        echo "$package_name" >> installed_packages.txt
        echo "Package $package_name installed and added to installed_packages.txt"
    else
        echo "Package name not found in output. Check installed_packages.txt manually."
    fi
else
    echo "Installation failed or was cancelled"
fi
