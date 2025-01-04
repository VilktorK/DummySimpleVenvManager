#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/BaseManager.sh"

MANAGER_NAME="Venv"
CONFIG_DIR="$HOME/.config/dummysimplevenvmanager"
HOTCMDS_FILE="$CONFIG_DIR/venvhotcmds.cfg"
SETTINGS_FILE="$CONFIG_DIR/settings.cfg"
CONDA_PATH_FILE="$CONFIG_DIR/condapath.cfg"

mkdir -p "$CONFIG_DIR"
touch "$HOTCMDS_FILE"
touch "$SETTINGS_FILE"

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
    echo "Options:"
    echo "1. Create a new venv"
    echo "3. Delete a venv"
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
    if [ -f "${venv_path}working_directory.cfg" ]; then
        echo "Working Directory: $(cat "${venv_path}working_directory.cfg")"
    fi
}


display_options_and_commands() {
    local venv_name="$1"
    local venv_path="$2"
    local color_code=$(generate_color_code "$venv_name")
    echo -e "\n${color_code}Managing venv: $venv_name\033[0m"
    show_venv_info "$venv_path"
    echo "Options:"
    echo "1. Enter venv"
    echo "2. Modify venv hot commands"
    echo "3. Set working directory"
    echo "4. Show launch script"
    echo "0. Back to main menu"
    echo "------------------------------"
    echo "Hot commands:"
    if [ -f "$HOTCMDS_FILE" ]; then
        local i=4
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
        2)  # New case
            delete_venv
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
            set_working_directory "$venv_path"
            ;;
        4)
            show_launch_script "$venv_name" "$venv_path"
            ;;
        0)
            return 2 
            ;;
        *)
            if [ "$option" -gt 4 ]; then
                hot_cmd_num=$((option - 4))
                execute_hot_command "$venv_name" "$hot_cmd_num" "$venv_path"
            else
                echo "Invalid choice"
                echo "Press Enter to continue..."
                read
            fi
            ;;
    esac
}

create_new_venv() {
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
    
    source "${venv_path}/bin/activate"
    if [ -f "${venv_path}working_directory.cfg" ]; then
        working_dir=$(cat "${venv_path}working_directory.cfg")
        if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
            cd "$working_dir"
        fi
    fi
    color_code=$(generate_color_code "$venv_name")
    echo -e "${color_code}Activated venv: $venv_name\033[0m"
    bash --init-file <(echo '
        source "'${venv_path}'/bin/activate"
        PS1="('$venv_name') \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
        alias deactivate="command deactivate && exit"
    ')
    cd "$PWD" 
}

delete_venv() {
    display_items formatted_venvs
    read -p "Enter the number of the venv to delete: " delete_choice
    
    if [ "$delete_choice" -ge 1 ] && [ "$delete_choice" -le "${#venvs[@]}" ]; then
        selected_venv="${venvs[$((delete_choice-1))]}"
        
        # Safety check 1: Ensure the name doesn't contain dangerous characters
        if echo "$selected_venv" | grep -q '[/;:|]'; then
            echo "Error: Venv name contains invalid characters"
            return 1
        fi  # Fixed the extra curly brace here
        
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
            
            echo "Virtual environment $selected_venv and its associated files have been deleted."
        else
            echo "Deletion aborted: name did not match."
        fi
    else
        echo "Invalid choice"
    fi
}

set_working_directory() {
    local venv_path="$1"
    read -p "Enter the working directory (leave blank to clear): " working_dir
    if [ -n "$working_dir" ]; then
        echo "$working_dir" > "${venv_path}working_directory.cfg"
        echo "Working directory set to: $working_dir"
        
        read -p "Execute hot commands in this working directory? (yes/no): " use_working_dir
        echo "$use_working_dir" > "${venv_path}use_working_dir_for_hot_commands.cfg"
        echo "Hot commands will $([ "$use_working_dir" = "yes" ] && echo "be executed" || echo "not be executed") in the working directory."
    else
        rm -f "${venv_path}working_directory.cfg"
        rm -f "${venv_path}use_working_dir_for_hot_commands.cfg"
        echo "Working directory cleared"
    fi
}

show_launch_script() {
    local venv_name="$1"
    local venv_path="$2"
    local working_dir=""
    if [ -f "${venv_path}working_directory.cfg" ]; then
        working_dir=$(cat "${venv_path}working_directory.cfg")
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
    local command=$(grep "^$venv_name:" "$HOTCMDS_FILE" | sed -n "${command_num}p" | cut -d: -f2-)
    
    if [ -n "$command" ]; then
        source "${venv_path}/bin/activate"
        if [ -f "${venv_path}working_directory.cfg" ]; then
            working_dir=$(cat "${venv_path}working_directory.cfg")
            use_working_dir=$(cat "${venv_path}use_working_dir_for_hot_commands.cfg")
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

# Main Loop
while true; do
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
