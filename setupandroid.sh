#!/data/data/com.termux/files/usr/bin/sh

# Install needed packages
pkg update -y
pkg install -y curl jq

# Ask if you would like to add an API key
echo -n "Would you like to add a new API key? (y or n, default=n): "
read need_api

# If answer is "y", ask for and save the key
if [ "$need_api" = "y" ]; then
  echo -n "Enter your API key: "
  read api_key

  echo "$api_key" > ICSkey.txt
  echo "✅ API key saved to ICSkey.txt"
else
  echo "✅ Using existing API key from ICSkey.txt"
fi

# Give run permissions
chmod +x HAHSICS/ICS

# Move script to bin for global access
mv HAHSICS/ICS $PREFIX/bin/ICS

# Move key to same location
mv ICSkey.txt $PREFIX/bin

# Add welcome message to shell startup
if ! grep -q "Welcome to Termux!" ~/.bashrc; then
  echo 'echo "Welcome to Termux! To open the client, please type ICS"' >> ~/.bashrc
fi

# Clear the screen
clear

# Success message
echo "✅ Successfully installed ICS client!"

# Clean up
rm -rf HAHSICS
