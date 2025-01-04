# Dummy Simple Venv Manager

Dummy Simple Venv Manager is a dummy simple BASH script for simplifying the process of creating and using python virtual environments.
![image](https://github.com/user-attachments/assets/2fbe4d73-a242-481b-bed4-0d73f954e7cb)

## Features

- Easily create and manage Python virtual environments without any dependencies. (Besides Python and BASH)
- Optional Conda integration for creating venvs on specific versions of python.
- "Hot Commands" for easily executing commands inside of the venv without having to type or memorize them.
- "Working Directory" to always open the venv inside of a specific directory for less "cd"ing.

## Requirements

Just Python and BASH. Conda is optional for creating venvs using specific versions of python.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/username/dummy-simple-venv-manager.git
```

2. Navigate to the directory:
```bash
cd dummy-simple-venv-manager
```

3. Make the script executable:
```bash
chmod +x DummySimpleVenvManager.sh
```
```bash
chmod +x BaseManager.sh
```

4. Run the script:
```bash
./DummySimpleVenvManager.sh
```

5. Specify the directory where you want to store your Python virtual environments when prompted.

## Usage

Simpily Run:
```bash
./DummySimpleVenvManager.sh
```

### Getting Started

1. Create a new virtual environment:
   - Select '0' for Options.
   - Choose '1' to create a new venv.
   - Select '1' to use the system's installed Python version or '2' to use conda for a custom Python version (if conda is installed).
   - You can specify your conda directory when selecting '1' for the first time.
   - Venvs created with either method are static and won't update.
   - Process of installing conda will be simplified in future updates.

2. Managing virtual environments:
   - Select a venv by its number from the main menu
   - Enter the venv to activate it

3. Using Hot Commands:
   - Hot commands are customizable commands that can be executed with the press of their associated number
   - This saves the work of typing or remembering commonly used commands within the venv

4. Setting a Working Directory:
   - The working directory is where the venv will start when entered using this script
   - This is useful for venvs that operate within a specific directory
   - You can choose whether the venv should execute its hot commands within the working directory
   - This means hot commands that affect certain files within the working directory won't need to include a cd command first

5. Show launch script:
   - Shows the command that will enter the venv and the working directory if one is configured.

6. Config Location:
   - All config files are located in $HOME/.config/dummysimplevenvmanager
