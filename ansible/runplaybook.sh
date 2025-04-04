#!/bin/bash

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
else
  source .venv/bin/activate
fi

ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbook.yaml -i inventory.yaml --syntax-check

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

ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbook.yaml -i inventory.yaml --ask-vault-password $TAGS $MODE