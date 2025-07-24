#!/bin/sh

# Install needed packages
apk add curl jq

# Prompt for API key
echo -n "Enter your API key: "
read api_key

# Save the key to a file
echo "$api_key" > key.txt

# Move the main script out
mv HAHSICS/snipeit.sh snipeit.sh

# Give run permissions
chmod +x snipeit.sh

clear

echo "Successfully installed ICS client!"
# Remove junk
rm -rf HAHSICS
