#!/bin/bash

# Advanced HackTheBox Enumeration Script for Kali Linux

# Check if target IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET_IP=$1
OUTPUT_DIR="htb_enum_$(date +%Y%m%d_%H%M%S)"
THREADS=8  # Adjust based on your system's capabilities

mkdir -p "$OUTPUT_DIR"

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
run_and_save "nmap -sC -sV -p- --min-rate=1000 -oA $OUTPUT_DIR/nmap_full $TARGET_IP" "nmap_full.nmap"

# Vulnerability scan using nmap scripts
run_and_save "nmap -sV --script vuln $TARGET_IP -oA $OUTPUT_DIR/nmap_vuln" "nmap_vuln.nmap"

# Directory enumeration with gobuster
GOBUSTER_WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
run_and_save "gobuster dir -u http://$TARGET_IP -w $GOBUSTER_WORDLIST -t $THREADS -o $OUTPUT_DIR/gobuster_dir.txt" "gobuster_dir.txt"

# Web vulnerability scanning with nikto
run_and_save "nikto -h http://$TARGET_IP -output $OUTPUT_DIR/nikto_scan.txt" "nikto_scan.txt"

# SSL/TLS analysis with sslscan
run_and_save "sslscan $TARGET_IP" "sslscan_results.txt"

# DNS enumeration with dnsrecon
run_and_save "dnsrecon -d $TARGET_IP -t std,brt -D /usr/share/wordlists/dnsmap.txt" "dnsrecon_results.txt"

# Web application fuzzing with wfuzz
WFUZZ_WORDLIST="/usr/share/wfuzz/wordlist/general/common.txt"
run_and_save "wfuzz -c -z file,$WFUZZ_WORDLIST --hc 404 http://$TARGET_IP/FUZZ" "wfuzz_results.txt"

# SMB enumeration with enum4linux
run_and_save "enum4linux $TARGET_IP" "enum4linux_results.txt"

# SNMP enumeration with snmp-check
run_and_save "snmp-check $TARGET_IP" "snmp_check_results.txt"

# Web application vulnerability scanning with whatweb
run_and_save "whatweb $TARGET_IP -v" "whatweb_results.txt"

# CMS detection with CMSmap
run_and_save "cmsmap http://$TARGET_IP" "cmsmap_results.txt"

# Subdomain enumeration with Sublist3r
run_and_save "sublist3r -d $TARGET_IP -o $OUTPUT_DIR/sublist3r_results.txt" "sublist3r_results.txt"

# JavaScript analysis with LinkFinder (if web application is detected)
run_and_save "python3 /usr/share/linkfinder/linkfinder.py -i http://$TARGET_IP -d" "linkfinder_results.txt"

# Check for vulnerable services using searchsploit
open_ports=$(grep "open" "$OUTPUT_DIR/nmap_full.nmap" | awk -F'/' '{print $1}' | tr '\n' ',')
run_and_save "searchsploit --nmap $OUTPUT_DIR/nmap_full.xml" "searchsploit_results.txt"

echo "Advanced enumeration complete. Results are saved in the $OUTPUT_DIR directory."
echo "Remember to manually review the results and perform targeted testing based on the findings."
