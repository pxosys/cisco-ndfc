# cisco-ndfc

Version-agnostic Ansible automation framework for backing up, cloning, and migrating fabrics, VRFs, networks, and configuration policies across **Cisco Nexus Dashboard (ND 4.3+)**, **NDFC 12.x**, and **DCNM 11.x** on Linux control nodes.

---

## Linux Environment & Library Validation

This repository includes two layers of automated Linux validation so playbooks fail fast with actionable diagnostics if any OS package, Python library, or Ansible collection is missing:

1. **Standalone Shell Validator (`scripts/validate_env.sh` / `make validate`):**
   - Verifies Linux OS, system binaries (`python3`, `git`, `curl`), Python `>= 3.11`, and `python3-venv`.
   - Verifies `.venv` exists and all required Python libraries (`ansible`, `requests`, `urllib3`, `packaging`, `yaml`, `jinja2`, `ansiblelint`, `yamllint`) are importable.
   - Verifies Ansible collections (`cisco.dcnm >= 3.6.0`, `ansible.netcommon >= 6.1.0`, `ansible.utils >= 3.1.0`), module doc loading (`cisco.dcnm.dcnm_rest`), and playbook syntax across all inventories.
2. **Embedded Ansible Pre-Flight Role (`roles/env_preflight`):**
   - Runs automatically as **Phase 0** in every playbook (`export_fabric.yml`, `import_fabric.yml`, `migrate_fabric.yml`) to confirm the control node is Linux, verify Python/Ansible versions, check Python module imports in `ansible_playbook_python`, and validate installed Ansible collections before touching any fabric.

---

## Architecture & Multi-Version Support

| Inventory | `ndfc_platform_version` | Target Controller |
| :--- | :--- | :--- |
| `inventories/nd43` | `nd4.3` | Cisco Nexus Dashboard 4.3+ (Unified Image) |
| `inventories/ndfc12` | `ndfc12` | Cisco NDFC 12.x |

Adding support for future Nexus Dashboard versions requires only creating a new inventory directory and mapping its API prefix in `roles/*/defaults/main.yml`.

---

## Linux Quick Start (`venv`)

### 1. Install Linux OS Prerequisites
* **Debian / Ubuntu:**
  ```bash
  sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip git curl
  ```
* **RHEL / Rocky / AlmaLinux:**
  ```bash
  sudo dnf install -y python3.11 python3.11-pip git curl
  ```

### 2. Bootstrap `.venv` and Validate Environment
```bash
git clone https://github.com/<your-org>/cisco-ndfc.git
cd cisco-ndfc
make setup
make validate
source .venv/bin/activate
```

### 3. Verify Linting & Syntax
```bash
make lint
make check
```

---

## Usage

### 1. Configure Target Inventory
Update `inventories/nd43/hosts.ini` and `inventories/nd43/group_vars/all.yml`:
```yaml
source_fabric_name: "Fabric-Prod-01"
dest_fabric_name: "Fabric-New-02"
dest_fabric_template: "Easy_Fabric"
```

### 2. Encrypt Credentials with Ansible Vault
```bash
ansible-vault edit inventories/nd43/group_vars/vault.yml
```

### 3. Execute Playbooks

**Standalone Environment Check:**
```bash
ansible-playbook playbooks/validate_environment.yml
```

**Full Migration (Pre-Flight + Export + Import):**
```bash
ansible-playbook -i inventories/nd43/hosts.ini playbooks/migrate_fabric.yml --ask-vault-pass
```

**Backup Only (Pre-Flight + Export):**
```bash
ansible-playbook -i inventories/nd43/hosts.ini playbooks/export_fabric.yml --ask-vault-pass
```

**Restore Only (Pre-Flight + Import):**
```bash
ansible-playbook -i inventories/nd43/hosts.ini playbooks/import_fabric.yml --ask-vault-pass
```

---

## Hardware Refresh: Migrating Switch-Level Policies
1. Import/discover the new switches into `dest_fabric_name`.
2. Define `switch_serial_map` in `group_vars/all.yml`:
   ```yaml
   switch_serial_map:
     FDO2412001A: FDO2710991B
     FDO2412002A: FDO2710992B
   ```
3. Run `playbooks/import_fabric.yml`.

---

## Contributing & Security Guardrails
- **Branching:** Create feature branches from `main` (`feat/<topic>` or `fix/<topic>`) and open a Pull Request.
- **Pre-Commit:** Every commit is validated locally by `.pre-commit-config.yaml` (`yamllint`, `ansible-lint`, secret detection) and verified remotely by GitHub Actions (`.github/workflows/ci.yml`).
- **Secrets & Backups:** Never commit unencrypted `vault.yml` files or `backups/*.json` exports (blocked by `.gitignore`).
