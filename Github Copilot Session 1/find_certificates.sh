#!/bin/bash

# Script to find certificate locations on RHEL Linux servers,
# extract certificate details, and display them in a tabular format.

# Function to extract certificate details
extract_cert_details() {
    local cert_file="$1"
    local format="$2"

    # Determine openssl command based on format
    case "$format" in
        "PEM")
            openssl_cmd="openssl x509 -in \"$cert_file\" -text -noout"
            ;;
        "DER")
            openssl_cmd="openssl x509 -in \"$cert_file\" -inform der -text -noout"
            ;;
        "PKCS12")
            # Assuming no password for PKCS12; adjust if needed
            openssl_cmd="openssl pkcs12 -in \"$cert_file\" -nokeys -passin pass: -clcerts | openssl x509 -text -noout"
            ;;
        *)
            echo "Unsupported format: $format for $cert_file"
            return 1
            ;;
    esac

    # Extract details
    if cert_info=$(eval "$openssl_cmd" 2>/dev/null); then
        subject=$(echo "$cert_info" | grep "Subject:" | sed 's/Subject: //')
        issuer=$(echo "$cert_info" | grep "Issuer:" | sed 's/Issuer: //')
        valid_from=$(echo "$cert_info" | grep "Not Before:" | sed 's/Not Before: //')
        valid_to=$(echo "$cert_info" | grep "Not After:" | sed 's/Not After: //')
        serial=$(echo "$cert_info" | grep "Serial Number:" | sed 's/Serial Number: //')

        # Print in a format suitable for table
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$cert_file" "$subject" "$issuer" "$valid_from" "$valid_to" "$serial"
    else
        printf "%s\tError extracting details\n" "$cert_file"
    fi
}

# Function to detect certificate format
detect_format() {
    local cert_file="$1"
    if openssl x509 -in "$cert_file" -text -noout >/dev/null 2>&1; then
        echo "PEM"
    elif openssl x509 -in "$cert_file" -inform der -text -noout >/dev/null 2>&1; then
        echo "DER"
    elif openssl pkcs12 -in "$cert_file" -nokeys -passin pass: >/dev/null 2>&1; then
        echo "PKCS12"
    else
        echo "UNKNOWN"
    fi
}

# Main script
echo "Searching for certificate files..."
echo

# Find certificate files (common extensions and locations)
cert_files=$(find /etc/ssl/certs /etc/pki/tls/certs /usr/local/share/ca-certificates /home -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cer" -o -name "*.p12" -o -name "*.pfx" \) 2>/dev/null)

# Print table header
printf "%-50s %-30s %-30s %-20s %-20s %-15s\n" "Path" "Subject" "Issuer" "Valid From" "Valid To" "Serial"
printf "%-50s %-30s %-30s %-20s %-20s %-15s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..15})"

# Process each certificate file
for cert_file in $cert_files; do
    format=$(detect_format "$cert_file")
    if [ "$format" != "UNKNOWN" ]; then
        extract_cert_details "$cert_file" "$format"
    fi
done

echo
echo "Certificate search completed."
