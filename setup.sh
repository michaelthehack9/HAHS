#!/bin/sh

# Install needed packages
apk add curl jq

# Prompt for API key
echo -n "Enter your API key: "
read api_key

# Save the key to a file
echo "$api_key" > key.txt

mv HAHSICS/audit.sh audit.sh
mv HAHSICS/snipeit.sh snipeit.sh

rm -rf HAHSICS
