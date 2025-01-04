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
   - Edit existing commands
   - Remove commands
   - Hot commands execute within the working directory if configured

3. Change working directory
   - Update or set the directory where the venv starts
   - Configure whether hot commands use this directory

## Hot Commands
- Custom commands that can be executed by pressing their associated numbers
- Appear as numbered options in the venv management menu
- Can be configured to run within the working directory (A choice made when setting the working directory)
- Saved to `venvhotcmds.cfg`

## Deleting a Virtual Environment

1. From the main menu, select `0` for Options
2. Choose `2` to delete a venv
3. Select the venv to delete
4. Type the full name of the venv to confirm deletion

Deletion process:
- Removes the virtual environment
- Cleans up associated configurations
- Removes associated hot commands from `venvhotcmds.cfg`

## Conda Support
- Conda must be installed separately
- When using conda, you can:
  - Specify custom Python versions
  - Access conda-specific packages
- First-time conda setup:
  - You'll be prompted to specify your conda installation directory
  - This setting is saved for future use in `condapath.cfg`

## Config Location

- Configuration directory: `~/.config/dummysimplevenvmanager/`
- Settings file: `settings.cfg`
- Hot commands: `venvhotcmds.cfg`
- Conda Path: `condapath.cfg`
