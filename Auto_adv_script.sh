#!/bin/bash
set -euo pipefail

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

check_dependencies() {
    for cmd in nmap gobuster nikto sslscan dnsrecon wfuzz enum4linux snmp-check whatweb cmsmap sublist3r searchsploit python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Required tool '$cmd' is not installed." >&2
            exit 1
        fi
    done
}

check_dependencies

# Nmap scan
run_and_save "nmap -sC -sV -p- --min-rate=1000 -oA $OUTPUT_DIR/nmap_full $TARGET_IP" "nmap_full.nmap"

# Extract open ports for conditional tasks
open_ports=$(grep "/tcp" "$OUTPUT_DIR/nmap_full.nmap" | grep open | awk -F"/" '{print $1}' | tr '\n' ',')

# Vulnerability scan using nmap scripts
run_and_save "nmap -sV --script vuln -p ${open_ports%,} $TARGET_IP -oA $OUTPUT_DIR/nmap_vuln" "nmap_vuln.nmap"

# Directory enumeration with gobuster
if echo "$open_ports" | grep -Eq '(^|,)(80|8080|8000)(,|$)'; then
    GOBUSTER_WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
    run_and_save "gobuster dir -u http://$TARGET_IP -w $GOBUSTER_WORDLIST -t $THREADS -o $OUTPUT_DIR/gobuster_dir.txt" "gobuster_dir.txt"
fi

# Web vulnerability scanning with nikto
if echo "$open_ports" | grep -Eq '(^|,)(80|8080|8000)(,|$)'; then
    run_and_save "nikto -h http://$TARGET_IP -output $OUTPUT_DIR/nikto_scan.txt" "nikto_scan.txt"
fi

# SSL/TLS analysis with sslscan
if echo "$open_ports" | grep -q "443"; then
    run_and_save "sslscan $TARGET_IP" "sslscan_results.txt"
fi

# DNS enumeration with dnsrecon
run_and_save "dnsrecon -d $TARGET_IP -t std,brt -D /usr/share/wordlists/dnsmap.txt" "dnsrecon_results.txt"

# Web application fuzzing with wfuzz
WFUZZ_WORDLIST="/usr/share/wfuzz/wordlist/general/common.txt"
run_and_save "wfuzz -c -z file,$WFUZZ_WORDLIST --hc 404 http://$TARGET_IP/FUZZ" "wfuzz_results.txt"

# SMB enumeration with enum4linux
if echo "$open_ports" | grep -q "445"; then
    run_and_save "enum4linux $TARGET_IP" "enum4linux_results.txt"
fi

# SNMP enumeration with snmp-check
if echo "$open_ports" | grep -q "161"; then
    run_and_save "snmp-check $TARGET_IP" "snmp_check_results.txt"
fi

# Web application vulnerability scanning with whatweb
run_and_save "whatweb $TARGET_IP -v" "whatweb_results.txt"

# CMS detection with CMSmap
if echo "$open_ports" | grep -Eq '(^|,)(80|8080|8000|443)(,|$)'; then
    run_and_save "cmsmap http://$TARGET_IP" "cmsmap_results.txt"
fi

# Subdomain enumeration with Sublist3r
if [[ $TARGET_IP =~ [a-zA-Z] ]]; then
    run_and_save "sublist3r -d $TARGET_IP -o $OUTPUT_DIR/sublist3r_results.txt" "sublist3r_results.txt"
fi

# JavaScript analysis with LinkFinder (if web application is detected)
if echo "$open_ports" | grep -Eq '(^|,)(80|8080|8000|443)(,|$)'; then
    run_and_save "python3 /usr/share/linkfinder/linkfinder.py -i http://$TARGET_IP -d" "linkfinder_results.txt"
fi

# Check for vulnerable services using searchsploit
run_and_save "searchsploit --nmap $OUTPUT_DIR/nmap_full.xml" "searchsploit_results.txt"

echo "Advanced enumeration complete. Results are saved in the $OUTPUT_DIR directory."
echo "Remember to manually review the results and perform targeted testing based on the findings."
