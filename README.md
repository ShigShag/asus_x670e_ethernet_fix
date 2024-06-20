# ROG STRIX X670E GAMING WIFI - Linux Ethernet Fix

**Linux** users may experience **random ethernet outages** on the **Asus ROG STRIX X670E GAMING WIFI** platform. Currently they are no reliable methods to prevent this in the first place. This repository aims to provide a quick fix when these outages occur, by checking every *x* seconds to see if an outage has occurred and then fixing it.

For more info about this topic consult the following thread:

* [ Network card (Intel Ethernet Controller I225-V, igc) keeps dropping after 1 hour on linux - solved with kernel param ](https://www.reddit.com/r/buildapc/comments/xypn1m/network_card_intel_ethernet_controller_i225v_igc/)

The solution in this repo was tested successfully in **Arch Linux**.

## Steps to resolve outages

In order to reenable ethernet we can use two commands:

```bash
echo 1 >/sys/bus/pci/devices/${pci_address}/remove
echo 1 >/sys/bus/pci/rescan
```

To automate we can create a timed service which runs every *x* seconds. For that we need to create three files:

### check_ethernet.timer

```bash
sudo vim /etc/systemd/system/check_ethernet.timer
```

```bash
[Unit]
Description=Runs Ethernet check every 2 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=2s
AccuracySec=1us
Unit=check_ethernet.service

[Install]
WantedBy=timers.target
```

### check_ethernet.service

```bash
sudo vim /etc/systemd/system/check_ethernet.service
```

```bash
[Unit]
Description=Check for Ethernet PCIe Link Failure
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check_and_reset_ethernet.sh

[Install]
WantedBy=multi-user.target
```

### check_and_reset_ethernet.sh

```bash
sudo vim /usr/local/bin/check_and_reset_ethernet.sh
```

```bash
#!/bin/bash

# Log and timestamp files
LOG_FILE="/var/log/reset_ethernet.log"

# Function to perform PCI reset
function pci_reset {
	local pci_address=$(lspci -D | grep "Ethernet Controller I225-V (rev 03)" | awk '{print $1}')
	if [ -n "$pci_address" ]; then
		echo "$(date): Resetting Ethernet Controller at $pci_address" | tee -a "$LOG_FILE"
		echo 1 >/sys/bus/pci/devices/${pci_address}/remove
		echo 1 >/sys/bus/pci/rescan
		echo "$(date): PCI reset performed and timestamp updated." | tee -a "$LOG_FILE"
	else
		echo "$(date): Ethernet controller not found." | tee -a "$LOG_FILE"
	fi
}

# Get system uptime in seconds
system_uptime=$(awk '{print int($1)}' /proc/uptime)

# Get the latest dmesg timestamp for the specific error
latest_error_timestamp=$(dmesg | grep "igc.*eno1: PCIe link lost, device now detached" | tail -1 | awk -F'[][ :]+*' '{split($2,a,"."); print a[1]}')

# Convert latest_error_timestamp to integer seconds
latest_error_seconds=$(echo $latest_error_timestamp | awk -F'.' '{print $1}')

# Check if there has been a disconnect
if [[ -z "$latest_error_timestamp" ]]; then
	exit 0
fi

# Compare the latest error timestamp with current uptime to see if it occurred at least 3 seconds ago
if ((system_uptime - latest_error_seconds <= 3)); then
	pci_reset
else
	exit 0
fi
```

### Update services

To enable this service on startup run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now check_ethernet.timer
```

To consult log file run:

```bash
cat /var/log/reset_ethernet.log
```