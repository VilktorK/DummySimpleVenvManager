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
FAVORITES_FILE="" # Should be set by inheriting script

# Default number of entries in the container's menu (can be overridden)
CONTAINER_MENU_ITEMS=6

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

# Get the current color mode
get_color_mode() {
    if [ -f "$SETTINGS_FILE" ]; then
        color_mode=$(grep "^COLOR_MODE=" "$SETTINGS_FILE" | cut -d= -f2)
        if [ -z "$color_mode" ]; then
            echo "dark"  # Default to dark mode
        else
            echo "$color_mode"
        fi
    else
        echo "dark"  # Default to dark mode
    fi
}

# Set the color mode
set_color_mode() {
    local new_mode="$1"
    local valid_modes=("dark" "light" "monochrome")

    # Validate the mode
    local valid=0
    for mode in "${valid_modes[@]}"; do
        if [ "$new_mode" = "$mode" ]; then
            valid=1
            break
        fi
    done

    if [ $valid -eq 0 ]; then
        echo "Invalid color mode: $new_mode"
        return 1
    fi

    # Update the settings file
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "^COLOR_MODE=" "$SETTINGS_FILE"; then
            # Replace existing setting
            local temp_file=$(mktemp)
            sed "s/^COLOR_MODE=.*/COLOR_MODE=$new_mode/" "$SETTINGS_FILE" > "$temp_file"
            mv "$temp_file" "$SETTINGS_FILE"
        else
            # Add new setting
            echo "COLOR_MODE=$new_mode" >> "$SETTINGS_FILE"
        fi
    else
        # Create new settings file
        echo "COLOR_MODE=$new_mode" > "$SETTINGS_FILE"
    fi

    echo "Color mode set to: $new_mode"
    return 0
}

# Generate color based on the input string and current color mode
generate_color_code() {
    local input_string="$1"
    local color_mode=$(get_color_mode)

    if [ "$color_mode" = "monochrome" ]; then
        # No color in monochrome mode
        echo ""
        return 0
    fi

    # Use hash to generate a predictable but seemingly random color
    local hash=$(echo "$input_string" | md5sum | cut -c 1-6)
    local hash_dec=$(printf "%d" 0x$hash)

    # Use simpler approach - pick from a set of predefined vivid colors
    # We'll use 16 base colors that look good in terminals
    local color_index=$((hash_dec % 16))

    # Define RGB components for our 16 vivid colors
    local r=0
    local g=0
    local b=0

    case $color_index in
        0)  r=5; g=0; b=0 ;;    # Red
        1)  r=5; g=2; b=0 ;;    # Orange
        2)  r=5; g=5; b=0 ;;    # Yellow
        3)  r=3; g=5; b=0 ;;    # Lime
        4)  r=0; g=5; b=0 ;;    # Green
        5)  r=0; g=5; b=2 ;;    # Spring Green
        6)  r=0; g=5; b=5 ;;    # Cyan
        7)  r=0; g=2; b=5 ;;    # Light Blue
        8)  r=0; g=0; b=5 ;;    # Blue
        9)  r=2; g=0; b=5 ;;    # Purple
        10) r=5; g=0; b=5 ;;    # Magenta
        11) r=5; g=0; b=2 ;;    # Pink
        12) r=4; g=3; b=0 ;;    # Gold
        13) r=3; g=0; b=3 ;;    # Plum
        14) r=0; g=3; b=3 ;;    # Teal
        15) r=3; g=4; b=5 ;;    # Light Steel Blue
    esac

    # Add slight variation based on another part of the hash
    local variation=$(($(printf "%d" 0x${hash:3:2}) % 3))
    local mod_r=$r
    local mod_g=$g
    local mod_b=$b

    # Small modifications to create more variety
    case $variation in
        1)  # Slightly darker
            mod_r=$((r > 0 ? r - 1 : 0))
            mod_g=$((g > 0 ? g - 1 : 0))
            mod_b=$((b > 0 ? b - 1 : 0))
            ;;
        2)  # Slightly different hue
            local shift=$(($(printf "%d" 0x${hash:5:1}) % 3))
            if [ $shift -eq 0 ]; then
                mod_r=$((r > 0 ? r - 1 : 0))
            elif [ $shift -eq 1 ]; then
                mod_g=$((g > 0 ? g - 1 : 0))
            else
                mod_b=$((b > 0 ? b - 1 : 0))
            fi
            ;;
    esac

    # Now adjust based on color mode
    if [ "$color_mode" = "dark" ]; then
        # For dark mode: Ensure brightness is sufficient
        # Check if all components are below threshold
        local all_low=1
        if [ $mod_r -ge 3 ] || [ $mod_g -ge 3 ] || [ $mod_b -ge 3 ]; then
            all_low=0
        fi

        # If all components are low, boost the highest one
        if [ $all_low -eq 1 ]; then
            if [ $mod_r -ge $mod_g ]; then
                if [ $mod_r -ge $mod_b ]; then
                    mod_r=4  # Boost red
                else
                    mod_b=4  # Boost blue
                fi
            else
                if [ $mod_g -ge $mod_b ]; then
                    mod_g=4  # Boost green
                else
                    mod_b=4  # Boost blue
                fi
            fi
        fi
    else
        # For light mode: Ensure there's enough contrast
        # Cap maximum brightness
        if [ $mod_r -gt 3 ]; then mod_r=3; fi
        if [ $mod_g -gt 3 ]; then mod_g=3; fi
        if [ $mod_b -gt 3 ]; then mod_b=3; fi

        # Check if all components are above threshold
        local all_high=1
        if [ $mod_r -le 1 ] || [ $mod_g -le 1 ] || [ $mod_b -le 1 ]; then
            all_high=0
        fi

        # If all components are high, lower the lowest one
        if [ $all_high -eq 1 ]; then
            if [ $mod_r -le $mod_g ]; then
                if [ $mod_r -le $mod_b ]; then
                    mod_r=0  # Lower red
                else
                    mod_b=0  # Lower blue
                fi
            else
                if [ $mod_g -le $mod_b ]; then
                    mod_g=0  # Lower green
                else
                    mod_b=0  # Lower blue
                fi
            fi
        fi
    fi

    # Calculate the color code
    local color_num=$((16 + 36*mod_r + 6*mod_g + mod_b))

    local color_code="\033[38;5;${color_num}m"
    echo "$color_code"
}

# Manage color mode preferences
manage_color_mode() {
    clear
    echo -e "\n\033[1;36mManage Color Mode\033[0m"
    echo -e "\033[90m----------------------------------------\033[0m"

    local current_mode=$(get_color_mode)

    echo "Current color mode: $current_mode"
    echo ""
    echo "Available color modes:"
    echo "1. Dark mode (light colored text for dark terminals)"
    echo "2. Light mode (dark colored text for light terminals)"
    echo "3. Monochrome (no colors)"
    echo "0. Return to options"

    read -p "Enter your choice: " color_choice

    case $color_choice in
        1)
            set_color_mode "dark"
            ;;
        2)
            set_color_mode "light"
            ;;
        3)
            set_color_mode "monochrome"
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

# Ask for color mode preference during first-time setup
prompt_for_color_mode() {
    echo -e "\n\033[1;36mColor Mode Selection\033[0m"
    echo -e "\033[90m----------------------------------------\033[0m"
    echo "Please select your preferred color mode:"
    echo "1. Dark mode (light colored text for dark terminals)"
    echo "2. Light mode (dark colored text for light terminals)"
    echo "3. Monochrome (no colors)"

    local valid_selection=0
    while [ $valid_selection -eq 0 ]; do
        read -p "Enter your choice (1-3): " color_choice

        case $color_choice in
            1)
                set_color_mode "dark"
                valid_selection=1
                ;;
            2)
                set_color_mode "light"
                valid_selection=1
                ;;
            3)
                set_color_mode "monochrome"
                valid_selection=1
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done

    echo -e "\033[1;32mColor mode set successfully!\033[0m"
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

    if [ -n "$FAVORITES_FILE" ]; then
        touch "$FAVORITES_FILE"
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
# FAVORITES SYSTEM FUNCTIONS
# ==========================================

# Check if an item is marked as a favorite
is_favorite() {
    local item_name="$1"

    # Check if favorites file exists
    if [ ! -f "$FAVORITES_FILE" ]; then
        return 1
    fi

    # Check if item is in favorites
    if grep -q "^$item_name$" "$FAVORITES_FILE"; then
        return 0
    else
        return 1
    fi
}

# Toggle an item's favorite status
toggle_favorite() {
    local item_name="$1"

    if is_favorite "$item_name"; then
        # Remove from favorites
        local temp_file=$(mktemp)
        grep -v "^$item_name$" "$FAVORITES_FILE" > "$temp_file"
        mv "$temp_file" "$FAVORITES_FILE"
        echo "Removed '$item_name' from favorites."
    else
        # Add to favorites
        echo "$item_name" >> "$FAVORITES_FILE"
        echo "Added '$item_name' to favorites."
    fi
}

# Get the list of favorites from all available items
get_favorites() {
    local -n all_items_ref="$1"
    local -n favorites_ref="$2"

    favorites_ref=()

    # Check if favorites file exists
    if [ ! -f "$FAVORITES_FILE" ] || [ ! -s "$FAVORITES_FILE" ]; then
        return 0
    fi

    # Get all favorites that exist in all_items
    while IFS= read -r favorite; do
        for item in "${all_items_ref[@]}"; do
            if [ "$item" = "$favorite" ]; then
                favorites_ref+=("$item")
                break
            fi
        done
    done < "$FAVORITES_FILE"

    # Sort favorites based on current sort method
    if [ ${#favorites_ref[@]} -gt 0 ]; then
        sort_method=$(get_sort_method)
        case $sort_method in
            alphabetical)
                # Sort alphabetically
                IFS=$'\n' favorites_ref=($(sort <<<"${favorites_ref[*]}"))
                ;;
            creation_time)
                # Sort by creation time
                sort_items_by_creation_time favorites_ref
                ;;
            last_used)
                # Sort by last access time
                sort_items_by_last_access favorites_ref
                ;;
        esac
    fi

    return 0
}

# Display items with favorites section at the top
display_items_with_favorites() {
    if [ -z "$1" ]; then
        echo "No items array provided"
        return 1
    fi
    local -n items_ref=$1
    local -a favorites=()
    local -a non_favorites=()

    # Get favorites
    get_favorites items_ref favorites

    # Get non-favorites
    for item in "${items_ref[@]}"; do
        local is_fav=0
        for fav in "${favorites[@]}"; do
            if [ "$item" = "$fav" ]; then
                is_fav=1
                break
            fi
        done
        if [ $is_fav -eq 0 ]; then
            non_favorites+=("$item")
        fi
    done

    # Display favorites if there are any
    if [ ${#favorites[@]} -gt 0 ]; then
        echo "Favorites:"
        for i in "${!favorites[@]}"; do
            item_name="${favorites[i]}"
            color_code=$(generate_color_code "$item_name")
            printf "%d. %b%s\033[0m\n" "$((i+1))" "$color_code" "$item_name"
        done
        echo ""
    fi

    echo "Available ${MANAGER_NAME}s:"
    # Start numbering after favorites
    local start_num=$((${#favorites[@]} + 1))
    for i in "${!non_favorites[@]}"; do
        item_name="${non_favorites[i]}"
        color_code=$(generate_color_code "$item_name")
        printf "%d. %b%s\033[0m\n" "$((start_num + i))" "$color_code" "$item_name"
    done
    echo -e "\n0. Options"
}

# Get the actual item from a selection number
get_item_from_selection() {
    local selection="$1"
    local -n all_items_ref="$2"
    local -n result_ref="$3"

    # Get favorites
    local -a favorites=()
    get_favorites all_items_ref favorites

    # Check if selection is in favorites range
    if [ "$selection" -ge 1 ] && [ "$selection" -le "${#favorites[@]}" ]; then
        result_ref="${favorites[$((selection-1))]}"
        return 0
    fi

    # Get non-favorites
    local -a non_favorites=()
    for item in "${all_items_ref[@]}"; do
        local is_fav=0
        for fav in "${favorites[@]}"; do
            if [ "$item" = "$fav" ]; then
                is_fav=1
                break
            fi
        done
        if [ $is_fav -eq 0 ]; then
            non_favorites+=("$item")
        fi
    done

    # Check if selection is in non-favorites range
    local non_fav_index=$((selection - ${#favorites[@]} - 1))
    if [ "$non_fav_index" -ge 0 ] && [ "$non_fav_index" -lt "${#non_favorites[@]}" ]; then
        result_ref="${non_favorites[$non_fav_index]}"
        return 0
    fi

    # Invalid selection
    return 1
}

# Function to manage favorites
manage_favorites_menu() {
    local -n items_ref="$1"

    while true; do
        clear
        echo -e "\n\033[1;36mManage Favorites\033[0m"
        echo -e "\033[90m----------------------------------------\033[0m"

        # Display all items with favorite status
        echo "Current items (★ = favorite):"
        for i in "${!items_ref[@]}"; do
            item="${items_ref[i]}"
            color_code=$(generate_color_code "$item")
            star="  "
            if is_favorite "$item"; then
                star="★ "
            fi
            printf "%d. %s%b%s\033[0m\n" "$((i+1))" "$star" "$color_code" "$item"
        done

        echo -e "\nEnter the number of an item to toggle its favorite status"
        echo "0. Return to options"

        read -p "Enter your choice: " fav_choice

        if [ "$fav_choice" = "0" ]; then
            break
        fi

        # Check if selection is valid
        if [ "$fav_choice" -ge 1 ] && [ "$fav_choice" -le "${#items_ref[@]}" ]; then
            local selected_item="${items_ref[$((fav_choice-1))]}"
            toggle_favorite "$selected_item"
            echo "Press Enter to continue..."
            read
        else
            echo "Invalid choice"
            echo "Press Enter to continue..."
            read
        fi
    done

    return 0
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

    read -p "Enter a name for this command (optional, press Enter to skip): " command_name
    if [ -z "$command_name" ]; then
        # Use default name (the command itself)
        echo "$item_name:$new_command" >> "$HOTCMDS_FILE"
    else
        # Include custom name
        echo "$item_name:$command_name:$new_command" >> "$HOTCMDS_FILE"
    fi

    echo "Hot command added successfully."
    echo "Press Enter to continue..."
    read
}

rename_hot_command() {
    local item_name="$1"
    clear
    local hot_cmds=()
    local hot_cmd_names=()
    local hot_cmd_lines=()
    local line_num=1

    # Collect commands, their names, and line numbers
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        if [ -n "$line" ]; then
            # Extract the box name (everything before first colon)
            local box="${line%%:*}"
            if [ "$box" = "$item_name" ]; then
                # Get everything after the first colon
                local after_first_colon="${line#*:}"
                
                # Check if there's another colon AND it's not part of a URL (indicating new format with custom name)
                if [[ "$after_first_colon" == *:* ]] && [[ "$after_first_colon" != *"://"* ]] && [[ "${after_first_colon#*:}" != *"://"* ]]; then
                    # New format: box:name:command
                    local cmd_name="${after_first_colon%%:*}"
                    local cmd="${after_first_colon#*:}"
                    hot_cmds+=("$cmd")
                    hot_cmd_names+=("$cmd_name")
                else
                    # Old format: box:command
                    hot_cmds+=("$after_first_colon")
                    hot_cmd_names+=("$after_first_colon")  # Default name is the command itself
                fi
                hot_cmd_lines+=("$line_num")
            fi
        fi
        line_num=$((line_num+1))
    done < "$HOTCMDS_FILE"

    if [ ${#hot_cmds[@]} -eq 0 ]; then
        echo "No hot commands to rename for $item_name."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a hot command to rename:"

    # Display commands with their menu numbers and current names
    local menu_number=$CONTAINER_MENU_ITEMS
    for i in "${!hot_cmds[@]}"; do
        if [ "${hot_cmds[$i]}" = "${hot_cmd_names[$i]}" ]; then
            # Command has no custom name yet
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmds[$i]}")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmds[$i]}"
        else
            # Command has a custom name
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmd_names[$i]}")
            printf "%b%d. \"%s\" (%s)\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmd_names[$i]}" "${hot_cmds[$i]}"
        fi
        menu_number=$((menu_number+1))
    done

    read -p "Enter command number to rename (or press Enter to cancel): " rename_num

    if [ -z "$rename_num" ]; then
        echo "Operation cancelled."
        return
    fi

    # Convert menu number to array index
    if [[ "$rename_num" =~ ^[0-9]+$ ]] && [ "$rename_num" -ge $CONTAINER_MENU_ITEMS ] && [ "$rename_num" -le $(($CONTAINER_MENU_ITEMS - 1 + ${#hot_cmds[@]})) ]; then
        local array_index=$((rename_num - $CONTAINER_MENU_ITEMS))
        local line_to_modify=${hot_cmd_lines[$array_index]}
        local current_command="${hot_cmds[$array_index]}"
        local current_name="${hot_cmd_names[$array_index]}"

        echo "Current command: $current_command"
        if [ "$current_command" != "$current_name" ]; then
            echo "Current name: $current_name"
        fi

        read -p "Enter new name for this command (or press Enter to reset to default): " new_name

        # Create a temp file and modify the line
        temp_file=$(mktemp)
        if [ -z "$new_name" ]; then
            # Reset to default (no custom name)
            sed "${line_to_modify}d" "$HOTCMDS_FILE" > "$temp_file"
            echo "$item_name:$current_command" >> "$temp_file"
            echo -e "\033[1;32mHot command name reset to default.\033[0m"
        else
            # Set custom name
            sed "${line_to_modify}d" "$HOTCMDS_FILE" > "$temp_file"
            echo "$item_name:$new_name:$current_command" >> "$temp_file"
            echo -e "\033[1;32mHot command renamed successfully to \"$new_name\".\033[0m"
        fi

        sort "$temp_file" > "$HOTCMDS_FILE"
        rm "$temp_file"
    else
        echo "Invalid selection."
    fi

    echo "Press Enter to continue..."
    read
}

# Edit an existing hot command (name and/or content)
edit_hot_command() {
    local item_name="$1"
    clear
    local hot_cmds=()
    local hot_cmd_names=()
    local hot_cmd_lines=()
    local line_num=1

    # Collect commands, their names, and line numbers
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        if [ -n "$line" ]; then
            # Extract the box name (everything before first colon)
            local box="${line%%:*}"
            if [ "$box" = "$item_name" ]; then
                # Get everything after the first colon
                local after_first_colon="${line#*:}"
                
                # Check if there's another colon AND it's not part of a URL (indicating new format with custom name)
                if [[ "$after_first_colon" == *:* ]] && [[ "$after_first_colon" != *"://"* ]] && [[ "${after_first_colon#*:}" != *"://"* ]]; then
                    # New format: box:name:command
                    local cmd_name="${after_first_colon%%:*}"
                    local cmd="${after_first_colon#*:}"
                    hot_cmds+=("$cmd")
                    hot_cmd_names+=("$cmd_name")
                else
                    # Old format: box:command
                    hot_cmds+=("$after_first_colon")
                    hot_cmd_names+=("$after_first_colon")  # Default name is the command itself
                fi
                hot_cmd_lines+=("$line_num")
            fi
        fi
        line_num=$((line_num+1))
    done < "$HOTCMDS_FILE"

    if [ ${#hot_cmds[@]} -eq 0 ]; then
        echo "No hot commands to edit for $item_name."
        echo "Press Enter to continue..."
        read
        return
    fi

    echo "Select a hot command to edit:"

    # Display commands with their menu numbers and current names
    local menu_number=$CONTAINER_MENU_ITEMS
    for i in "${!hot_cmds[@]}"; do
        if [ "${hot_cmds[$i]}" = "${hot_cmd_names[$i]}" ]; then
            # Command has no custom name yet
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmds[$i]}")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmds[$i]}"
        else
            # Command has a custom name
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmd_names[$i]}")
            printf "%b%d. \"%s\" (%s)\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmd_names[$i]}" "${hot_cmds[$i]}"
        fi
        menu_number=$((menu_number+1))
    done

    read -p "Enter command number to edit (or press Enter to cancel): " edit_num

    if [ -z "$edit_num" ]; then
        echo "Operation cancelled."
        return
    fi

    # Convert menu number to array index
    if [[ "$edit_num" =~ ^[0-9]+$ ]] && [ "$edit_num" -ge $CONTAINER_MENU_ITEMS ] && [ "$edit_num" -le $(($CONTAINER_MENU_ITEMS - 1 + ${#hot_cmds[@]})) ]; then
        local array_index=$((edit_num - $CONTAINER_MENU_ITEMS))
        local line_to_modify=${hot_cmd_lines[$array_index]}
        local current_command="${hot_cmds[$array_index]}"
        local current_name="${hot_cmd_names[$array_index]}"

        echo "Current command: $current_command"
        if [ "$current_command" != "$current_name" ]; then
            echo "Current name: $current_name"
        fi

        echo ""
        echo "What would you like to edit?"
        echo "1. Edit command name only"
        echo "2. Edit command content only" 
        echo "3. Edit both name and content"
        echo "0. Cancel"

        read -p "Enter your choice: " edit_choice

        case $edit_choice in
            1)
                # Edit name only
                read -p "Enter new name for this command (or press Enter to reset to default): " new_name
                
                # Create a temp file and modify the line
                temp_file=$(mktemp)
                sed "${line_to_modify}d" "$HOTCMDS_FILE" > "$temp_file"
                
                if [ -z "$new_name" ]; then
                    # Reset to default (no custom name)
                    echo "$item_name:$current_command" >> "$temp_file"
                    echo -e "\033[1;32mHot command name reset to default.\033[0m"
                else
                    # Set custom name
                    echo "$item_name:$new_name:$current_command" >> "$temp_file"
                    echo -e "\033[1;32mHot command renamed successfully to \"$new_name\".\033[0m"
                fi
                
                sort "$temp_file" > "$HOTCMDS_FILE"
                rm "$temp_file"
                ;;
            2)
                # Edit command content only
                read -p "Enter new command content: " new_command
                
                if [ -z "$new_command" ]; then
                    echo "Operation cancelled - command content cannot be empty."
                    return
                fi
                
                # Create a temp file and modify the line
                temp_file=$(mktemp)
                sed "${line_to_modify}d" "$HOTCMDS_FILE" > "$temp_file"
                
                if [ "$current_command" = "$current_name" ]; then
                    # No custom name, keep it that way
                    echo "$item_name:$new_command" >> "$temp_file"
                else
                    # Has custom name, preserve it
                    echo "$item_name:$current_name:$new_command" >> "$temp_file"
                fi
                
                sort "$temp_file" > "$HOTCMDS_FILE"
                rm "$temp_file"
                echo -e "\033[1;32mHot command content updated successfully.\033[0m"
                ;;
            3)
                # Edit both name and content
                read -p "Enter new name for this command (or press Enter to reset to default): " new_name
                read -p "Enter new command content: " new_command
                
                if [ -z "$new_command" ]; then
                    echo "Operation cancelled - command content cannot be empty."
                    return
                fi
                
                # Create a temp file and modify the line
                temp_file=$(mktemp)
                sed "${line_to_modify}d" "$HOTCMDS_FILE" > "$temp_file"
                
                if [ -z "$new_name" ]; then
                    # Reset to default (no custom name)
                    echo "$item_name:$new_command" >> "$temp_file"
                    echo -e "\033[1;32mHot command updated with default name.\033[0m"
                else
                    # Set custom name
                    echo "$item_name:$new_name:$new_command" >> "$temp_file"
                    echo -e "\033[1;32mHot command updated with name \"$new_name\".\033[0m"
                fi
                
                sort "$temp_file" > "$HOTCMDS_FILE"
                rm "$temp_file"
                ;;
            0)
                echo "Operation cancelled."
                return
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    else
        echo "Invalid selection."
    fi

    echo "Press Enter to continue..."
    read
}

# Base function to remove a hot command
# Can be overridden for custom menu numbering
remove_hot_command() {
    local item_name="$1"
    clear
    local hot_cmds=()
    local hot_cmd_names=()
    local hot_cmd_lines=()
    local line_num=1

    # Collect commands, names, and their line numbers
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        if [ -n "$line" ]; then
            # Extract the box name (everything before first colon)
            local box="${line%%:*}"
            if [ "$box" = "$item_name" ]; then
                # Get everything after the first colon
                local after_first_colon="${line#*:}"
                
                # Check if there's another colon AND it's not part of a URL (indicating new format with custom name)
                if [[ "$after_first_colon" == *:* ]] && [[ "$after_first_colon" != *"://"* ]] && [[ "${after_first_colon#*:}" != *"://"* ]]; then
                    # New format: box:name:command
                    local cmd_name="${after_first_colon%%:*}"
                    local cmd="${after_first_colon#*:}"
                    hot_cmds+=("$cmd")
                    hot_cmd_names+=("$cmd_name")
                else
                    # Old format: box:command
                    hot_cmds+=("$after_first_colon")
                    hot_cmd_names+=("$after_first_colon")  # Default name is the command itself
                fi
                hot_cmd_lines+=("$line_num")
            fi
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

    # Display commands with their menu numbers and names
    local menu_number=$CONTAINER_MENU_ITEMS
    for i in "${!hot_cmds[@]}"; do
        if [ "${hot_cmds[$i]}" = "${hot_cmd_names[$i]}" ]; then
            # Command has no custom name
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmds[$i]}")
            printf "%b%d. %s\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmds[$i]}"
        else
            # Command has a custom name
            cmd_color_code=$(generate_color_code "$item_name:${hot_cmd_names[$i]}")
            printf "%b%d. \"%s\" (%s)\033[0m\n" "$cmd_color_code" "$menu_number" "${hot_cmd_names[$i]}" "${hot_cmds[$i]}"
        fi
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
