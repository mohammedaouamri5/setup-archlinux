#!/bin/zsh

echo "Do you want to continue? (y/N)"
read response

if [[ "$response" == "y" ]]; then
    echo "You chose to continue."
    # Place your code for continuing here
else
    echo "You chose not to continue."
    # Place your code for not continuing here
fi
