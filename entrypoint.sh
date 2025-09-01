#!/bin/bash

# Configuration Flags
ENABLE_FALLBACK=true
ENABLE_LOGGING=true
CLEANUP_ON_EXIT=true
EXTRACT_BOOTSTRAP_ONLY=false

# Define your repositories in order of PRIORITY
REPOS=(
    "https://github.com/yourusername/your-public-cmd-repo.git"
    "https://bitbucket.org/yourusername/your-public-cmd-repo.git"
    "https://gitlab.com/yourusername/your-public-cmd-repo.git"
)

# Fixed configuration - USING YOUR SPECIFIED DIRECTORY
CLONE_TARGET_DIR="/tmp/repo_cache"
BOOTSTRAP_WORKDIR="/usr/src/app"  # Changed to your specified directory
LOG_FILE="/var/log/bootstrap-loader.log"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    case "$level" in
        "ERROR") echo "❌ $message" ;;
        "WARNING") echo "⚠️  $message" ;;
        "INFO") echo "ℹ️  $message" ;;
        *) echo "✅ $message" ;;
    esac
}

# Function to install required packages
install_packages() {
    echo "┌─────────────────────────────────────┐"
    echo "│    Installing Required Packages    │"
    echo "└─────────────────────────────────────┘"
    
    if ! sudo apt-get update -qq; then
        log_message "ERROR" "Failed to update package lists!"
        exit 1
    fi
    
    CRITICAL_PKGS=("git" "curl" "wget" "unzip")
    
    for pkg in "${CRITICAL_PKGS[@]}"; do
        if ! dpkg -l | grep -qw "^ii  $pkg"; then
            log_message "INFO" "Installing $pkg..."
            if ! sudo apt-get install -y -qq $pkg >/dev/null; then
                log_message "ERROR" "Failed to install $pkg"
                exit 1
            fi
            log_message "SUCCESS" "$pkg successfully installed"
        else
            log_message "INFO" "$pkg already installed"
        fi
    done
}

# Function to prepare workspace
prepare_workspace() {
    log_message "INFO" "Preparing workspace in $BOOTSTRAP_WORKDIR"
    # Create the working directory with proper permissions
    sudo mkdir -p "$BOOTSTRAP_WORKDIR"
    sudo chown -R $(whoami):$(whoami) "$BOOTSTRAP_WORKDIR"
    chmod 755 "$BOOTSTRAP_WORKDIR"
}

# Function to handle repository cloning and bootstrap extraction
handle_repository() {
    local repo_url=$1
    log_message "INFO" "Processing repository: $repo_url"
    
    # Clean up previous clone attempt
    rm -rf "$CLONE_TARGET_DIR" 2>/dev/null || true
    mkdir -p "$CLONE_TARGET_DIR"
    
    # Clone repository
    if timeout 30s git clone "$repo_url" "$CLONE_TARGET_DIR" 2>/dev/null; then
        log_message "SUCCESS" "Successfully cloned repository"
        
        # Look for bootstrap.sh in common locations
        local bootstrap_path=""
        local possible_paths=(
            "$CLONE_TARGET_DIR/bootstrap.sh"
            "$CLONE_TARGET_DIR/scripts/bootstrap.sh"
            "$CLONE_TARGET_DIR/src/bootstrap.sh"
        )
        
        for path in "${possible_paths[@]}"; do
            if [ -f "$path" ]; then
                bootstrap_path="$path"
                break
            fi
        done
        
        if [ -n "$bootstrap_path" ]; then
            log_message "SUCCESS" "Found bootstrap script at: $bootstrap_path"
            
            if [ "$EXTRACT_BOOTSTRAP_ONLY" = true ]; then
                # Copy only the bootstrap script
                cp "$bootstrap_path" "$BOOTSTRAP_WORKDIR/bootstrap.sh"
                log_message "INFO" "Copied bootstrap.sh to workspace"
            else
                # Copy entire repository contents
                cp -r "$CLONE_TARGET_DIR"/* "$BOOTSTRAP_WORKDIR/"
                log_message "INFO" "Copied repository contents to workspace"
            fi
            
            # EXPLICITLY SET EXECUTE PERMISSION - This is what you asked about
            chmod +x "$BOOTSTRAP_WORKDIR/bootstrap.sh"
            log_message "INFO" "Set execute permission on bootstrap.sh"
            
            # Clean up clone directory
            rm -rf "$CLONE_TARGET_DIR"
            
            return 0
        else
            log_message "WARNING" "No bootstrap.sh found in repository"
            rm -rf "$CLONE_TARGET_DIR"
            return 1
        fi
    else
        log_message "WARNING" "Failed to clone repository"
        rm -rf "$CLONE_TARGET_DIR"
        return 1
    fi
}

# Function to display IP and system information
display_ip_info() {
    echo "┌─────────────────────────────────────┐"
    echo "│      System Information            │"
    echo "└─────────────────────────────────────┘"
    
    if command -v curl >/dev/null; then
        IP_INFO=$(curl -s ipinfo.io)
        IP=$(echo "$IP_INFO" | grep '"ip"' | cut -d'"' -f4)
        COUNTRY=$(echo "$IP_INFO" | grep '"country"' | cut -d'"' -f4)
        CITY=$(echo "$IP_INFO" | grep '"city"' | cut -d'"' -f4)
        
        echo "🌐 IP Address: $IP"
        echo "🌍 Country: $COUNTRY"
        echo "🏙️ City: $CITY"
    else
        echo "⚠️ IP information tools not available"
    fi
    
    HOSTNAME=$(hostname)
    echo "🏷️ Hostname: $HOSTNAME"
}

# Function to cleanup on exit
cleanup() {
    if [ "$CLEANUP_ON_EXIT" = true ]; then
        log_message "INFO" "Cleaning up temporary files..."
        rm -rf "$CLONE_TARGET_DIR" 2>/dev/null || true
        # Note: We don't clean up BOOTSTRAP_WORKDIR as it may contain important files
    fi
    log_message "INFO" "Bootstrap loader execution finished"
}

# Set trap to ensure cleanup happens on exit
trap cleanup EXIT

# Main Execution Flow
echo "🚀 Starting Bootstrap Loader"
log_message "INFO" "Starting Bootstrap Loader execution"

# 1. Install required packages
install_packages

# 2. Display system info
display_ip_info

# 3. Prepare workspace
prepare_workspace

# 4. Attempt to clone from repositories
echo "┌─────────────────────────────────────┐"
echo "│    Cloning Bootstrap Repository     │"
echo "└─────────────────────────────────────┘"

SUCCESS=false
for repo_url in "${REPOS[@]}"; do
    if handle_repository "$repo_url"; then
        SUCCESS=true
        break
    fi
    
    # If not enabling fallback, break after first attempt
    if [ "$ENABLE_FALLBACK" = false ]; then
        log_message "INFO" "Fallback disabled, not trying other repositories"
        break
    fi
done

if [ "$SUCCESS" = false ]; then
    log_message "ERROR" "All repository cloning attempts failed"
    echo "┌─────────────────────────────────────┐"
    echo "│           ❌ FAILURE               │"
    echo "│ Could not retrieve bootstrap script │"
    echo "└─────────────────────────────────────┘"
    exit 1
fi

# 5. Execute the bootstrap script
echo "┌─────────────────────────────────────┐"
echo "│    Executing Bootstrap Script       │"
echo "└─────────────────────────────────────┘"

# Change to the working directory
cd "$BOOTSTRAP_WORKDIR"
log_message "INFO" "Working directory: $(pwd)"

# Verify the bootstrap script exists and is executable
if [ -f "bootstrap.sh" ]; then
    if [ -x "bootstrap.sh" ]; then
        log_message "INFO" "Bootstrap script is executable, executing now"
        # Execute the bootstrap script, replacing the current process
        exec ./bootstrap.sh
    else
        log_message "ERROR" "Bootstrap script exists but is not executable"
        # Try to fix permissions and execute
        chmod +x bootstrap.sh
        if [ -x "bootstrap.sh" ]; then
            log_message "INFO" "Fixed permissions, executing now"
            exec ./bootstrap.sh
        else
            log_message "ERROR" "Failed to make bootstrap script executable"
            exit 1
        fi
    fi
else
    log_message "ERROR" "Bootstrap script not found in workspace"
    exit 1
fi

# Note: The script will not reach here because of the exec command
exit 0
