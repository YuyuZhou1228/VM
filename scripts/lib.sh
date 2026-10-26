#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts. Not meant to be run directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log()  { printf '\033[1;32m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1 (run scripts/00-host-setup.sh)"
}

load_env() {
  local env_file="${REPO_ROOT}/config/vm.env"
  [[ -f "${env_file}" ]] || die "Missing config/vm.env — copy config/vm.env.example to it and edit."
  # Export every variable defined in vm.env.
  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
}

# Append KEY="VALUE" to config/vm.env so a generated value stays stable across runs.
persist_env() {
  local key="$1" value="$2"
  printf '%s="%s"\n' "${key}" "${value}" >> "${REPO_ROOT}/config/vm.env"
}
