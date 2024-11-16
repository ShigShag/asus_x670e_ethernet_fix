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
latest_error_timestamp=$(dmesg | grep "igc.*: PCIe link lost, device now detached" | tail -1 | awk -F'[][ :]+*' '{split($2,a,"."); print a[1]}')

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
