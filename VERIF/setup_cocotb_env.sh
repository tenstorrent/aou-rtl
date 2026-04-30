#!/usr/bin/env bash
# *****************************************************************************
# SPDX-License-Identifier: Apache-2.0
# *****************************************************************************
# Copyright (c) 2026 Tenstorrent USA Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
#
# Create a local Python venv under VERIF/venv/ and install cocotb +
# cocotbext-axi from PyPI. No VIP source is vendored into the repo.
#
# Usage:
#   bash setup_cocotb_env.sh        # default venv path: ./venv
#   VENV_DIR=/tmp/myenv bash setup_cocotb_env.sh
#
# After install:
#   source venv/bin/activate
#   make                 # Verilator (default)
#   make SIM=vcs         # Synopsys VCS
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

VENV_DIR="${VENV_DIR:-${SCRIPT_DIR}/venv}"
PYTHON="${PYTHON:-python3}"

echo "=== Cocotb environment setup ==="
echo "  Script dir : ${SCRIPT_DIR}"
echo "  Venv dir   : ${VENV_DIR}"
echo "  Python     : $(${PYTHON} --version 2>&1)"
echo ""

if [ ! -d "${VENV_DIR}" ]; then
    echo "Creating venv at ${VENV_DIR}"
    "${PYTHON}" -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "Upgrading pip"
pip install --quiet --upgrade pip

echo "Installing requirements"
pip install --quiet -r "${SCRIPT_DIR}/requirements.txt"

echo ""
echo "Installed packages:"
pip list --format=columns | grep -E '^(cocotb|pytest)' || true

echo ""
echo "=== Cocotb environment ready ==="
echo ""
echo "Activate with:"
echo "    source ${VENV_DIR}/bin/activate"
echo ""
echo "Run with:"
echo "    cd ${SCRIPT_DIR} && make            # Verilator (default)"
echo "    cd ${SCRIPT_DIR} && make SIM=vcs    # Synopsys VCS"
echo "    cd ${SCRIPT_DIR} && make WAVES=1    # enable waveform dump"
echo ""
