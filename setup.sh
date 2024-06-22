#!/bin/zsh

set -e  # Exit immediately if a command exits with a non-zero status

# Function to check if a file exists and move it if necessary
function check_and_move_f() {
    local from_path="$1"
    local to_path="$2"

    if [ -f "$to_path" ]; then  # Check if the target file already exists
        local to_path_bkp="$to_path.bkp_setup-archlinux"
        echo "Backing up existing file: $to_path to $to_path_bkp"
        mv -fv "$to_path" "$to_path_bkp"  # Move the existing file to a backup
        echo "Copying new file: $from_path to $to_path"
        cp -fv "$from_path" "$to_path"  # Copy the new file to the target location
    else
        echo "Copying new file: $from_path to $to_path"
        cp -fv "$from_path" "$to_path"  # If the target file does not exist, just copy the new file
    fi
}


function check_and_move_d() {
    local from_path="$1"
    local to_path="$2"

    if [ -d "$to_path" ]; then  # Check if the target file already exists
        local to_path_bkp="$to_path.bkp_setup-archlinux"
        echo "Backing up existing file: $to_path to $to_path_bkp"
        mv -fv "$to_path" "$to_path_bkp"  # Move the existing file to a backup
        echo "Copying new file: $from_path to $to_path"
        cp -rfv "$from_path" "$to_path"  # Copy the new file to the target location
    else
        echo "Copying new file: $from_path to $to_path"
        cp -rfv "$from_path" "$to_path"  # If the target file does not exist, just copy the new file
    fi
}




# Example usage of the function
check_and_move_f "./starship.toml" "$HOME/.config/starship.toml"
check_and_move_f "./.zshrc" "$HOME/.zshrc"
check_and_move_d "./.config/hypr" "$HOME/.config/hypr"





# Source the updated .zshrc file
source "$HOME/.zshrc"
