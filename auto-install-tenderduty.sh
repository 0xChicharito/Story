#!/bin/bash

# Hàm yêu cầu người dùng nhập thông tin
prompt() {
    read -p "$1: " input
    echo "$input"
}

# Step 1: Update and Upgrade
echo "Updating and upgrading system..."
sudo apt update && sudo apt upgrade -y

# Step 2: Create User for Tenderduty
echo "Creating user for Tenderduty..."
USERNAME=$(prompt "Enter the username for tenderduty (default: tenderduty)")
USERNAME=${USERNAME:-tenderduty}
sudo adduser $USERNAME
sudo adduser $USERNAME sudo
sudo su - $USERNAME << EOF

# Step 3: Install Go
echo "Installing Go..."
ver="1.22.4"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version

# Step 4: Download and Install Tenderduty Binary
echo "Cloning Tenderduty from GitHub..."
git clone https://github.com/blockpane/tenderduty
cd tenderduty
go install

# Step 5: Configure Tenderduty
echo "Creating configuration directory and files..."
mkdir -p chains.d
CHAIN_NAME=$(prompt "Enter the chain name (e.g., planq)")
CHAIN_ID=$(prompt "Enter Chain ID")
VALOPER_ADDRESS=$(prompt "Enter your valoper address")
TELEGRAM_ENABLED=$(prompt "Enable Telegram alerts? (yes/no)")
if [[ "$TELEGRAM_ENABLED" == "yes" ]]; then
    TELEGRAM_API_KEY=$(prompt "Enter Telegram API key")
    TELEGRAM_CHANNEL=$(prompt "Enter Telegram Channel ID")
fi
RPC_URL1=$(prompt "Enter the first RPC URL")
RPC_URL2=$(prompt "Enter the second RPC URL (optional)")

# Step 6: Create Chain Configuration
echo "Creating chain configuration..."
tee ./chains.d/${CHAIN_NAME}.yml > /dev/null << EOF1
    chain_id: ${CHAIN_ID}
    valoper_address: ${VALOPER_ADDRESS}
    public_fallback: no

    alerts:
      stalled_enabled: yes
      stalled_minutes: 10
      consecutive_enabled: yes
      consecutive_missed: 5
      consecutive_priority: critical
      percentage_enabled: no
      percentage_missed: 10
      percentage_priority: warning
      alert_if_inactive: yes
      alert_if_no_servers: yes

      telegram:
        enabled: ${TELEGRAM_ENABLED}
        api_key: "${TELEGRAM_API_KEY}"
        channel: "${TELEGRAM_CHANNEL}"

    nodes:
      - url: ${RPC_URL1}
        alert_if_down: yes
      - url: ${RPC_URL2}
        alert_if_down: no
EOF1

# Step 7: Create and Configure systemd Service for Tenderduty
echo "Creating systemd service for Tenderduty..."
sudo tee /etc/systemd/system/tenderduty.service > /dev/null << EOF2
[Unit]
Description=Tenderduty Service
After=network-online.target

[Service]
User=$USERNAME
ExecStart=\$(which tenderduty) run start
WorkingDirectory=\$HOME/tenderduty
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
Type=simple
TimeoutSec=180

[Install]
WantedBy=multi-user.target
EOF2

EOF

# Step 8: Reload systemd, Enable, and Start Tenderduty Service
echo "Reloading systemd, enabling, and starting Tenderduty service..."
sudo systemctl daemon-reload
sudo systemctl enable tenderduty
sudo systemctl start tenderduty

# Step 9: Check Service Status
echo "Checking Tenderduty service status..."
sudo systemctl status tenderduty --no-pager -l

# Step 10: Check Logs for Tenderduty
echo "Checking logs for Tenderduty..."
sudo journalctl -u tenderduty -f -o cat

echo "Tenderduty installation and setup complete!"
