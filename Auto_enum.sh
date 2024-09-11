#!/bin/bash

# Improved HackTheBox Enumeration Script

# Check if target IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET_IP=$1
OUTPUT_DIR="htb_enum_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run a command and save output
run_and_save() {
    command=$1
    output_file=$2
    echo "Running: $command"
    if eval "$command" > "$OUTPUT_DIR/$output_file" 2>&1; then
        echo "Output saved to $OUTPUT_DIR/$output_file"
    else
        echo "Error running command. Check $OUTPUT_DIR/$output_file for details."
    fi
    echo
}

# Nmap scan
run_and_save "nmap -sC -sV -oN $OUTPUT_DIR/nmap_initial.txt $TARGET_IP" "nmap_initial.txt"

# Faster Nmap for all ports
run_and_save "nmap -p- --min-rate=1000 -T4 $TARGET_IP -oN $OUTPUT_DIR/nmap_all_ports.txt" "nmap_all_ports.txt"

# Gobuster directory scan
if command_exists gobuster; then
    run_and_save "gobuster dir -u http://$TARGET_IP -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -t 50 -o $OUTPUT_DIR/gobuster_dir.txt" "gobuster_dir.txt"
else
    echo "Gobuster is not installed. Skipping directory enumeration."
fi

# Nikto scan
if command_exists nikto; then
    run_and_save "nikto -h http://$TARGET_IP -output $OUTPUT_DIR/nikto_scan.txt" "nikto_scan.txt"
else
    echo "Nikto is not installed. Skipping web server scan."
fi

# Ffuf vhost discovery (if web server is present)
if command_exists ffuf; then
    WORDLIST="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    if [ ! -f "$WORDLIST" ]; then
        echo "Wordlist not found. Using a smaller, common wordlist."
        WORDLIST="/usr/share/wordlists/dirb/common.txt"
    fi
    run_and_save "ffuf -w $WORDLIST -u http://$TARGET_IP -H 'Host: FUZZ.$TARGET_IP' -fc 404 -o $OUTPUT_DIR/ffuf_vhost.txt" "ffuf_vhost.txt"
else
    echo "Ffuf is not installed. Skipping vhost discovery."
fi

echo "Enumeration complete. Results are saved in the $OUTPUT_DIR directory."
