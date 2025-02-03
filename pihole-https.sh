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

# Copy the certificate to the web server directory
WEB_DIR="/var/www/html"
CERT_FILE="/etc/ssl/mycerts/$HOSTNAME.crt"

if [ -d "$WEB_DIR" ]; then
    sudo cp "$CERT_FILE" "$WEB_DIR/"
    sudo chmod 644 "$WEB_DIR/$HOSTNAME.crt"
    echo -e "\033[32mCertificate copied to $WEB_DIR and is accessible via URL.\033[0m"

    # Display the clickable URL for the certificate
    if command -v hostname -I &>/dev/null; then
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        CERT_URL="http://$IP_ADDRESS/$HOSTNAME.crt"
        echo -e "\033[34mClick the following link to download the certificate:\033[0m"
        echo -e "\033[4;32m$CERT_URL\033[0m"
    else
        echo -e "\033[33mUnable to determine the IP address. The certificate should be accessible from:\033[0m"
        echo -e "\033[4;32mhttp://<your-server-ip>/$HOSTNAME.crt\033[0m"
    fi
else
    echo -e "\033[31mError: Web directory $WEB_DIR does not exist. The certificate cannot be made available via URL.\033[0m"
    echo -e "\033[34mCertificate available in text, copy and use the following content:\033[0m"
    sudo cat "$CERT_FILE"
fi

echo -e "\033[34mInstall this certificate on your device as a Trusted Root Certificate Authority (CA).\033[0m"
echo -e "\033[34mSteps:\033[0m"
echo -e "\033[34m1. Download the certificate using the provided URL or copy the content manually to create a .crt file.\033[0m"
echo -e "\033[34m2. Open your device's certificate manager (e.g., Windows, Linux, Android, macOS).\033[0m"
echo -e "\033[34m3. Import the certificate into the 'Trusted Root Certification Authorities' store.\033[0m"
echo -e "\033[34m4. Restart your browser or application to apply the changes.\033[0m"
