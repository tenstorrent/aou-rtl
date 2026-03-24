#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# (c) 2026 Tenstorrent USA Inc
#
# Generate all IP integration collateral from the SystemRDL register source.
# Run from the repository root:
#   source venv/bin/activate
#   bash scripts/gen_collateral.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RDL=csr/aou-core.rdl

IPXACT_DIR=INTEG/ipxact
GEN_DIR=$IPXACT_DIR/gen

mkdir -p "$GEN_DIR" DOC/csr VERIF

echo "=== Generating collateral from $RDL ==="

echo "  [1/5] Markdown register docs  -> DOC/csr/aou-core-csrs.md"
peakrdl markdown $RDL -t aou_core -o DOC/csr/aou-core-csrs.md

echo "  [2/5] IP-XACT register map    -> $GEN_DIR/aou_core_regmap.xml"
peakrdl ip-xact $RDL -o $GEN_DIR/aou_core_regmap.xml

echo "  [3/5] C header                -> DOC/csr/aou_core_csr.h"
peakrdl c-header $RDL -o DOC/csr/aou_core_csr.h

echo "  [4/5] Interactive HTML docs   -> DOC/csr/html/"
peakrdl html $RDL -o DOC/csr/html

echo "  [5/5] UVM register model      -> VERIF/aou_core_csr_uvm_pkg.sv"
peakrdl uvm $RDL -o VERIF/aou_core_csr_uvm_pkg.sv

echo ""
echo "=== Validating IP-XACT output ==="
python3 scripts/validate_ipxact.py $GEN_DIR/aou_core_regmap.xml

echo "=== Done ==="
