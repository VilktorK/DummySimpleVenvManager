#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/BaseManager.sh"

MANAGER_NAME="Venv"
CONFIG_DIR="$HOME/.config/dummysimplevenvmanager"
HOTCMDS_FILE="$CONFIG_DIR/venvhotcmds.cfg"
SETTINGS_FILE="$CONFIG_DIR/settings.cfg"
CONDA_PATH_FILE="$CONFIG_DIR/condapath.cfg"
GLOBAL_STARTUP_CMDS_FILE="$CONFIG_DIR/global_startup_commands.cfg"
CONTAINER_STARTUP_CMDS_FILE="$CONFIG_DIR/container_startup_commands.cfg"

mkdir -p "$CONFIG_DIR"
touch "$HOTCMDS_FILE"
touch "$SETTINGS_FILE"
touch "$GLOBAL_STARTUP_CMDS_FILE"
touch "$CONTAINER_STARTUP_CMDS_FILE"

# Amount of entries in the container's menu
CONTAINER_MENU_ITEMS=6

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

# Function to manage global startup commands
manage_global_startup_commands() {
    clear
    echo -e "\n\033[1;36mManage Global Venv Startup Commands\033[0m"
    echo "These commands will run automatically when any venv is activated"
    echo -e "\033[90m----------------------------------------\033[0m"

    if [ -s "$GLOBAL_STARTUP_CMDS_FILE" ]; then
        echo "Current global startup commands:"
        local i=1
        while IFS= read -r cmd; do
            cmd_color_code=$(generate_color_code "$cmd")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$cmd"
            i=$((i+1))
        done < "$GLOBAL_STARTUP_CMDS_FILE"
    else
        echo "No global startup commands configured."
    fi

    echo -e "\n1. Add global startup command"
    echo "2. Remove global startup command"
    echo "0. Return to options"

    read -p "Enter your choice: " cmd_option
    case $cmd_option in
        1)
            add_global_startup_command
            ;;
        2)
            remove_global_startup_command
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

add_global_startup_command() {
    read -p "Enter the command to run at venv activation (for all venvs): " new_cmd

    if [ -z "$new_cmd" ]; then
        echo "Operation cancelled."
        return
    fi

    echo "$new_cmd" >> "$GLOBAL_STARTUP_CMDS_FILE"
    echo -e "\033[1;32mGlobal startup command added successfully.\033[0m"
    echo "Press Enter to continue..."
    read
}

remove_global_startup_command() {
    if [ ! -s "$GLOBAL_STARTUP_CMDS_FILE" ]; then
        echo "No global startup commands to remove."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a command to remove:"
    mapfile -t cmds < "$GLOBAL_STARTUP_CMDS_FILE"

    for i in "${!cmds[@]}"; do
        cmd_color_code=$(generate_color_code "${cmds[$i]}")
        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$((i+1))" "${cmds[$i]}"
    done

    read -p "Enter command number to remove (or press Enter to cancel): " remove_num

    if [ -z "$remove_num" ]; then
        echo "Operation cancelled."
        return
    fi

    if [[ "$remove_num" =~ ^[0-9]+$ ]] && [ "$remove_num" -ge 1 ] && [ "$remove_num" -le "${#cmds[@]}" ]; then
        temp_file=$(mktemp)
        sed "$remove_num d" "$GLOBAL_STARTUP_CMDS_FILE" > "$temp_file"
        mv "$temp_file" "$GLOBAL_STARTUP_CMDS_FILE"
        echo -e "\033[1;32mGlobal startup command removed successfully.\033[0m"
    else
        echo "Invalid selection."
    fi

    echo "Press Enter to continue..."
    read
}

# Function to manage container-specific startup commands
manage_container_startup_commands() {
    local venv_name="$1"
    clear

    echo -e "\n\033[1;36mManage Container-Specific Startup Commands for $venv_name\033[0m"
    echo "These commands will run automatically when this specific venv is activated"
    echo -e "\033[90m----------------------------------------\033[0m"

    # Display current container-specific commands
    local container_cmds=()
    if [ -s "$CONTAINER_STARTUP_CMDS_FILE" ]; then
        while IFS=: read -r env cmd || [ -n "$env" ]; do
            if [ "$env" = "$venv_name" ]; then
                container_cmds+=("$cmd")
            fi
        done < "$CONTAINER_STARTUP_CMDS_FILE"
    fi

    if [ ${#container_cmds[@]} -gt 0 ]; then
        echo "Current container-specific startup commands for $venv_name:"
        for i in "${!container_cmds[@]}"; do
            cmd_color_code=$(generate_color_code "${container_cmds[$i]}")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$((i+1))" "${container_cmds[$i]}"
        done
    else
        echo "No container-specific startup commands configured for $venv_name."
    fi

    echo -e "\n1. Add container-specific startup command"
    echo "2. Remove container-specific startup command"
    echo "0. Return to container menu"

    read -p "Enter your choice: " cmd_option
    case $cmd_option in
        1)
            add_container_startup_command "$venv_name"
            ;;
        2)
            remove_container_startup_command "$venv_name"
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

add_container_startup_command() {
    local venv_name="$1"
    read -p "Enter the command to run at activation for $venv_name: " new_cmd

    if [ -z "$new_cmd" ]; then
        echo "Operation cancelled."
        return
    fi

    echo "$venv_name:$new_cmd" >> "$CONTAINER_STARTUP_CMDS_FILE"
    echo -e "\033[1;32mContainer-specific startup command added successfully.\033[0m"
    echo "Press Enter to continue..."
    read
}

remove_container_startup_command() {
    local venv_name="$1"
    local container_cmds=()
    local container_cmd_lines=()
    local line_num=1

    # Collect commands and their line numbers
    while IFS=: read -r env cmd || [ -n "$env" ]; do
        if [ "$env" = "$venv_name" ]; then
            container_cmds+=("$cmd")
            container_cmd_lines+=("$line_num")
        fi
        line_num=$((line_num+1))
    done < "$CONTAINER_STARTUP_CMDS_FILE"

    if [ ${#container_cmds[@]} -eq 0 ]; then
        echo "No container-specific startup commands to remove for $venv_name."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a command to remove:"
    for i in "${!container_cmds[@]}"; do
        cmd_color_code=$(generate_color_code "${container_cmds[$i]}")
        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$((i+1))" "${container_cmds[$i]}"
    done

    read -p "Enter command number to remove (or press Enter to cancel): " remove_num

    if [ -z "$remove_num" ]; then
        echo "Operation cancelled."
        return
    fi

    if [[ "$remove_num" =~ ^[0-9]+$ ]] && [ "$remove_num" -ge 1 ] && [ "$remove_num" -le "${#container_cmds[@]}" ]; then
        line_to_remove=${container_cmd_lines[$((remove_num-1))]}
        temp_file=$(mktemp)
        sed "${line_to_remove}d" "$CONTAINER_STARTUP_CMDS_FILE" > "$temp_file"
        mv "$temp_file" "$CONTAINER_STARTUP_CMDS_FILE"
        echo -e "\033[1;32mContainer-specific startup command removed successfully.\033[0m"
    else
        echo "Invalid selection."
    fi

    echo "Press Enter to continue..."
    read
}

if ! get_venv_directory > /dev/null; then
    echo -e "Welcome to \033[38;2;102;205;170mDummy Simple Venv Manager!\033[0m"
  # echo "You currently have no config directory which means this is likely your first time running the script."
    echo "To start, just enter what directory you want to use to store your Python virtual environment(s) (venv) inside of."
    echo "You can use a pre-existing directory or enter a new one to create it."
    if ! set_venv_directory; then
        echo "No venv directory set. Exiting..."
        exit 1
    fi
fi

display_options_menu() {
    clear
    echo "Options:"
    echo "1. Create a new venv"
    echo "2. Delete a venv"
    echo "3. Manage global startup commands"
    echo "0. Back to main menu"
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
        grep "^$venv_name:" "$HOTCMDS_FILE" | cut -d: -f2- | while read -r cmd; do
            i=$((i+1))
            cmd_color_code=$(generate_color_code "$venv_name:$cmd")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$i" "$cmd"
        done
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
            read -p "Enter your choice: " modify_option
            if [ -z "$modify_option" ]; then
                return 0
            fi
            case $modify_option in
                1) add_hot_command "$venv_name" ;;
                2) remove_hot_command "$venv_name" ;;
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

    # Create a temporary activation script with startup commands
    local temp_script=$(mktemp)

    # Write the basic activation
    cat > "$temp_script" << EOF
#!/bin/bash
# Auto-generated venv activation script
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

remove_hot_command() {
    clear
    local venv_name="$1"
    local hot_cmds=()
    local hot_cmd_lines=()
    local line_num=1

    # Collect commands and their line numbers
    while IFS= read -r line; do
        if [[ "$line" == "$venv_name:"* ]]; then
            hot_cmds+=("${line#*:}")
            hot_cmd_lines+=("$line_num")
        fi
        line_num=$((line_num+1))
    done < "$HOTCMDS_FILE"

    if [ ${#hot_cmds[@]} -eq 0 ]; then
        echo "No hot commands to remove for $venv_name."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a hot command to remove:"

    local menu_number=$CONTAINER_MENU_ITEMS
    for i in "${!hot_cmds[@]}"; do
        cmd_color_code=$(generate_color_code "$venv_name:${hot_cmds[$i]}")
        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmds[$i]}"
        menu_number=$((menu_number+1))
    done

    read -p "Enter command number to remove (or press Enter to cancel): " remove_num

    if [ -z "$remove_num" ]; then
        echo "Operation cancelled."
        return
    fi

    # Convert menu number (6+) to array index
    if [[ "$remove_num" =~ ^[0-9]+$ ]] && [ "$remove_num" -ge $CONTAINER_MENU_ITEMS ] && [ "$remove_num" -le $(($CONTAINER_MENU_ITEMS - 1 + ${#hot_cmds[@]})) ]; then
        # Calculate the array index from the menu number
        local array_index=$((remove_num - $CONTAINER_MENU_ITEMS))
        local line_to_remove=${hot_cmd_lines[$array_index]}

        # Create a temp file and remove the line
        temp_file=$(mktemp)
        sed "${line_to_remove}d" "$HOTCMDS_FILE" > "$temp_file"
        mv "$temp_file" "$HOTCMDS_FILE"
        echo -e "\033[1;32mHot command removed successfully.\033[0m"
    else
        echo "Invalid selection."
    fi

    echo "Press Enter to continue..."
    read
}

execute_hot_command() {
    local venv_name="$1"
    local command_num="$2"
    local venv_path="$3"

    # echo "Debug: venv_name=$venv_name, command_num=$command_num, CONTAINER_MENU_ITEMS=$CONTAINER_MENU_ITEMS"

    # Get all hot commands for this venv
    local hot_cmds=()
    while IFS= read -r line; do
        if [[ "$line" == "$venv_name:"* ]]; then
            hot_cmds+=("${line#*:}")

            # echo "Debug: Added hot command: ${line#*:}"
        fi
    done < "$HOTCMDS_FILE"

    # echo "Debug: Total hot commands found: ${#hot_cmds[@]}"

    # Convert the menu number to array index using the global CONTAINER_MENU_ITEMS
    local array_index=$((command_num - $CONTAINER_MENU_ITEMS))

    # echo "Debug: array_index=$array_index"

    # Check if index is valid
    if [ "$array_index" -ge 0 ] && [ "$array_index" -lt "${#hot_cmds[@]}" ]; then
        local command="${hot_cmds[$array_index]}"

        # echo "Debug: Executing command: $command"

        source "${venv_path}/bin/activate"

        # Execute global startup commands if they exist
        if [ -s "$GLOBAL_STARTUP_CMDS_FILE" ]; then
            while IFS= read -r startup_cmd; do
                eval "$startup_cmd"
            done < "$GLOBAL_STARTUP_CMDS_FILE"
        fi

        # Execute container-specific startup commands if they exist
        if [ -s "$CONTAINER_STARTUP_CMDS_FILE" ]; then
            while IFS=: read -r env cmd || [ -n "$env" ]; do
                if [ "$env" = "$venv_name" ]; then
                    eval "$cmd"
                fi
            done < "$CONTAINER_STARTUP_CMDS_FILE"
        fi

        # Set working directory if configured
        if [ -f "${venv_path}/working_directory.cfg" ]; then
            working_dir=$(cat "${venv_path}/working_directory.cfg")
            use_working_dir=$(cat "${venv_path}/use_working_dir_for_hot_commands.cfg" 2>/dev/null || echo "no")
            if [ -n "$working_dir" ] && [ -d "$working_dir" ] && [ "$use_working_dir" = "yes" ]; then
                pushd "$working_dir" > /dev/null
                eval "$command"
                popd > /dev/null
            else
                eval "$command"
            fi
        else
            eval "$command"
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

            echo "Virtual environment $selected_venv and its associated files have been deleted."
        else
            echo "Deletion aborted: name did not match."
        fi
    else
        echo "Invalid choice"
    fi
}

# Main Loop
while true; do
    clear
    venv_dir=$(get_venv_directory)
    if [ $? -ne 0 ]; then
        echo "Error: Could not determine venv directory."
        exit 1
    fi

    venvs=($(find "$venv_dir" -maxdepth 1 -type d -printf "%f\n" | sort))
    venvs=(${venvs[@]/"$(basename "$venv_dir")"/})
    venvs=(${venvs[@]/*.conda/})

    formatted_venvs=()
    for venv in "${venvs[@]}"; do
        version=$(get_venv_python_version "$venv_dir/$venv")
        formatted_venvs+=("$venv [${version}]")
    done

    display_items formatted_venvs
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
    elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#venvs[@]}" ]; then
        selected_venv="${venvs[$((choice-1))]}"
        venv_path="$venv_dir/$selected_venv"
        manage_item "$selected_venv" "$venv_path"
    else
        echo "Invalid choice"
    fi
done
