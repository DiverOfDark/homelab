#!/bin/bash
source .venv/bin/activate

ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbook/playbook.yaml -i inventory.yaml