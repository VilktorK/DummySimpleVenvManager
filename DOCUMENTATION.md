# Dummy Simple Venv Manager Documentation

## Overview
Dummy Simple Venv Manager is a dummy simple script for managing Python virtual environments. It provides a simple way to create, manage, and maintain virtual environments with separate working directories and customizable hot commands.

### Key Concepts
- When a venv is created it will place the core venv files inside of the venv directory that was set during the initial setup
- A working directory can be set from within the options menu of the venv that can act as a "home" directory for all the venv

## Creating a Virtual Environment

1. From the main menu, select `0` for Options
2. Choose `1` to create a new venv
3. Select your Python source:
   - Option 1: Use system's installed Python version
   - Option 2: Use conda for a custom Python version (requires an independent conda installation)
4. Enter a name for your new virtual environment
5. Optional: Set up a working directory
   - Enter the venv and select `3`
   - Specify a directory where the venv should start when activated
   - Choose whether hot commands should execute within this directory

## Managing Virtual Environments

From the main menu, select a venv by its number to access these features:

## Basic Operations
1. Enter venv
   - Activates the selected virtual environment
   - If configured, starts in the specified working directory

2. Modify hot commands
   - Add custom commands for quick access
   - Remove existing hot commands
   - Rename hot commands to give them custom names
   - Edit existing hot commands
   - Show config file paths
   - Hot commands execute within the working directory if configured

3. Manage container startup commands
   - Add commands that run automatically when entering the venv
   - Can be set globally or per-venv

4. Set working directory
   - Update or set the directory where the venv starts
   - Configure whether hot commands use this directory

5. Show launch script
   - Display the generated launch script for the venv

## Hot Commands
- Custom commands that can be executed by pressing their associated numbers
- Appear as numbered options (6 and above) in the venv management menu
- Can be configured to run within the working directory (A choice made when setting the working directory)
- Each venv has its own hot commands file: `hotcommands/{venv_name}.cfg`
- Commands can be given custom names for easier identification
- Hot commands automatically load your shell environment (bashrc, bash_profile)

## Exiting a Venv
- Type `exit` to leave an active venv and return to the main menu

## Deleting a Virtual Environment

1. From the main menu, select `0` for Options
2. Choose `2` to delete a venv
3. Select the venv to delete
4. Type the full name of the venv to confirm deletion

Deletion process:
- Removes the virtual environment
- Cleans up associated configurations
- Removes associated hot commands file

## Conda Support
- Conda must be installed separately
- When using conda, you can:
  - Specify custom Python versions
  - Access conda-specific packages
- First-time conda setup:
  - You'll be prompted to specify your conda installation directory
  - This setting is saved for future use in `condapath.cfg`

## Sorting and Organization

### Sorting Options
Available from Options menu (4. Manage sorting preferences):
- **Alphabetical** - Default sorting by venv name
- **Most Recently Created** - Newest venvs first
- **Most Recently Used** - Recently accessed venvs first

### Favorites System
Available from Options menu (6. Manage favorites):
- Mark venvs as favorites for quick access
- Favorites appear at the top of the main menu with ★ symbol
- Shows Python version in brackets for easy identification
- Favorites respect your chosen sorting method
- Toggle favorite status on/off for any venv

## Config Location

- Configuration directory: `~/.config/dummysimplevenvmanager/`
- Settings file: `settings.cfg`
- Hot commands directory: `hotcommands/`
- Per-venv hot commands: `hotcommands/{venv_name}.cfg`
- Conda Path: `condapath.cfg`
- Favorites: `favorites.cfg`
- Creation times: `creation_time.cfg`
- Last access: `last_access.cfg`
