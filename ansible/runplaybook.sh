#!/bin/bash
source .venv/bin/activate

ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbook/playbook.yaml -i inventory.yaml --syntax-check

# Check if a tag was provided
if [ -n "$1" ]; then
    TAGS="--tags $1"
else
    TAGS=""
fi

# Ask the user whether to run in check/diff mode or apply changes
read -p "Do you want to run in check mode with diff (y/n)? " answer
if [ "$answer" = "y" ]; then
    MODE="--check --diff"
else
    MODE=""
fi

ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbook/playbook.yaml -i inventory.yaml -J $TAGS $MODE