#!/usr/bin/env bash



#  WIP

# Use 'script' to simulate a terminal
script -qec "flatpak install --user org.gnome.Epiphany" /dev/null

# Check if the installation was successful
if [ $? -eq 0 ]; then

    package_name=$(echo "$output" | grep " permissions:" | awk '{print $2}')
    


    echo "org.gnome.Epiphany" >> installed_packages.txt
    echo "Package org.gnome.Epiphany installed and added to installed_packages.txt"
else
    echo "Installation failed or was cancelled"
fi