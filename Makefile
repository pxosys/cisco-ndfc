VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
ANSIBLE_GALAXY := $(VENV)/bin/ansible-galaxy
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
YAMLLINT := $(VENV)/bin/yamllint
PRE_COMMIT := $(VENV)/bin/pre-commit

.PHONY: help setup validate lint check clean

help:
	@echo "Usage:"
	@echo "  make setup     - Create .venv, install Python packages, Ansible collections, and pre-commit hooks"
	@echo "  make validate  - Validate Linux OS dependencies, Python libraries, and Ansible collections"
	@echo "  make lint      - Run yamllint and ansible-lint"
	@echo "  make check     - Run syntax-check across all playbooks"
	@echo "  make clean     - Remove .venv and temporary artifacts"

setup:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	$(ANSIBLE_GALAXY) collection install -r requirements.yml --upgrade
	chmod +x scripts/validate_env.sh
	$(PRE_COMMIT) install || true

validate:
	chmod +x scripts/validate_env.sh
	./scripts/validate_env.sh

lint:
	$(YAMLLINT) .
	$(ANSIBLE_LINT)

check:
	$(VENV)/bin/ansible-playbook -i inventories/nd43/hosts.ini playbooks/migrate_fabric.yml --syntax-check
	$(VENV)/bin/ansible-playbook -i inventories/ndfc12/hosts.ini playbooks/migrate_fabric.yml --syntax-check

clean:
	rm -rf $(VENV) .ansible __pycache__ *.retry
