# Bash Prompt Framework

A modular, feature-rich Bash prompt with Git integration, virtual environment detection, Kubernetes context, and more. Designed for both standard Linux and Termux environments.

## Features

- **Modular design** - Enable/disable components as needed
- **Git integration** - Branch name, clean/dirty status, ahead/behind commits
- **Python virtual environments** - Auto-detects venv and conda
- **Kubernetes context** - Shows current context and namespace
- **Command duration** - Displays execution time for long-running commands
- **Exit code display** - Shows non-zero exit codes
- **SSH detection** - Shows hostname when connected via SSH
- **Background jobs counter** - Shows number of running background jobs
- **Termux support** - Optimized for Android/Termux environments
- **CLI manager** - Easy configuration via `prompt` command

## Quick Install

```bash
https://github.com/setya-rgb/bash-prompt.git
cd bash-prompt.git
./install.sh
