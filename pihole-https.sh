#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31mThis script must be run as root. Please use sudo.\033[0m"
  exit 1
fi

echo -e "\033[32mRunning script with admin privileges ✅\033[0m"

# Create the directory to store certificates
#sudo mkdir -p /etc/ssl/mycerts
sudo chmod 640 ./$HOSTNAME.*

# Install the OpenSSL module for Lighttpd
sudo apt install -y lighttpd-mod-openssl
echo -e "\033[32mLighttpd OpenSSL module installed.\033[0m"

# Add SSL and redirect configuration
CONFIG_FILE="/etc/lighttpd/lighttpd.conf"

# Check if the .pem file exists
if [ ! -f "/etc/ssl/mycerts/$HOSTNAME.pem" ]; then
    echo -e "\033[31mError: File /etc/ssl/mycerts/$HOSTNAME.pem does not exist. Cannot configure SSL.\033[0m"
    exit 1
fi

echo "Starting SSL and redirect configuration for Lighttpd..."

# Add mod_openssl module
if ! grep -q '"mod_openssl"' "$CONFIG_FILE"; then
    sudo sed -i '/server.modules = (/a\        "mod_openssl",' "$CONFIG_FILE"
    echo -e "\033[32mAdded 'mod_openssl' to Lighttpd modules.\033[0m"
else
    echo -e "\033[33m'mod_openssl' is already present in Lighttpd modules.\033[0m"
fi

# Add SSL block
if ! grep -q 'ssl.engine = "enable"' "$CONFIG_FILE"; then
    sudo bash -c "cat << 'EOF' >> $CONFIG_FILE

# SSL
\$SERVER[\"socket\"] == \":443\" {
    ssl.engine = \"enable\"
    ssl.pemfile = \"/etc/ssl/mycerts/$HOSTNAME.pem\"
}

# Redirect /admin to HTTPS
\$SERVER[\"socket\"] == \":80\" {
    url.redirect = ( \"^/admin(.*)\" => \"https://$HOSTNAME/admin\$1\" )
}
EOF"
    echo -e "\033[32mSSL and redirect configuration added to Lighttpd.\033[0m"
else
    echo -e "\033[33mSSL configuration is already present in Lighttpd.\033[0m"
fi

# Restart Lighttpd service
sudo systemctl restart lighttpd
if [ $? -eq 0 ]; then
    echo -e "\033[32mLighttpd service restarted successfully.\033[0m"
else
    echo -e "\033[31mFailed to restart Lighttpd service. Please check the configuration.\033[0m"
fi


echo -e "\033[34mConfiguration completed! Certificates are stored in /etc/ssl/mycerts/.\033[0m"
