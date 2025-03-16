# Dummy Simple Venv Manager

A dummy simple BASH script that simplifies the process of creating and using Python virtual environments.
![image](https://github.com/user-attachments/assets/2fbe4d73-a242-481b-bed4-0d73f954e7cb)

## Features

- Easily create and manage Python virtual environments without any dependencies. (Besides Python and BASH)
- Optional Conda integration for creating venvs on specific versions of python.
- "Hot Commands" for easily executing commands inside of the venv without having to type or memorize them.
- "Working Directory" to always open the venv inside of a specific directory for less "cd"ing.
- "Startup Commands" that can be executed automatically when a venv is activated.

## Requirements

Just Python and BASH. Conda is optional for creating venvs using specific versions of python.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/VilktorK/DummySimpleVenvManager
```

2. Navigate to the directory:
```bash
cd DummySimpleVenvManager
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

Simply Run:
```bash
./DummySimpleVenvManager.sh
```
Refer to DOCUMENTATION.md or type "help" when in the main menu for a detailed explinations of all functions

