# Getting Started

### Create a new virtual environment:
   - Select '0' for Options.
   - Choose '1' to create a new venv.
   - Select '1' to use the system's installed Python version or '2' to use conda for a custom Python version (if conda is installed).
   - You can specify your conda directory when selecting '1' for the first time.
   - Venvs created with either method are static and won't update.
   - Process of installing conda will be simplified in future updates.

### Managing virtual environments:
   - Select a venv by its number from the main menu
   - Enter the venv to activate it

### Using Hot Commands:
   - Hot commands are customizable commands that can be executed with the press of their associated number
   - This saves the work of typing or remembering commonly used commands within the venv

### Setting a Working Directory:
   - The working directory is where the venv will start when entered using this script
   - This is useful for venvs that operate within a specific directory
   - You can choose whether the venv should execute its hot commands within the working directory
   - This means hot commands that affect certain files within the working directory won't need to include a cd command first

### Config Location:
   - All config files are located in $HOME/.config/dummysimplevenvmanager
