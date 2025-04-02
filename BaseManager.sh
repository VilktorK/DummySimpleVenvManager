#!/bin/bash

# Don't let script be run by itself
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "This script should be inherited from by other scripts and not executed directly."
    exit 1
fi

# Base Configuration Variables - Should be overridden by inheriting script
MANAGER_NAME="" # Should be set by inheriting script
CONFIG_DIR="" # Should be set by inheriting script
HOTCMDS_FILE="" # Should be set by inheriting script
SETTINGS_FILE="" # Should be set by inheriting script
GLOBAL_STARTUP_CMDS_FILE="" # Should be set by inheriting script
CONTAINER_STARTUP_CMDS_FILE="" # Should be set by inheriting script
LAST_ACCESS_FILE="" # Should be set by inheriting script
CREATION_TIME_FILE="" # Should be set by inheriting script

# Default number of entries in the container's menu (can be overridden)
CONTAINER_MENU_ITEMS=6

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

# Generate random colors for entries
generate_color_code() {
    local input_string="$1"
    local hash=$(echo "$input_string" | md5sum | cut -c 1-6)
    local color_code="\033[38;5;$((16 + $(printf "%d" 0x$hash) % 231))m"
    echo "$color_code"
}

# Ensure necessary directories and files exist
ensure_config_files() {
    mkdir -p "$CONFIG_DIR"

    if [ -n "$HOTCMDS_FILE" ]; then
        touch "$HOTCMDS_FILE"
    fi

    if [ -n "$SETTINGS_FILE" ]; then
        touch "$SETTINGS_FILE"
    fi

    if [ -n "$GLOBAL_STARTUP_CMDS_FILE" ]; then
        touch "$GLOBAL_STARTUP_CMDS_FILE"
    fi

    if [ -n "$CONTAINER_STARTUP_CMDS_FILE" ]; then
        touch "$CONTAINER_STARTUP_CMDS_FILE"
    fi

    if [ -n "$LAST_ACCESS_FILE" ]; then
        touch "$LAST_ACCESS_FILE"
    fi

    if [ -n "$CREATION_TIME_FILE" ]; then
        touch "$CREATION_TIME_FILE"
    fi
}

# ==========================================
# DISPLAY AND UI FUNCTIONS
# ==========================================

# Display list of items with coloring
display_items() {
    if [ -z "$1" ]; then
        echo "No items array provided"
        return 1
    fi
    local -n items=$1

    echo "Available ${MANAGER_NAME}s:"
    for i in "${!items[@]}"; do
        item_name="${items[i]}"
        color_code=$(generate_color_code "$item_name")
        printf "%d. %b%s\033[0m\n" "$((i+1))" "$color_code" "$item_name"
    done
    echo -e "\n0. Options"
}

# ==========================================
# SORTING SYSTEM FUNCTIONS
# ==========================================

# Function to get the current sort method
get_sort_method() {
    if [ -f "$SETTINGS_FILE" ]; then
        sort_method=$(grep "^SORT_METHOD=" "$SETTINGS_FILE" | cut -d= -f2)
        if [ -z "$sort_method" ]; then
            echo "alphabetical"  # Default to alphabetical sorting
        else
            echo "$sort_method"
        fi
    else
        echo "alphabetical"  # Default to alphabetical sorting
    fi
}

# Function to set the sort method
set_sort_method() {
    local new_method="$1"
    local valid_methods=("alphabetical" "creation_time" "last_used")

    # Validate the method
    local valid=0
    for method in "${valid_methods[@]}"; do
        if [ "$new_method" = "$method" ]; then
            valid=1
            break
        fi
    done

    if [ $valid -eq 0 ]; then
        echo "Invalid sort method: $new_method"
        return 1
    fi

    # Update the settings file
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "^SORT_METHOD=" "$SETTINGS_FILE"; then
            # Replace existing setting
            local temp_file=$(mktemp)
            sed "s/^SORT_METHOD=.*/SORT_METHOD=$new_method/" "$SETTINGS_FILE" > "$temp_file"
            mv "$temp_file" "$SETTINGS_FILE"
        else
            # Add new setting
            echo "SORT_METHOD=$new_method" >> "$SETTINGS_FILE"
        fi
    else
        # Create new settings file
        echo "SORT_METHOD=$new_method" > "$SETTINGS_FILE"
    fi

    echo "Sort method set to: $new_method"
    return 0
}

# Function to update the last access time for an item
update_last_access() {
    local item_name="$1"
    local current_timestamp=$(date +%s)

    # Only update if the item doesn't exist in the file or if it's been more than 1 minute
    if [ -f "$LAST_ACCESS_FILE" ]; then
        local last_timestamp=$(grep "^$item_name:" "$LAST_ACCESS_FILE" | cut -d: -f2)
        if [ -z "$last_timestamp" ] || [ $((current_timestamp - last_timestamp)) -gt 60 ]; then
            if grep -q "^$item_name:" "$LAST_ACCESS_FILE"; then
                # Replace existing entry
                local temp_file=$(mktemp)
                sed "s/^$item_name:.*/$item_name:$current_timestamp/" "$LAST_ACCESS_FILE" > "$temp_file"
                mv "$temp_file" "$LAST_ACCESS_FILE"
            else
                # Add new entry
                echo "$item_name:$current_timestamp" >> "$LAST_ACCESS_FILE"
            fi
        fi
    else
        # Create new file
        echo "$item_name:$current_timestamp" > "$LAST_ACCESS_FILE"
    fi
}

# Function to get the last access time for an item
get_last_access() {
    local item_name="$1"

    if [ -f "$LAST_ACCESS_FILE" ]; then
        local timestamp=$(grep "^$item_name:" "$LAST_ACCESS_FILE" | cut -d: -f2)
        if [ -z "$timestamp" ]; then
            echo "0"  # Default to 0 if not found
        else
            echo "$timestamp"
        fi
    else
        echo "0"  # Default to 0 if file doesn't exist
    fi
}

# Function to set the creation time for an item
set_creation_time() {
    local item_name="$1"
    local timestamp=$(date +%s)

    if [ -f "$CREATION_TIME_FILE" ]; then
        if grep -q "^$item_name:" "$CREATION_TIME_FILE"; then
            # Replace existing entry
            local temp_file=$(mktemp)
            sed "s/^$item_name:.*/$item_name:$timestamp/" "$CREATION_TIME_FILE" > "$temp_file"
            mv "$temp_file" "$CREATION_TIME_FILE"
        else
            # Add new entry
            echo "$item_name:$timestamp" >> "$CREATION_TIME_FILE"
        fi
    else
        # Create new file
        echo "$item_name:$timestamp" > "$CREATION_TIME_FILE"
    fi
}

# Function to get the creation time for an item (base implementation)
# Note: This may need to be overridden for specific directory paths
get_creation_time() {
    local item_name="$1"

    if [ -f "$CREATION_TIME_FILE" ]; then
        local timestamp=$(grep "^$item_name:" "$CREATION_TIME_FILE" | cut -d: -f2)
        if [ -n "$timestamp" ]; then
            echo "$timestamp"
        else
            echo "0"  # Default to 0 if not found
        fi
    else
        echo "0"  # Default to 0 if file doesn't exist
    fi
}

# Function to sort items by creation time
sort_items_by_creation_time() {
    local -n items_ref="$1"
    local item_times=()

    # Collect items and their creation times
    for item in "${items_ref[@]}"; do
        item_times+=("$item:$(get_creation_time "$item")")
    done

    # Sort by creation time (newest first)
    IFS=$'\n' item_times=($(sort -t: -k2 -nr <<<"${item_times[*]}"))

    # Extract the sorted items
    items_ref=()
    for item_time in "${item_times[@]}"; do
        items_ref+=("${item_time%%:*}")
    done
}

# Function to sort items by last access time
sort_items_by_last_access() {
    local -n items_ref="$1"
    local item_times=()

    # Collect items and their last access times
    for item in "${items_ref[@]}"; do
        item_times+=("$item:$(get_last_access "$item")")
    done

    # Sort by last access time (most recent first)
    IFS=$'\n' item_times=($(sort -t: -k2 -nr <<<"${item_times[*]}"))

    # Extract the sorted items
    items_ref=()
    for item_time in "${item_times[@]}"; do
        items_ref+=("${item_time%%:*}")
    done
}

# Function to manage sorting preferences
manage_sorting_preferences() {
    clear
    echo -e "\n\033[1;36mManage Sorting Preferences\033[0m"
    echo -e "\033[90m----------------------------------------\033[0m"

    local current_method=$(get_sort_method)

    echo "Current sorting method: $current_method"
    echo ""
    echo "Available sorting methods:"
    echo "1. Alphabetical"
    echo "2. Most recently created"
    echo "3. Most recently used"
    echo "0. Return to options"

    read -p "Enter your choice: " sort_choice

    case $sort_choice in
        1)
            set_sort_method "alphabetical"
            ;;
        2)
            set_sort_method "creation_time"
            ;;
        3)
            set_sort_method "last_used"
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac

    echo "Press Enter to continue..."
    read
}

# ==========================================
# STARTUP COMMANDS MANAGEMENT
# ==========================================

# Function to manage global startup commands
manage_global_startup_commands() {
    clear
    echo -e "\n\033[1;36mManage Global $MANAGER_NAME Startup Commands\033[0m"
    echo "These commands will run automatically when any $MANAGER_NAME is activated"
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
    read -p "Enter the command to run at ${MANAGER_NAME} activation (for all ${MANAGER_NAME}s): " new_cmd

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
    local item_name="$1"
    clear

    echo -e "\n\033[1;36mManage Container-Specific Startup Commands for $item_name\033[0m"
    echo "These commands will run automatically when this specific ${MANAGER_NAME} is activated"
    echo -e "\033[90m----------------------------------------\033[0m"

    # Display current container-specific commands
    local container_cmds=()
    if [ -s "$CONTAINER_STARTUP_CMDS_FILE" ]; then
        while IFS=: read -r env cmd || [ -n "$env" ]; do
            if [ "$env" = "$item_name" ]; then
                container_cmds+=("$cmd")
            fi
        done < "$CONTAINER_STARTUP_CMDS_FILE"
    fi

    if [ ${#container_cmds[@]} -gt 0 ]; then
        echo "Current container-specific startup commands for $item_name:"
        for i in "${!container_cmds[@]}"; do
            cmd_color_code=$(generate_color_code "${container_cmds[$i]}")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$((i+1))" "${container_cmds[$i]}"
        done
    else
        echo "No container-specific startup commands configured for $item_name."
    fi

    echo -e "\n1. Add container-specific startup command"
    echo "2. Remove container-specific startup command"
    echo "0. Return to container menu"

    read -p "Enter your choice: " cmd_option
    case $cmd_option in
        1)
            add_container_startup_command "$item_name"
            ;;
        2)
            remove_container_startup_command "$item_name"
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
    local item_name="$1"
    read -p "Enter the command to run at activation for $item_name: " new_cmd

    if [ -z "$new_cmd" ]; then
        echo "Operation cancelled."
        return
    fi

    echo "$item_name:$new_cmd" >> "$CONTAINER_STARTUP_CMDS_FILE"
    echo -e "\033[1;32mContainer-specific startup command added successfully.\033[0m"
    echo "Press Enter to continue..."
    read
}

remove_container_startup_command() {
    local item_name="$1"
    local container_cmds=()
    local container_cmd_lines=()
    local line_num=1

    # Collect commands and their line numbers
    while IFS=: read -r env cmd || [ -n "$env" ]; do
        if [ "$env" = "$item_name" ]; then
            container_cmds+=("$cmd")
            container_cmd_lines+=("$line_num")
        fi
        line_num=$((line_num+1))
    done < "$CONTAINER_STARTUP_CMDS_FILE"

    if [ ${#container_cmds[@]} -eq 0 ]; then
        echo "No container-specific startup commands to remove for $item_name."
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

# ==========================================
# HOT COMMANDS MANAGEMENT
# ==========================================

# Add a hot command to an item
add_hot_command() {
    local item_name="$1"
    read -p "Enter the new hot command (or press Enter to cancel): " new_command
    if [ -z "$new_command" ]; then
        echo "Hot command add canceled."
        return
    fi
    echo "$item_name:$new_command" >> "$HOTCMDS_FILE"
    echo "Hot command added successfully."
    echo "Press Enter to continue..."
    read
}

# Base function to remove a hot command
# Can be overridden for custom menu numbering
remove_hot_command() {
    local item_name="$1"
    clear
    local hot_cmds=()
    local hot_cmd_lines=()
    local line_num=1

    # Collect commands and their line numbers
    while IFS=: read -r name cmd || [ -n "$name" ]; do
        if [ "$name" = "$item_name" ]; then
            hot_cmds+=("$cmd")
            hot_cmd_lines+=("$line_num")
        fi
        line_num=$((line_num+1))
    done < "$HOTCMDS_FILE"

    if [ ${#hot_cmds[@]} -eq 0 ]; then
        echo "No hot commands to remove for $item_name."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a hot command to remove:"

    # Display commands with their menu numbers
    local menu_number=$CONTAINER_MENU_ITEMS
    for i in "${!hot_cmds[@]}"; do
        cmd_color_code=$(generate_color_code "$item_name:${hot_cmds[$i]}")
        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmds[$i]}"
        menu_number=$((menu_number+1))
    done

    read -p "Enter command number to remove (or press Enter to cancel): " remove_num

    if [ -z "$remove_num" ]; then
        echo "Operation cancelled."
        return
    fi

    # Convert menu number to array index
    if [[ "$remove_num" =~ ^[0-9]+$ ]] && [ "$remove_num" -ge $CONTAINER_MENU_ITEMS ] && [ "$remove_num" -le $(($CONTAINER_MENU_ITEMS - 1 + ${#hot_cmds[@]})) ]; then
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

# ==========================================
# ITEM MANAGEMENT FUNCTIONS
# ==========================================

# Main function to manage an item - this orchestrates the menu loop
manage_item() {
    local item_name="$1"
    local extra_args=("${@:2}")

    while true; do
        display_options_and_commands "$item_name" "${extra_args[@]}"
        read -p "Enter your choice: " option

        if [ -z "$option" ]; then
            continue
        fi

        handle_option "$item_name" "$option" "${extra_args[@]}"

        if [ $? -eq 2 ]; then
            break
        fi
    done
}

# Function to handle the options menu
handle_options_menu() {
    while true; do
        display_options_menu
        read -p "Enter your choice: " option_choice

        if [ -z "$option_choice" ]; then
            continue
        fi

        if [ "$option_choice" -eq 0 ]; then
            return 0
        else
            handle_custom_options "$option_choice"
            local custom_return=$?
            if [ $custom_return -eq 2 ]; then
                return 2
            fi
        fi
    done
}

# ==========================================
# FUNCTIONS THAT MUST BE IMPLEMENTED BY CHILD SCRIPTS
# ==========================================

# Must be implemented by inheriting script - shows options for a specific item
display_options_and_commands() {
    local item_name="$1"
    echo "Error: display_options_and_commands must be implemented by the inheriting script"
    return 1
}

# Must be implemented by inheriting script - shows main options menu
display_options_menu() {
    echo "Error: display_options_menu must be implemented by the inheriting script"
    return 1
}

# Must be implemented by inheriting script - handles options menu selections
handle_custom_options() {
    echo "Error: handle_custom_options must be implemented by the inheriting script"
    return 1
}

# Must be implemented by inheriting script - handles item-specific menu selections
handle_option() {
    echo "Error: handle_option must be implemented by the inheriting script"
    return 1
}

# ==========================================
# INITIALIZATION
# ==========================================

# Initialize the base manager
initialize_base_manager() {
    ensure_config_files
}

# Call initialization when sourced
initialize_base_manager
