#!/bin/bash

# Improved HackTheBox Enumeration Script for Kali Linux

# Check if target IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET_IP=$1
OUTPUT_DIR="htb_enum_$(date +%Y%m%d_%H%M%S)"
THREADS=8

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

# Directory enumeration with gobuster (adjusted for 302 responses)
GOBUSTER_WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
run_and_save "gobuster dir -u http://$TARGET_IP -w $GOBUSTER_WORDLIST -t $THREADS -s '200,204,301,302,307,403,500' -o $OUTPUT_DIR/gobuster_dir.txt" "gobuster_dir.txt"

# Web vulnerability scanning with nikto
run_and_save "nikto -h http://$TARGET_IP -output $OUTPUT_DIR/nikto_scan.txt" "nikto_scan.txt"

# Extract potential hostnames from nikto results
POTENTIAL_HOSTNAME=$(grep "Root page / redirects to:" "$OUTPUT_DIR/nikto_scan.txt" | awk '{print $NF}' | sed 's/http:\/\///' | sed 's/\/.*//')
if [ ! -z "$POTENTIAL_HOSTNAME" ]; then
    echo "Potential hostname found: $POTENTIAL_HOSTNAME"
    echo "Consider adding '$TARGET_IP $POTENTIAL_HOSTNAME' to your /etc/hosts file"
fi

# SSL/TLS analysis with sslscan (if HTTPS is available)
if nmap -p 443 --open "$TARGET_IP" | grep -q "open"; then
    run_and_save "sslscan $TARGET_IP" "sslscan_results.txt"
fi

# Web application fuzzing with wfuzz
WFUZZ_WORDLIST="/usr/share/wfuzz/wordlist/general/common.txt"
run_and_save "wfuzz -c -z file,$WFUZZ_WORDLIST --hc 404 http://$TARGET_IP/FUZZ" "wfuzz_results.txt"

# SMB enumeration with enum4linux (only if port 445 is open)
if nmap -p 445 --open "$TARGET_IP" | grep -q "open"; then
    run_and_save "enum4linux $TARGET_IP" "enum4linux_results.txt"
fi

# SNMP enumeration with snmp-check (only if port 161 is open)
if nmap -p 161 --open "$TARGET_IP" | grep -q "open"; then
    run_and_save "snmp-check $TARGET_IP" "snmp_check_results.txt"
fi

# Web application vulnerability scanning with whatweb
run_and_save "whatweb $TARGET_IP -v" "whatweb_results.txt"

# Subdomain enumeration with Sublist3r (if a hostname was found)
if [ ! -z "$POTENTIAL_HOSTNAME" ]; then
    run_and_save "sublist3r -d $POTENTIAL_HOSTNAME -o $OUTPUT_DIR/sublist3r_results.txt" "sublist3r_results.txt"
fi

# Check for vulnerable services using searchsploit
open_ports=$(grep "open" "$OUTPUT_DIR/nmap_full.nmap" | awk -F'/' '{print $1}' | tr '\n' ',')
run_and_save "searchsploit --nmap $OUTPUT_DIR/nmap_full.xml" "searchsploit_results.txt"

echo "Enumeration complete. Results are saved in the $OUTPUT_DIR directory."
echo "Remember to manually review the results and perform targeted testing based on the findings."
