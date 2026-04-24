#!/bin/bash

# Script to gather VM CPU cores, memory details, JVM memory for Java processes,
# and thread settings for Tomcat, Apache, or other Java processes on RHEL Linux servers.
# Displays information in a tabular format.

# Function to get VM details
get_vm_details() {
    cpu_cores=$(nproc)
    total_memory=$(free -h | awk 'NR==2{printf "%.0fGB", $2/1024}')
    used_memory=$(free -h | awk 'NR==2{printf "%.0fGB", $3/1024}')
    free_memory=$(free -h | awk 'NR==2{printf "%.0fGB", $4/1024}')

    printf "VM Details\tCPU Cores: %s\tTotal Memory: %s\tUsed Memory: %s\tFree Memory: %s\n" "$cpu_cores" "$total_memory" "$used_memory" "$free_memory"
}

# Function to get JVM memory details
get_jvm_memory() {
    local pid="$1"
    if jstat -gc "$pid" 2>/dev/null | head -n 2 >/dev/null; then
        jvm_mem=$(jstat -gc "$pid" | tail -n 1 | awk '{printf "Heap Used: %.0fMB, Heap Max: %.0fMB", ($3+$4+$6+$8)/1024, ($5+$7)/1024}')
        echo "$jvm_mem"
    else
        echo "N/A"
    fi
}

# Function to get thread settings
get_thread_settings() {
    local pid="$1"
    local process_name="$2"

    case "$process_name" in
        *tomcat*|*catalina*)
            # For Tomcat, check server.xml for thread settings
            tomcat_home=$(ps -p "$pid" -o cmd= | awk '{for(i=1;i<=NF;i++) if($i ~ /catalina.home/) print $(i+1)}' | head -1)
            if [ -n "$tomcat_home" ]; then
                server_xml="$tomcat_home/conf/server.xml"
                if [ -f "$server_xml" ]; then
                    threads=$(grep -o 'maxThreads="[0-9]*"' "$server_xml" | sed 's/.*="//;s/".*//' | head -1)
                    echo "Tomcat maxThreads: ${threads:-N/A}"
                else
                    echo "Tomcat config not found"
                fi
            else
                echo "Tomcat home not found"
            fi
            ;;
        *apache*|*httpd*)
            # For Apache, check httpd.conf for thread settings
            httpd_conf=$(find /etc/httpd /etc/apache2 -name "httpd.conf" 2>/dev/null | head -1)
            if [ -f "$httpd_conf" ]; then
                threads=$(grep -i "MaxRequestWorkers\|ThreadsPerChild" "$httpd_conf" | head -1 | awk '{print $2}')
                echo "Apache Threads: ${threads:-N/A}"
            else
                echo "Apache config not found"
            fi
            ;;
        *)
            # For other Java processes, get JVM thread info
            thread_count=$(jstack "$pid" 2>/dev/null | grep -c "nid=")
            echo "JVM Threads: ${thread_count:-N/A}"
            ;;
    esac
}

# Main script
echo "Gathering system and JVM details..."
echo

# Get VM details
get_vm_details
echo

# Print table header for Java processes
printf "%-10s %-20s %-30s %-30s %-20s\n" "PID" "Process Name" "JVM Memory" "Thread Settings" "User"
printf "%-10s %-20s %-30s %-30s %-20s\n" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..20})"

# Find Java processes
java_processes=$(ps aux | grep java | grep -v grep | awk '{print $2}')

for pid in $java_processes; do
    process_name=$(ps -p "$pid" -o comm=)
    user=$(ps -p "$pid" -o user=)
    jvm_memory=$(get_jvm_memory "$pid")
    thread_settings=$(get_thread_settings "$pid" "$process_name")

    printf "%-10s %-20s %-30s %-30s %-20s\n" "$pid" "$process_name" "$jvm_memory" "$thread_settings" "$user"
done

echo
echo "Details gathering completed."
