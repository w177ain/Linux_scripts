#!/bin/bash

# Optimized HackTheBox Enumeration Script for Kali Linux

# Check if target IP is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET_IP=$1
OUTPUT_DIR="htb_enum_$(date +%Y%m%d_%H%M%S)"
THREADS=8  # Adjusted based on your 2 CPU cores

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
run_and_save "nmap -sC -sV -oA $OUTPUT_DIR/nmap_initial $TARGET_IP" "nmap_initial.nmap"

# Faster Nmap for all ports
run_and_save "nmap -p- --min-rate=1000 -T4 $TARGET_IP -oA $OUTPUT_DIR/nmap_all_ports" "nmap_all_ports.nmap"

# Gobuster directory scan
GOBUSTER_WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
run_and_save "gobuster dir -u http://$TARGET_IP -w $GOBUSTER_WORDLIST -t $THREADS -o $OUTPUT_DIR/gobuster_dir.txt" "gobuster_dir.txt"

# Nikto scan
run_and_save "nikto -h http://$TARGET_IP -output $OUTPUT_DIR/nikto_scan.txt" "nikto_scan.txt"

# Ffuf vhost discovery
FFUF_WORDLIST="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
run_and_save "ffuf -w $FFUF_WORDLIST -u http://$TARGET_IP -H 'Host: FUZZ.$TARGET_IP' -fc 404 -o $OUTPUT_DIR/ffuf_vhost.json" "ffuf_vhost.json"

# DNS enumeration with dnsrecon
run_and_save "dnsrecon -d $TARGET_IP -t std,brt -D /usr/share/wordlists/dnsmap.txt" "dnsrecon_results.txt"

# Wfuzz for API endpoint discovery
WFUZZ_WORDLIST="/usr/share/wfuzz/wordlist/general/common.txt"
run_and_save "wfuzz -c -z file,$WFUZZ_WORDLIST --hc 404 http://$TARGET_IP/FUZZ" "wfuzz_api_endpoints.txt"

# Hydra SSH brute force (use with caution)
HYDRA_WORDLIST="/usr/share/wordlists/rockyou.txt.gz"
run_and_save "hydra -l root -P $HYDRA_WORDLIST $TARGET_IP ssh -t $THREADS" "hydra_ssh_brute.txt"

# SQLMap basic scan (if a potential SQL injection point is found)
echo "If you find a potential SQL injection point, run:"
echo "sqlmap -u 'http://$TARGET_IP/vulnerable_page.php?id=1' --batch --random-agent"

# Check for vulnerable services using nmap scripts
run_and_save "nmap -sV -p- --script vuln $TARGET_IP" "nmap_vuln_scan.nmap"

echo "Enumeration complete. Results are saved in the $OUTPUT_DIR directory."
