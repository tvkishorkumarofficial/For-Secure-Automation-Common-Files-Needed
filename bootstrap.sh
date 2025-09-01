#!/bin/bash

# Bootstrap Script - Secure Automation Loader
# This script handles both ZIP files and direct script files

# Configuration
PAYLOAD_URL="https://raw.githubusercontent.com/kishorkumartv000/amd-bootstrap-for-test/refs/heads/main/payload.sh"  # Can be a ZIP or a script
ZIP_PASSWORD="YourStrongPassword123!"                  # Password for the zip file (if applicable)
TEMP_DIR="/tmp/secure_payload"
WORKING_DIR="/usr/src/app"
LOG_FILE="/var/log/bootstrap.log"
ENABLE_LOGGING=true

# ASCII Art Header
echo "┌─────────────────────────────────────────────────────┐" >&2
echo "│           SECURE AUTOMATION BOOTSTRAP               │" >&2
echo "│           (ZIP and Direct Script Handling)          │" >&2
echo "└─────────────────────────────────────────────────────┘" >&2

# Function to log messages with timestamp and emojis
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Select emoji based on log level
    case "$level" in
        "ERROR") emoji="❌" ;;
        "WARNING") emoji="⚠️ " ;;
        "INFO") emoji="ℹ️ " ;;
        "SUCCESS") emoji="✅" ;;
        *) emoji="🔹" ;;
    esac
    
    # Log to file if enabled
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Display with emoji
    echo "$emoji $message" >&2
}

# Function to display status updates with boxes
show_status() {
    echo "┌─────────────────────────────────────────────────────┐" >&2
    echo "│ $1" >&2
    echo "└─────────────────────────────────────────────────────┘" >&2
}

# Function to cleanup temporary files
cleanup() {
    log_message "INFO" "Cleaning up temporary files"
    rm -rf "$TEMP_DIR" 2>/dev/null
}

# Set trap to ensure cleanup happens on exit
trap cleanup EXIT

# Function to check required tools
check_dependencies() {
    show_status "🔍 Checking System Dependencies"
    local tools=("curl" "unzip" "wget" "file")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
            log_message "WARNING" "$tool is not installed"
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_message "ERROR" "Missing required tools: ${missing[*]}"
        return 1
    fi
    
    log_message "SUCCESS" "All dependencies are available"
    return 0
}

# Function to download the file and return the actual filename
download_file() {
    show_status "📥 Downloading File"
    local url="$1"
    local output_dir="$2"
    
    log_message "INFO" "Downloading from: $url"
    
    # Extract filename from URL or use a default
    local filename=$(basename "$url" | cut -d'?' -f1)
    if [ -z "$filename" ] || [ "$filename" = "/" ]; then
        filename="downloaded_file"
    fi
    
    local output_path="$output_dir/$filename"
    
    # Try using curl first, then wget as fallback
    if command -v curl &> /dev/null; then
        if ! curl -s -L -o "$output_path" "$url"; then
            log_message "ERROR" "curl download failed"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -q -O "$output_path" "$url"; then
            log_message "ERROR" "wget download failed"
            return 1
        fi
    else
        log_message "ERROR" "No download tool available"
        return 1
    fi
    
    # Verify the downloaded file exists and has content
    if [ ! -f "$output_path" ] || [ ! -s "$output_path" ]; then
        log_message "ERROR" "Downloaded file is missing or empty"
        return 1
    fi
    
    log_message "SUCCESS" "File downloaded successfully: $filename"
    echo "$filename"  # Return the actual filename
    return 0
}

# Function to check if a file is a ZIP archive
is_zip_file() {
    local file_path="$1"
    if file "$file_path" | grep -q "Zip archive data"; then
        return 0  # It is a ZIP file
    else
        return 1  # It is not a ZIP file
    fi
}

# Function to decrypt and extract a ZIP payload
extract_zip_payload() {
    show_status "🔓 Decrypting and Extracting ZIP Payload"
    local zip_file="$1"
    local password="$2"
    local extract_dir="$3"
    
    # Create extraction directory
    mkdir -p "$extract_dir"
    
    log_message "INFO" "Extracting $zip_file with password protection"
    
    # Try to extract with password
    if ! unzip -P "$password" -o "$zip_file" -d "$extract_dir" 2>/dev/null; then
        log_message "ERROR" "Failed to extract zip file - incorrect password or corrupt file"
        return 1
    fi
    
    log_message "SUCCESS" "ZIP payload extracted successfully"
    
    # Show what was extracted
    log_message "INFO" "Extracted contents:"
    find "$extract_dir" -type f -exec ls -la {} \; 2>/dev/null | while read line; do
        log_message "INFO" "  $line"
    done
    
    return 0
}

# Function to execute the main payload script
execute_payload() {
    show_status "🚀 Executing Payload"
    local payload_dir="$1"
    
    # Look for the main payload script in all subdirectories
    local payload_script=""
    local possible_names=("main.sh" "payload.sh" "automation.sh" "run.sh" "start.sh")
    
    # Search through all files in the directory
    for script_name in "${possible_names[@]}"; do
        # Use find to search in all subdirectories
        found_script=$(find "$payload_dir" -name "$script_name" -type f | head -n 1)
        if [ -n "$found_script" ]; then
            payload_script="$found_script"
            break
        fi
    done
    
    if [ -z "$payload_script" ]; then
        log_message "ERROR" "No executable script found in payload"
        log_message "INFO" "Available files:"
        find "$payload_dir" -type f -exec ls -la {} \; 2>/dev/null | while read line; do
            log_message "INFO" "  $line"
        done
        return 1
    fi
    
    # Make the script executable
    chmod +x "$payload_script"
    log_message "INFO" "Made script executable: $payload_script"
    
    log_message "INFO" "Executing: $payload_script"
    
    # Change to the directory containing the script
    local script_dir=$(dirname "$payload_script")
    cd "$script_dir" || {
        log_message "ERROR" "Failed to change to script directory: $script_dir"
        return 1
    }
    
    # Execute the payload script
    exec "./$(basename "$payload_script")"
}

# Function to execute a direct script file
execute_direct_script() {
    show_status "🚀 Executing Direct Script"
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        log_message "ERROR" "Script file not found: $script_path"
        return 1
    fi
    
    # Make the script executable
    chmod +x "$script_path"
    log_message "INFO" "Made script executable: $script_path"
    
    log_message "INFO" "Executing: $script_path"
    
    # Execute the script directly
    exec "$script_path"
}

# Main execution flow
main() {
    log_message "INFO" "🚀 Starting Bootstrap Process"
    
    # Step 1: Check dependencies
    if ! check_dependencies; then
        log_message "ERROR" "Dependency check failed"
        exit 1
    fi
    
    # Step 2: Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Step 3: Download the file and get the actual filename
    downloaded_file=$(download_file "$PAYLOAD_URL" "$TEMP_DIR")
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Failed to download file"
        exit 1
    fi
    
    local file_path="$TEMP_DIR/$downloaded_file"
    
    # Step 4: Determine if the file is a ZIP or a direct script
    if is_zip_file "$file_path"; then
        log_message "INFO" "Downloaded file is a ZIP archive"
        
        # Extract the ZIP file
        if ! extract_zip_payload "$file_path" "$ZIP_PASSWORD" "$TEMP_DIR"; then
            log_message "ERROR" "Failed to extract ZIP payload"
            exit 1
        fi
        
        # Execute the payload from the extracted contents
        execute_payload "$TEMP_DIR"
    else
        log_message "INFO" "Downloaded file is not a ZIP archive, treating as direct script"
        
        # Check if it's likely a script file
        if [[ "$downloaded_file" == *.sh ]] || head -n 1 "$file_path" | grep -q "^#!"; then
            # Execute the script directly
            execute_direct_script "$file_path"
        else
            log_message "ERROR" "Downloaded file is not a ZIP and doesn't appear to be a script"
            log_message "INFO" "File type: $(file "$file_path")"
            exit 1
        fi
    fi
    
    # This point should not be reached due to exec in execute functions
    log_message "ERROR" "Unexpected exit from execution"
    exit 1
}

# Run main function
main "$@"
