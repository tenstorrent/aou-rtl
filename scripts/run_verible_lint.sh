#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Tenstorrent USA Inc
#
# Verible style and structural lint check for AOU RTL
# Rules are defined in scripts/.rules.verible_lint.
#
# Usage:  bash scripts/run_verible_lint.sh
#         (run from the repository root)
#
# Override the Verible binary location via VERIBLE_LINT:
#   VERIBLE_LINT=/path/to/verible-verilog-lint bash scripts/run_verible_lint.sh

set -euo pipefail
export AOU_CORE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERIBLE_LINT="${VERIBLE_LINT:-verible-verilog-lint}"

# ---------------------------------------------------------------------------
# Expand VCS-style filelist.f into a flat list of source files.
# Handles ${AOU_CORE_HOME} expansion, nested -f includes, and strips
# comments, +define+, +incdir+ directives.
# ---------------------------------------------------------------------------
expand_filelist() {
    local flist="$1"
    while IFS= read -r line; do
        line="${line%%//*}"                      # strip // comments
        line="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        [[ "$line" == +define+* ]] && continue
        [[ "$line" == +incdir+* ]] && continue

        if [[ "$line" == -f* ]]; then
            local nested="${line#-f}"
            nested="$(echo "$nested" | sed 's/^[[:space:]]*//')"
            nested="${nested//\$\{AOU_CORE_HOME\}/$AOU_CORE_HOME}"
            expand_filelist "$nested"
        else
            line="${line//\$\{AOU_CORE_HOME\}/$AOU_CORE_HOME}"
            echo "$line"
        fi
    done < "$flist"
}

FILES=()
while IFS= read -r f; do
    FILES+=("$f")
done < <(expand_filelist "${AOU_CORE_HOME}/RTL/filelist.f")

RULES_CONFIG="${AOU_CORE_HOME}/scripts/.rules.verible_lint"
LOG_DIR="${AOU_CORE_HOME}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/verible_lint.log"

echo "Verible lint: checking ${#FILES[@]} files"
echo "Rules config: ${RULES_CONFIG}"
echo "Log file:     ${LOG_FILE}"

# ---------------------------------------------------------------------------
# Rules are loaded from scripts/.rules.verible_lint via --rules_config.
# The config file starts from --ruleset=none (explicit rule list) to give
# full control over which rules are active.
# Output is captured to the log file and also printed to the terminal.
# ---------------------------------------------------------------------------
$VERIBLE_LINT \
    --ruleset=none \
    --rules_config="${RULES_CONFIG}" \
    --show_diagnostic_context \
    "${FILES[@]}" 2>&1 | tee "${LOG_FILE}"

RC=${PIPESTATUS[0]}
VIOLATIONS=$(grep -c ':.*\[.*\]' "${LOG_FILE}" 2>/dev/null || true)
echo ""
echo "Verible lint complete: ${VIOLATIONS} violation(s) found"
echo "Full log: ${LOG_FILE}"
exit $RC
