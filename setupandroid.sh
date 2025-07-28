#!/data/data/com.termux/files/usr/bin/sh

# Install needed packages
pkg update -y
pkg install -y curl jq

# Make directory for key
mkdir -p ~/.ics

# Ask if you would like to add an API key
echo -n "Would you like to add a new API key? (y or n, default=n): "
read need_api

# If answer is "y", ask for and save the key
if [ "$need_api" = "y" ]; then
  echo -n "Enter your API key: "
  read api_key

  echo "$api_key" > ~/.ics/ICSkey.txt
  echo "✅ API key saved to ICSkey.txt"
else
  echo "✅ Using existing API key from ICSkey.txt"
fi

# Give run permissions
chmod +x HAHSICS/ICSandroid

# Move script to bin for global access
mv HAHSICS/ICSandroid $PREFIX/bin/ICS

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
