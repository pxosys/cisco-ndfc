#!/usr/bin/env bash
set -euo pipefail

# Validates Linux OS dependencies, Python venv, Python packages, and Ansible collections
# required to execute all playbooks in cisco-ndfc.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${REPO_ROOT}/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"
GALAXY_BIN="${VENV_DIR}/bin/ansible-galaxy"
PLAYBOOK_BIN="${VENV_DIR}/bin/ansible-playbook"

ERRORS=0

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }

echo "============================================================"
echo " Cisco NDFC / Nexus Dashboard - Linux Pre-Flight Validator"
echo "============================================================"

# 1. Verify Linux OS
if [[ "$(uname -s)" != "Linux" ]]; then
  warn "Detected non-Linux OS ($(uname -s)). Playbooks are designed for Linux control nodes."
else
  pass "Operating System: Linux ($(uname -r))"
fi

# 2. Verify system binaries
for cmd in python3 git curl; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    pass "System binary '${cmd}' found: $(command -v "${cmd}")"
  else
    fail "Required Linux system binary '${cmd}' is missing."
  fi
done

# 3. Verify Python >= 3.11
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
    pass "System Python version: $(python3 --version)"
  else
    fail "Python >= 3.11 is required (found $(python3 --version))."
  fi
fi

# 4. Verify python3-venv module availability (common missing package on Debian/Ubuntu)
if python3 -m venv --help >/dev/null 2>&1; then
  pass "Python 'venv' module is available"
else
  fail "Python 'venv' module is missing. Install python3-venv (e.g., sudo apt-get install -y python3-venv)."
fi

# 5. Verify .venv exists and is executable
if [[ ! -x "${PYTHON_BIN}" ]]; then
  fail "Virtual environment not found at ${VENV_DIR}. Run 'make setup' first."
  echo "============================================================"
  echo -e "${RED}Validation failed with ${ERRORS} error(s).${NC}"
  exit 1
else
  pass "Virtual environment found at ${VENV_DIR}"
fi

# 6. Verify required Python libraries inside .venv
REQUIRED_PY_PKGS=("ansible" "ansiblelint" "yamllint" "pre_commit" "requests" "urllib3" "packaging" "yaml" "jinja2")
for pkg in "${REQUIRED_PY_PKGS[@]}"; do
  if "${PYTHON_BIN}" -c "import ${pkg}" >/dev/null 2>&1; then
    pass "Python library '${pkg}' is importable"
  else
    fail "Python library '${pkg}' is NOT installed in ${VENV_DIR}. Run 'make setup'."
  fi
done

# 7. Verify required Ansible collections & minimum versions
check_collection() {
  local col_name="$1"
  local min_ver="$2"
  local installed_ver

  installed_ver=$("${GALAXY_BIN}" collection list "${col_name}" 2>/dev/null | awk -v col="${col_name}" '$1 == col {print $2}' | head -n 1)

  if [[ -z "${installed_ver}" ]]; then
    fail "Ansible collection '${col_name}' (>= ${min_ver}) is NOT installed."
    return
  fi

  if "${PYTHON_BIN}" -c "from packaging.version import Version; raise SystemExit(0 if Version('${installed_ver}') >= Version('${min_ver}') else 1)" 2>/dev/null; then
    pass "Ansible collection '${col_name}' version ${installed_ver} (>= ${min_ver})"
  else
    fail "Ansible collection '${col_name}' version ${installed_ver} is older than required ${min_ver}."
  fi
}

check_collection "cisco.dcnm" "3.6.0"
check_collection "ansible.netcommon" "6.1.0"
check_collection "ansible.utils" "3.1.0"

# 8. Verify Ansible httpapi plugin and dcnm_rest module load cleanly
if "${VENV_DIR}/bin/ansible-doc" -t module cisco.dcnm.dcnm_rest >/dev/null 2>&1; then
  pass "Ansible module 'cisco.dcnm.dcnm_rest' loaded successfully"
else
  fail "Unable to load Ansible module 'cisco.dcnm.dcnm_rest'."
fi

if "${VENV_DIR}/bin/ansible-doc" -t connection ansible.netcommon.httpapi >/dev/null 2>&1; then
  pass "Ansible connection plugin 'ansible.netcommon.httpapi' loaded successfully"
else
  fail "Unable to load Ansible connection plugin 'ansible.netcommon.httpapi'."
fi

# 9. Verify playbook syntax across all inventories
for inv in "${REPO_ROOT}"/inventories/*/hosts.ini; do
  if "${PLAYBOOK_BIN}" -i "${inv}" "${REPO_ROOT}/playbooks/migrate_fabric.yml" --syntax-check >/dev/null 2>&1; then
    pass "Playbook syntax valid for inventory: ${inv#${REPO_ROOT}/}"
  else
    fail "Playbook syntax check failed for inventory: ${inv#${REPO_ROOT}/}"
  fi
done

echo "============================================================"
if [[ ${ERRORS} -eq 0 ]]; then
  echo -e "${GREEN}All Linux environment & library validations PASSED!${NC}"
  exit 0
else
  echo -e "${RED}Validation FAILED with ${ERRORS} error(s). Fix issues above before running playbooks.${NC}"
  exit 1
fi
