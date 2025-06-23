#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/BaseManager.sh"

# Set manager-specific variables
MANAGER_NAME="Venv"
CONFIG_DIR="$HOME/.config/dummysimplevenvmanager"
HOTCMDS_FILE="$CONFIG_DIR/venvhotcmds.cfg"
SETTINGS_FILE="$CONFIG_DIR/settings.cfg"
CONDA_PATH_FILE="$CONFIG_DIR/condapath.cfg"
GLOBAL_STARTUP_CMDS_FILE="$CONFIG_DIR/global_startup_commands.cfg"
CONTAINER_STARTUP_CMDS_FILE="$CONFIG_DIR/container_startup_commands.cfg"
LAST_ACCESS_FILE="$CONFIG_DIR/last_access.cfg"
CREATION_TIME_FILE="$CONFIG_DIR/creation_time.cfg"
FAVORITES_FILE="$CONFIG_DIR/favorites.cfg"

# Initialize files
ensure_config_files
touch "$CONDA_PATH_FILE"

# Override get_creation_time for venv-specific behavior
get_creation_time() {
    local venv_name="$1"

    if [ -f "$CREATION_TIME_FILE" ]; then
        local timestamp=$(grep "^$venv_name:" "$CREATION_TIME_FILE" | cut -d: -f2)
        if [ -z "$timestamp" ]; then
            # Fallback to directory creation time
            local venv_dir=$(get_venv_directory)
            if [ $? -eq 0 ] && [ -d "$venv_dir/$venv_name" ]; then
                echo $(stat -c %Y "$venv_dir/$venv_name")
            else
                echo "0"
            fi
        else
            echo "$timestamp"
        fi
    else
        # Fallback to directory creation time
        local venv_dir=$(get_venv_directory)
        if [ $? -eq 0 ] && [ -d "$venv_dir/$venv_name" ]; then
            echo $(stat -c %Y "$venv_dir/$venv_name")
        else
            echo "0"
        fi
    fi
}

check_conda() {
    if command -v conda >/dev/null 2>&1; then
        return 0
    fi

    if [ -f "$CONDA_PATH_FILE" ]; then
        local saved_path=$(cat "$CONDA_PATH_FILE")
        if [ -x "$saved_path/bin/conda" ]; then
            export PATH="$saved_path/bin:$PATH"
            return 0
        fi
    fi

    return 1
}

set_conda_path() {
    echo -e "\n\033[1;33mConda not found in PATH. Would you like to specify its location?\033[0m"

    read -p "Enter conda installation directory (or press Enter when blank to return): " conda_dir

    if [ -z "$conda_dir" ]; then
        echo -e "\033[90mReturning to previous menu.\033[0m"
        return 1
    fi

    conda_dir="${conda_dir/#\~/$HOME}"

    if [ -x "$conda_dir/bin/conda" ]; then
        echo "$conda_dir" > "$CONDA_PATH_FILE"
        export PATH="$conda_dir/bin:$PATH"
        echo -e "\033[1;32mConda path set successfully!\033[0m"
        return 0
    else
        echo -e "\033[1;31mError: Conda executable not found in $conda_dir/bin\033[0m"
        echo -e "\033[90mMake sure you specified the correct conda installation directory.\033[0m"
        echo -e "\033[90mReturning.\033[0m"
        return 1
    fi
}

get_conda_python_versions() {
    conda search python | grep -E '^python\s+[0-9]' | awk '{print $2}' | sort -u -V
}

get_venv_python_version() {
    local venv_path="$1"
    local version=""

    if [ -f "$venv_path/.python-version" ]; then
        version=$(cat "$venv_path/.python-version")
    elif [ -f "$venv_path/bin/python" ]; then
        version=$("$venv_path/bin/python" --version 2>&1)
    else
        version="Unknown"
    fi

    echo "$version"
}

ensure_python_version() {
    local version="$1"
    local install_dir="$2"

    if ! check_conda; then
        if ! set_conda_path; then
            return 1
        fi
    fi

    if ! conda create -y -p "$install_dir" python="$version"; then
        echo "Error: Failed to install Python $version"
        return 1
    fi

    return 0
}

set_venv_directory() {
    while true; do
        read -p "Enter the directory for venvs (or press Enter to cancel): " venv_dir
        if [ -z "$venv_dir" ]; then
            echo "Operation cancelled."
            return 1
        fi
        if [ -d "$venv_dir" ]; then
            echo "VENV_DIR=$venv_dir" > "$SETTINGS_FILE"
            echo "Venv directory set to: $venv_dir"
            break
        else
            echo "Directory does not exist. Do you want to create it? (y/n)"
            read -r create_dir
            if [[ $create_dir =~ ^[Yy]$ ]]; then
                mkdir -p "$venv_dir"
                echo "VENV_DIR=$venv_dir" > "$SETTINGS_FILE"
                echo "Directory created and venv directory set to: $venv_dir"
                break
            fi
        fi
    done
    return 0
}

get_venv_directory() {
    if [ -f "$SETTINGS_FILE" ]; then
        local venv_dir=$(grep "^VENV_DIR=" "$SETTINGS_FILE" | cut -d= -f2)
        if [ -n "$venv_dir" ] && [ -d "$venv_dir" ]; then
            echo "$venv_dir"
            return 0
        fi
    fi
    return 1
}

show_venv_info() {
    local venv_path="$1"
    if [ -f "$venv_path/.python-version" ]; then
        echo "Python Version: $(cat "$venv_path/.python-version")"
    fi
    if [ -f "$venv_path/.conda-path" ]; then
        echo "Using Conda-installed Python from: $(cat "$venv_path/.conda-path")"
    fi
    echo "Location: $venv_path"
    if [ -f "${venv_path}/working_directory.cfg" ]; then
        echo "Working Directory: $(cat "${venv_path}/working_directory.cfg")"
    fi
}

create_new_venv() {
    clear
    local venv_dir=$(get_venv_directory)
    if [ $? -ne 0 ]; then
        echo "Error: Could not determine venv directory."
        return 1
    fi

    echo -e "\n\033[1;36mCreate New venv\033[0m"
    echo -e "\033[90m----------------------------------------\033[0m"

    while true; do
        read -p "Enter the name for the new venv: " venv_name
        if [ -z "$venv_name" ]; then
            echo "Operation cancelled."
            return 1
        fi

        # Validate venv name (alphanumeric, dash, and underscore only)
        if ! [[ "$venv_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: Venv name can only contain letters, numbers, dashes, and underscores."
            continue
        fi

        # Check if venv directory already exists
        if [ -d "$venv_dir/$venv_name" ]; then
            echo "Error: A venv with this name already exists."
            continue
        fi
        break
    done

    while true; do
        echo -e "\nSelect Python Version:"
        echo "1. System Python ($(python3 --version 2>&1))"
        echo "2. Custom Python Version"

        read -p "Enter your choice (1-2): " version_choice

        if ! [[ "$version_choice" =~ ^[1-2]$ ]]; then
            echo -e "\033[1;31mInvalid choice. Enter 1 or 2.\033[0m"
            continue
        fi

        case $version_choice in
            1)
                echo -e "\n\033[1;32mUsing system Python...\033[0m"
                if ! python3 -m venv "$venv_dir/$venv_name"; then
                    echo "Failed to create venv with system Python."
                    return 1
                fi
                echo "$(python3 --version 2>&1)" > "$venv_dir/$venv_name/.python-version"
                break
                ;;
            2)
                if ! check_conda; then
                    echo -e "\n\033[1;33mConda not found. Specify conda installation directory.\033[0m"

                    while true; do
                        read -p "Enter conda installation directory (or press Enter to return to version selection): " conda_dir

                        if [ -z "$conda_dir" ]; then
                            echo -e "\033[90mReturning to version selection...\033[0m"
                            continue 2
                        fi

                        conda_dir="${conda_dir/#\~/$HOME}"

                        if [ -x "$conda_dir/bin/conda" ]; then
                            echo "$conda_dir" > "$CONDA_PATH_FILE"
                            export PATH="$conda_dir/bin:$PATH"
                            echo -e "\033[1;32mConda path set successfully!\033[0m"
                            break
                        else
                            echo -e "\033[1;31mError: Conda executable not found in $conda_dir/bin\033[0m"
                            echo -e "\033[90mPlease check the directory and try again.\033[0m"
                        fi
                    done
                fi

                while true; do
                    echo -e "\nEnter Python version (e.g., '3.11') or type 'list' to see available versions:"
                    read -p "> " desired_version

                    if [ "$desired_version" = "list" ]; then
                        echo -e "\nAvailable Python versions:"
                        get_conda_python_versions | while read version; do
                            echo "- Python $version"
                        done
                        continue
                    fi

                    if [[ "$desired_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
                        local env_path="$venv_dir/$venv_name"

                        echo -e "\n\033[1;32mCreating environment with Python $desired_version...\033[0m"
                        if ! conda create -y -p "$env_path" python="$desired_version"; then
                            echo -e "\033[1;31mFailed to create environment with Python $desired_version.\033[0m"
                            continue
                        fi

                        echo "Python $desired_version (conda)" > "$env_path/.python-version"
                        break 2
                    else
                        echo -e "\033[1;31mInvalid version format. Use format like '3.11' or '3.11.0'.\033[0m"
                    fi
                done
                ;;
        esac
    done

    # Record creation time
    set_creation_time "$venv_name"

    echo -e "\n\033[1;32mNew venv created successfully: $venv_name\033[0m"
    echo "Initializing venv..."

    # Run a non-interactive command to ensure initialization is complete
    source "$venv_dir/$venv_name/bin/activate" && deactivate

    echo -e "\nSetup complete. Returning to manager..."
    sleep 1
    return 0
}

enter_venv() {
    local venv_name="$1"
    local venv_path="$2"

    # Update last access time
    update_last_access "$venv_name"

    # Create a temporary activation script with startup commands
    local temp_script=$(mktemp)

    # Write the basic activation
    cat > "$temp_script" << EOF
#!/bin/bash
source "${venv_path}/bin/activate"

EOF

    # Add global startup commands if they exist
    if [ -s "$GLOBAL_STARTUP_CMDS_FILE" ]; then
        echo "# Run global startup commands" >> "$temp_script"
        cat "$GLOBAL_STARTUP_CMDS_FILE" >> "$temp_script"
        echo "" >> "$temp_script"
    fi

    # Add container-specific startup commands if they exist
    if [ -s "$CONTAINER_STARTUP_CMDS_FILE" ]; then
        echo "# Run container-specific startup commands" >> "$temp_script"
        while IFS=: read -r env cmd || [ -n "$env" ]; do
            if [ "$env" = "$venv_name" ]; then
                echo "$cmd" >> "$temp_script"
            fi
        done < "$CONTAINER_STARTUP_CMDS_FILE"
        echo "" >> "$temp_script"
    fi

    # Add working directory change if configured
    if [ -f "${venv_path}/working_directory.cfg" ]; then
        working_dir=$(cat "${venv_path}/working_directory.cfg")
        if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
            echo "# Change to configured working directory" >> "$temp_script"
            echo "cd \"$working_dir\"" >> "$temp_script"
            echo "" >> "$temp_script"
        fi
    fi

    # Set custom prompt and finalize script
    cat >> "$temp_script" << EOF
# Set custom prompt
PS1="($venv_name) \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "

# Override deactivate to exit shell when done
alias deactivate="command deactivate && exit"

# Start interactive shell
exec bash
EOF

    chmod +x "$temp_script"

    # Activate and show info
    color_code=$(generate_color_code "$venv_name")
    echo -e "${color_code}Activating venv: $venv_name\033[0m"

    if [ -s "$GLOBAL_STARTUP_CMDS_FILE" ] || grep -q "^$venv_name:" "$CONTAINER_STARTUP_CMDS_FILE"; then
        echo -e "\033[90mRunning startup commands...\033[0m"
    fi

    # Execute the script
    bash "$temp_script"

    # Clean up
    rm "$temp_script"

    # Return to current directory after shell exits
    cd "$PWD"
}

set_working_directory() {
    clear
    local venv_path="$1"
    read -p "Enter the working directory (leave blank to clear): " working_dir
    if [ -n "$working_dir" ]; then
        echo "$working_dir" > "${venv_path}/working_directory.cfg"
        echo "Working directory set to: $working_dir"

        read -p "Execute hot commands in this working directory? (yes/no): " use_working_dir
        echo "$use_working_dir" > "${venv_path}/use_working_dir_for_hot_commands.cfg"
        echo "Hot commands will $([ "$use_working_dir" = "yes" ] && echo "be executed" || echo "not be executed") in the working directory."
    else
        rm -f "${venv_path}/working_directory.cfg"
        rm -f "${venv_path}/use_working_dir_for_hot_commands.cfg"
        echo "Working directory cleared"
    fi
}

show_launch_script() {
    clear
    local venv_name="$1"
    local venv_path="$2"
    local working_dir=""
    if [ -f "${venv_path}/working_directory.cfg" ]; then
        working_dir=$(cat "${venv_path}/working_directory.cfg")
    fi

    echo "Launch script:"
    if [ -n "$working_dir" ]; then
        echo "cd '$working_dir' && source '${venv_path}/bin/activate' && bash"
    else
        echo "source '${venv_path}/bin/activate' && bash"
    fi
    echo ""
    echo "You can use this line to create a shortcut or assign it to a macro."
    echo "Press Enter to continue..."
    read
}

execute_hot_command() {
    local venv_name="$1"
    local command_num="$2"
    local venv_path="$3"

    # Update last access time
    update_last_access "$venv_name"

    # Get all hot commands for this venv (handle both formats)
    local hot_cmds=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Extract the venv name (everything before first colon)
        local env="${line%%:*}"
        if [ "$env" = "$venv_name" ]; then
            # Check for new exotic delimiter format first
            if [[ "$line" == *":-:+:"* ]]; then
                # New format with exotic delimiter
                local after_delimiter="${line#*:-:+:}"
                if [[ "$after_delimiter" == *":-:+:"* ]]; then
                    # Format: env:-:+:name:-:+:command
                    local command="${after_delimiter#*:-:+:}"
                    hot_cmds+=("$command")
                else
                    # Format: env:-:+:command
                    hot_cmds+=("$after_delimiter")
                fi
            else
                # Legacy single-colon format
                local after_first_colon="${line#*:}"
                if [[ "$after_first_colon" == *:* ]] && [[ "$after_first_colon" != *"://"* ]] && [[ "${after_first_colon#*:}" != *"://"* ]]; then
                    # Old format: env:name:command
                    local temp="${line#*:}"
                    local name="${temp%%:*}"
                    local command="${temp#"$name":}"
                    hot_cmds+=("$command")
                else
                    # Old format: env:command
                    hot_cmds+=("$after_first_colon")
                fi
            fi
        fi
    done < "$HOTCMDS_FILE"

    # Convert the menu number to array index using the global CONTAINER_MENU_ITEMS
    local array_index=$((command_num - $CONTAINER_MENU_ITEMS))

    # Check if index is valid
    if [ "$array_index" -ge 0 ] && [ "$array_index" -lt "${#hot_cmds[@]}" ]; then
        local command="${hot_cmds[$array_index]}"

        source "${venv_path}/bin/activate"

        # Execute global startup commands if they exist
        if [ -s "$GLOBAL_STARTUP_CMDS_FILE" ]; then
            while IFS= read -r startup_cmd; do
                local startup_temp_script=$(mktemp)
                cat > "$startup_temp_script" << 'EOF'
#!/bin/bash
set -e
EOF
                echo "$startup_cmd" >> "$startup_temp_script"
                chmod +x "$startup_temp_script"
                bash "$startup_temp_script"
                rm "$startup_temp_script"
            done < "$GLOBAL_STARTUP_CMDS_FILE"
        fi

        # Execute container-specific startup commands if they exist
        if [ -s "$CONTAINER_STARTUP_CMDS_FILE" ]; then
            while IFS=: read -r env cmd || [ -n "$env" ]; do
                if [ "$env" = "$venv_name" ]; then
                    local container_temp_script=$(mktemp)
                    cat > "$container_temp_script" << 'EOF'
#!/bin/bash
set -e
EOF
                    echo "$cmd" >> "$container_temp_script"
                    chmod +x "$container_temp_script"
                    bash "$container_temp_script"
                    rm "$container_temp_script"
                fi
            done < "$CONTAINER_STARTUP_CMDS_FILE"
        fi

        # Set working directory if configured
        if [ -f "${venv_path}/working_directory.cfg" ]; then
            working_dir=$(cat "${venv_path}/working_directory.cfg")
            use_working_dir=$(cat "${venv_path}/use_working_dir_for_hot_commands.cfg" 2>/dev/null || echo "no")
            if [ -n "$working_dir" ] && [ -d "$working_dir" ] && [ "$use_working_dir" = "yes" ]; then
                pushd "$working_dir" > /dev/null
                # Create a temporary script file to handle complex commands with quotes
                local temp_script=$(mktemp)
                cat > "$temp_script" << 'EOF'
#!/bin/bash
set -e
# Source interactive shell configurations to have access to aliases and PATH
[ -f ~/.bashrc ] && source ~/.bashrc
[ -f ~/.bash_profile ] && source ~/.bash_profile
EOF
                echo "$command" >> "$temp_script"
                chmod +x "$temp_script"
                bash "$temp_script"
                rm "$temp_script"
                popd > /dev/null
            else
                # Create a temporary script file to handle complex commands with quotes
                local temp_script=$(mktemp)
                cat > "$temp_script" << 'EOF'
#!/bin/bash
set -e
# Source interactive shell configurations to have access to aliases and PATH
[ -f ~/.bashrc ] && source ~/.bashrc
[ -f ~/.bash_profile ] && source ~/.bash_profile
EOF
                echo "$command" >> "$temp_script"
                chmod +x "$temp_script"
                bash "$temp_script"
                rm "$temp_script"
            fi
        else
            # Create a temporary script file to handle complex commands with quotes
            local temp_script=$(mktemp)
            cat > "$temp_script" << 'EOF'
#!/bin/bash
set -e
# Source interactive shell configurations to have access to aliases and PATH
[ -f ~/.bashrc ] && source ~/.bashrc
[ -f ~/.bash_profile ] && source ~/.bash_profile
EOF
            echo "$command" >> "$temp_script"
            chmod +x "$temp_script"
            bash "$temp_script"
            rm "$temp_script"
        fi
        deactivate
        echo "Hot command executed. Press Enter to continue..."
        read
    else
        echo "Invalid hot command number."
        echo "Press Enter to continue..."
        read
    fi
}

delete_venv() {
    clear
    display_items formatted_venvs
    read -p "Enter the number of the venv to delete: " delete_choice

    if [ "$delete_choice" -ge 1 ] && [ "$delete_choice" -le "${#venvs[@]}" ]; then
        selected_venv="${venvs[$((delete_choice-1))]}"

        # Safety check 1: Ensure the name doesn't contain dangerous characters
        if echo "$selected_venv" | grep -q '[/;:|]'; then
            echo "Error: Venv name contains invalid characters"
            return 1
        fi

        # Get venv directory from settings
        venv_dir=$(get_venv_directory)
        if [ $? -ne 0 ]; then
            echo "Error: Could not determine venv directory"
            return 1
        fi

        # Safety check 2: Construct and verify the full path
        venv_path="$venv_dir/$selected_venv"

        # Safety check 3: Ensure the path is actually under the venv directory
        if [[ ! "$(realpath "$venv_path")" =~ ^"$(realpath "$venv_dir")"/ ]]; then
            echo "Error: Security check failed - path is outside of venv directory"
            return 1
        fi

        # Safety check 4: Verify the directory exists and is a directory
        if [ ! -d "$venv_path" ]; then
            echo "Error: Venv directory not found or is not a directory"
            return 1
        fi

        echo "This will:"
        echo "1. Delete the virtual environment '$selected_venv'"
        echo "2. Remove the folder '$venv_path'"
        echo "3. Delete all associated hot commands"
        echo "4. Delete all associated container startup commands"
        read -p "To confirm deletion, Type the name of the venv ($selected_venv): " confirm

        if [ "$confirm" = "$selected_venv" ]; then
            # First deactivate if this venv is active
            if [[ "$VIRTUAL_ENV" == "$venv_path" ]]; then
                deactivate
            fi

            # Safely remove the directory
            if [ -d "$venv_path" ]; then
                # Final safety check before removal
                if [[ "$(realpath "$venv_path")" =~ ^"$(realpath "$venv_dir")"/ ]]; then
                    rm -rf "$venv_path"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to remove venv directory"
                        return 1
                    fi
                else
                    echo "Error: Final security check failed"
                    return 1
                fi
            fi

            # Remove hot commands
            local temp_file=$(mktemp)
            grep -v "^$selected_venv:" "$HOTCMDS_FILE" > "$temp_file"
            mv "$temp_file" "$HOTCMDS_FILE"

            # Remove container-specific startup commands
            temp_file=$(mktemp)
            grep -v "^$selected_venv:" "$CONTAINER_STARTUP_CMDS_FILE" > "$temp_file"
            mv "$temp_file" "$CONTAINER_STARTUP_CMDS_FILE"

            # Remove entries from tracking files
            temp_file=$(mktemp)
            grep -v "^$selected_venv:" "$CREATION_TIME_FILE" > "$temp_file" 2>/dev/null
            mv "$temp_file" "$CREATION_TIME_FILE"

            temp_file=$(mktemp)
            grep -v "^$selected_venv:" "$LAST_ACCESS_FILE" > "$temp_file" 2>/dev/null
            mv "$temp_file" "$LAST_ACCESS_FILE"

            # Remove from favorites if present
            if [ -f "$FAVORITES_FILE" ]; then
                temp_file=$(mktemp)
                grep -v "^$selected_venv$" "$FAVORITES_FILE" > "$temp_file"
                mv "$temp_file" "$FAVORITES_FILE"
            fi

            echo "Virtual environment $selected_venv and its associated files have been deleted."
        else
            echo "Deletion aborted: name did not match."
        fi
    else
        echo "Invalid choice"
    fi
}

# Implementing required functions from BaseManager

display_options_menu() {
    clear
    echo "Options:"
    echo "1. Create a new venv"
    echo "2. Delete a venv"
    echo "3. Manage global startup commands"
    echo "4. Manage sorting preferences"
    echo "5. Manage color mode"
    echo "6. Manage favorites"
    echo "0. Back to main menu"
}

display_options_and_commands() {
    local venv_name="$1"
    local venv_path="$2"
    clear
    local color_code=$(generate_color_code "$venv_name")
    echo -e "\n${color_code}Managing venv: $venv_name\033[0m"
    show_venv_info "$venv_path"
    echo "Options:"
    echo "1. Enter venv"
    echo "2. Modify venv hot commands"
    echo "3. Manage container startup commands"
    echo "4. Set working directory"
    echo "5. Show launch script"
    echo "0. Back to main menu"
    echo "------------------------------"
    echo "Hot commands:"
    if [ -f "$HOTCMDS_FILE" ]; then
        local i=5
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines
            [ -z "$line" ] && continue
            
            # Extract the venv name (everything before first delimiter)
            local env
            if [[ "$line" == *":-:+:"* ]]; then
                env="${line%%:-:+:*}"
            else
                env="${line%%:*}"
            fi
            
            if [ "$env" = "$venv_name" ]; then
                i=$((i+1))
                
                # Check for new exotic delimiter format first
                if [[ "$line" == *":-:+:"* ]]; then
                    # New format with exotic delimiter
                    local after_delimiter="${line#*:-:+:}"
                    if [[ "$after_delimiter" == *":-:+:"* ]]; then
                        # Format: env:-:+:name:-:+:command
                        local cmd_name="${after_delimiter%%:-:+:*}"
                        cmd_color_code=$(generate_color_code "$venv_name:$cmd_name")
                        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$cmd_name"
                    else
                        # Format: env:-:+:command
                        cmd_color_code=$(generate_color_code "$venv_name:$after_delimiter")
                        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$after_delimiter"
                    fi
                else
                    # Legacy single-colon format
                    local after_first_colon="${line#*:}"
                    if [[ "$after_first_colon" == *:* ]] && [[ "$after_first_colon" != *"://"* ]] && [[ "${after_first_colon#*:}" != *"://"* ]]; then
                        # Old format: env:name:command (has custom name)
                        local cmd_name="${after_first_colon%%:*}"
                        cmd_color_code=$(generate_color_code "$venv_name:$cmd_name")
                        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$cmd_name"
                    else
                        # Old format: env:command (no custom name)
                        cmd_color_code=$(generate_color_code "$venv_name:$after_first_colon")
                        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$after_first_colon"
                    fi
                fi
            fi
        done < "$HOTCMDS_FILE"
    else
        echo "No hot commands found."
    fi
}

handle_custom_options() {
    local option_choice="$1"
    case $option_choice in
        1)
            create_new_venv
            return 2
            ;;
        2)
            delete_venv
            return 2
            ;;
        3)
            manage_global_startup_commands
            return 2
            ;;
        4)
            manage_sorting_preferences
            return 2
            ;;
        5)
            manage_color_mode
            return 2
            ;;
        6)
            # Modified to show unformatted venv names in the favorites menu
            clear
            echo -e "\n\033[1;36mManage Favorites\033[0m"
            echo -e "\033[90m----------------------------------------\033[0m"

            # Display all items with favorite status
            echo "Current items (★ = favorite):"
            for i in "${!venvs[@]}"; do
                item="${venvs[i]}"
                color_code=$(generate_color_code "$item")
                star="  "
                if is_favorite "$item"; then
                    star="★ "
                fi
                # Also show Python version for better identification
                version=$(get_venv_python_version "$venv_dir/$item")
                printf "%d. %s%b%s \033[90m[%s]\033[0m\n" "$((i+1))" "$star" "$color_code" "$item" "$version"
            done

            echo -e "\nEnter the number of an item to toggle its favorite status"
            echo "0. Return to options"

            read -p "Enter your choice: " fav_choice

            if [ "$fav_choice" = "0" ]; then
                return 2
            fi

            # Check if selection is valid
            if [ "$fav_choice" -ge 1 ] && [ "$fav_choice" -le "${#venvs[@]}" ]; then
                local selected_item="${venvs[$((fav_choice-1))]}"
                toggle_favorite "$selected_item"
                echo "Press Enter to continue..."
                read
                return 2
            else
                echo "Invalid choice"
                echo "Press Enter to continue..."
                read
                return 2
            fi
            ;;
        *)
            echo "Invalid choice"
            return 0
            ;;
    esac
}

handle_option() {
    local venv_name="$1"
    local option="$2"
    local venv_path="$3"

    case $option in
        1)
            enter_venv "$venv_name" "$venv_path"
            return 2
            ;;
        2)
            echo "1. Add hot command"
            echo "2. Remove hot command"
            echo "3. Rename hot command"
            echo "4. Edit hot command"
            echo "5. Show hot commands config file path"
            read -p "Enter your choice: " modify_option
            if [ -z "$modify_option" ]; then
                return 0
            fi
            case $modify_option in
                1) add_hot_command "$venv_name" ;;
                2) remove_hot_command "$venv_name" ;;
                3) rename_hot_command "$venv_name" ;;
                4) edit_hot_command "$venv_name" ;;
                5) 
                    echo -e "\nHot commands configuration file path:"
                    echo "$HOTCMDS_FILE"
                    echo -e "\nPress Enter to continue..."
                    read
                    ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
        3)
            manage_container_startup_commands "$venv_name"
            ;;
        4)
            set_working_directory "$venv_path"
            ;;
        5)
            show_launch_script "$venv_name" "$venv_path"
            ;;
        0)
            return 2
            ;;
        *)
            if [ "$option" -gt 5 ]; then
                execute_hot_command "$venv_name" "$option" "$venv_path"
            else
                echo "Invalid choice"
                echo "Press Enter to continue..."
                read
            fi
            ;;
    esac
}

# First-time setup check
if ! get_venv_directory > /dev/null; then
    echo -e "Welcome to \033[38;2;102;205;170mDummy Simple Venv Manager!\033[0m"
    echo "To start, just enter what directory you want to use to store your Python virtual environment(s) (venv) inside of."
    echo "You can use a pre-existing directory or enter a new one to create it."
    if ! set_venv_directory; then
        echo "No venv directory set. Exiting..."
        exit 1
    fi

    # Ask for color mode preference during first-time setup
    prompt_for_color_mode
fi

# Main Loop
while true; do
    clear
    venv_dir=$(get_venv_directory)
    if [ $? -ne 0 ]; then
        echo "Error: Could not determine venv directory."
        exit 1
    fi

    # Get raw venv list
    venvs=($(find "$venv_dir" -maxdepth 1 -type d -printf "%f\n"))
    venvs=(${venvs[@]/"$(basename "$venv_dir")"/})
    venvs=(${venvs[@]/*.conda/})

    # Sort the venv list based on the sorting method
    sort_method=$(get_sort_method)

    case $sort_method in
        alphabetical)
            # Sort alphabetically
            IFS=$'\n' venvs=($(sort <<<"${venvs[*]}"))
            ;;
        creation_time)
            # Sort by creation time (newest first)
            sort_items_by_creation_time venvs
            ;;
        last_used)
            # Sort by last access time (most recent first)
            sort_items_by_last_access venvs
            ;;
    esac

    # Format the venv list for display
    formatted_venvs=()
    for venv in "${venvs[@]}"; do
        version=$(get_venv_python_version "$venv_dir/$venv")
        formatted_venvs+=("$venv [$version]")
    done

    # Get favorites and format them
    favorites=()
    get_favorites venvs favorites

    if [ ${#favorites[@]} -gt 0 ]; then
        # Format favorites for display
        formatted_favorites=()
        for venv in "${favorites[@]}"; do
            version=$(get_venv_python_version "$venv_dir/$venv")
            formatted_favorites+=("$venv [$version]")
        done

        # Display favorites section
        echo "Favorites:"
        for i in "${!formatted_favorites[@]}"; do
            item_name="${formatted_favorites[i]}"
            venv_name="${favorites[i]}"
            color_code=$(generate_color_code "$venv_name")
            printf "%d. %b%s\033[0m\n" "$((i+1))" "$color_code" "$item_name"
        done
        echo ""
    fi

    # Display regular items
    echo "Available ${MANAGER_NAME}s:"
    # Start numbering after favorites
    start_num=$((${#favorites[@]} + 1))
    non_favorites=()
    formatted_non_favorites=()

    # Get non-favorites
    for i in "${!venvs[@]}"; do
        venv="${venvs[i]}"
        is_fav=0
        for fav in "${favorites[@]}"; do
            if [ "$venv" = "$fav" ]; then
                is_fav=1
                break
            fi
        done
        if [ $is_fav -eq 0 ]; then
            non_favorites+=("$venv")
            formatted_non_favorites+=("${formatted_venvs[i]}")
        fi
    done

    # Display non-favorites
    for i in "${!formatted_non_favorites[@]}"; do
        item_name="${formatted_non_favorites[i]}"
        venv_name="${non_favorites[i]}"
        color_code=$(generate_color_code "$venv_name")
        printf "%d. %b%s\033[0m\n" "$((start_num + i))" "$color_code" "$item_name"
    done
    echo -e "\n0. Options"

    read -p "Enter the number of the venv you want to manage, 0 for Options, or type 'help': " choice

    if [ -z "$choice" ]; then
        continue
    elif [ "$choice" = "help" ]; then
        clear
        if [ -f "$SCRIPT_DIR/DOCUMENTATION.md" ]; then
            cat "$SCRIPT_DIR/DOCUMENTATION.md"
            echo -e "\n\033[1;36mPress Enter to return to the previous menu...\033[0m"
            read
        else
            echo -e "\033[1;31mError: Documentation file not found.\033[0m"
            echo -e "Ensure DOCUMENTATION.md exists in: $SCRIPT_DIR"
            echo -e "\nPress Enter to continue..."
            read
        fi
        continue
    elif [ "$choice" -eq 0 ]; then
        handle_options_menu
        if [ $? -eq 2 ]; then
            continue
        fi
    elif [ "$choice" -ge 1 ]; then
        # Check if selection is in favorites range
        if [ "$choice" -le "${#favorites[@]}" ]; then
            selected_venv="${favorites[$(($choice-1))]}"
            venv_path="$venv_dir/$selected_venv"
            manage_item "$selected_venv" "$venv_path"
        # Check if selection is in non-favorites range
        elif [ "$choice" -gt "${#favorites[@]}" ] && [ "$choice" -le "$((${#favorites[@]} + ${#non_favorites[@]}))" ]; then
            non_fav_index=$(($choice - ${#favorites[@]} - 1))
            selected_venv="${non_favorites[$non_fav_index]}"
            venv_path="$venv_dir/$selected_venv"
            manage_item "$selected_venv" "$venv_path"
        else
            echo "Invalid choice"
            sleep 1
        fi
    else
        echo "Invalid choice"
    fi
done
