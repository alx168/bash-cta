# installer.bash
#
# Nic Hite
# 09/27/16
#
# A super quick installer that sets up the cta bash script for use.
# Makes the script executable and creates a link in usr/local/bin
# to the script in the git repo--this way, updates will instantly 
# be usable one pulled
#
# Should be run as sudo for chmod


# Make the file executable
echo "Making the script executable..."
sudo chmod +x ./cta.bash || echo "wasn't able to change script execution :("

# Create the link
echo "linking the script to executable directory..."
abspath="$(pwd)/cta.bash"
sudo ln -s $abspath /usr/local/bin/cta || echo "wasn't able to create file link :("

echo "Done!"