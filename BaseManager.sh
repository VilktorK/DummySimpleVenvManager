#!/bin/bash

# Dont let script be run by itself
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "This script should be inherited from by other scripts and not executed directly."
    exit 1
fi

BASE_CONFIG_DIR="$HOME/.config"
MANAGER_NAME="" # Should be set by inheriting script
CONFIG_DIR="" # Should be set by inheriting script
HOTCMDS_FILE="" # Should be set by inheriting script

# Generate random colors for entries
generate_color_code() {
    local input_string="$1"
    local hash=$(echo "$input_string" | md5sum | cut -c 1-6)
    local color_code="\033[38;5;$((16 + $(printf "%d" 0x$hash) % 231))m"
    echo "$color_code"
}

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

add_hot_command() {
    local item_name="$1"
    read -p "Enter the new hot command (or press Enter to cancel): " new_command
    if [ -z "$new_command" ]; then
        echo "Hot command add canceled."
        return
    fi
    echo "$item_name:$new_command" >> "$HOTCMDS_FILE"
    echo "Hot command add successfully."
}

remove_hot_command() {
    local item_name="$1"
    mapfile -t commands < <(grep "^$item_name:" "$HOTCMDS_FILE" | cut -d: -f2-)
    local num_commands=${#commands[@]}

    if [ $num_commands -eq 0 ]; then
        echo "No hot commands found."
        return
    fi

    echo "Current hot commands:"
    for ((i=0; i<num_commands; i++)); do
        cmd_color_code=$(generate_color_code "$item_name:${commands[i]}")
        printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$((i+1))" "${commands[i]}"
    done

    read -p "Enter the number of the hot command to remove (or press Enter to cancel): " remove_num
    if [ -z "$remove_num" ]; then
        echo "Hot command removal canceled."
        return
    fi

    if [ "$remove_num" -ge 1 ] && [ "$remove_num" -le "$num_commands" ]; then
        temp_file=$(mktemp)
        grep -v "^$item_name:${commands[$((remove_num-1))]}$" "$HOTCMDS_FILE" > "$temp_file"
        mv "$temp_file" "$HOTCMDS_FILE"
        echo "Hot command removed successfully."
    else
        echo "Invalid selection."
    fi
}

execute_hot_command() {
    local item_name="$1"
    local command_num="$2"
    local command=$(grep "^$item_name:" "$HOTCMDS_FILE" | sed -n "${command_num}p" | cut -d: -f2-)
    
    if [ -n "$command" ]; then
        eval "$command"
        echo "Hot command executed. Press Enter to continue..."
        read
    else
        echo "Invalid hot command number."
        echo "Press Enter to continue..."
        read
    fi
}

display_options_and_commands() {
    local item_name="$1"
    local color_code=$(generate_color_code "$item_name")
    echo -e "\n${color_code}Managing ${MANAGER_NAME}: $item_name\033[0m"
    
    echo "Error: display_options_and_commands must be implemented by the inheriting script"
    return 1
}

manage_item() {
    local item_name="$1"
    local extra_args=("${@:2}") 
    
    while true; do
        display_options_and_commands "$item_name"
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

handle_options_menu() {
    while true; do
        display_options_menu
        read -p "Enter your choice: " option_choice
        
        if [ -z "$option_choice" ]; then
            continue
        fi
        
        case $option_choice in
            0)
                return 0
                ;;
            *)
                handle_custom_options "$option_choice"
                local custom_return=$?
                if [ $custom_return -eq 2 ]; then
                    return 2
                fi
                ;;
        esac
    done
}

display_options_menu() {
    echo "Error: display_options_menu must be implemented by the inheriting script"
    return 1
}

handle_custom_options() {
    echo "Error: handle_custom_options must be implemented by the inheriting script"
    return 1
}

handle_option() {
    echo "Error: handle_option must be implemented by the inheriting script"
    return 1
}
