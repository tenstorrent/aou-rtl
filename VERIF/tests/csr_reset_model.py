# SPDX-License-Identifier: Apache-2.0
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

"""SystemRDL-driven expected-reset-value model for the AOU CSR block.

Parses ``csr/aou-core.rdl`` (the same single source of truth used by
``scripts/gen_collateral.sh``) and produces, for every register with at
least one sw-readable field carrying a defined reset value, a
``CsrResetSpec`` describing the address, the bit mask of fields we
expect to be predictable, and the assembled expected reset value.

Hardware-driven status fields, write-only fields, and any field without
a reset value are deliberately excluded from the mask so the readback
test only checks bits whose reset value the RDL actually pins down.
"""

from __future__ import annotations

from pathlib import Path
from typing import List, NamedTuple, Tuple

from systemrdl import RDLCompiler
from systemrdl.node import RegNode


# Resolve <repo_root>/csr/aou-core.rdl from this file's location.
# Layout: <repo>/VERIF/tests/csr_reset_model.py -> parents[2] == <repo>.
RDL_PATH = Path(__file__).resolve().parents[2] / "csr" / "aou-core.rdl"

# Top addrmap to elaborate (matches `addrmap aou_core` in aou-core.rdl).
RDL_TOP = "aou_core"


class CsrResetSpec(NamedTuple):
    """One register's predictable post-reset value.

    Attributes:
        name:     hierarchical RDL inst path (e.g. ``aou_init``).
        addr:     absolute byte address as APB sees it.
        mask:     bitmask of bits whose reset value is RDL-defined and
                  sw-readable (i.e. bits we expect to be able to verify).
        expected: ``read_value & mask`` should equal this on a freshly
                  reset DUT.
        fields:   per-field detail used for human-readable failure
                  messages: ``(field_name, low_bit, width, reset_value)``.
    """

    name: str
    addr: int
    mask: int
    expected: int
    fields: List[Tuple[str, int, int, int]]


def build_csr_reset_specs() -> List[CsrResetSpec]:
    """Walk the elaborated RDL and emit one CsrResetSpec per checkable reg.

    A register is "checkable" iff at least one of its fields is both
    sw-readable AND has a defined ``reset`` property. Registers whose
    reset state is entirely hw-driven (status, counters, etc.) are
    skipped so the readback test stays deterministic.
    """
    rdlc = RDLCompiler()
    rdlc.compile_file(str(RDL_PATH))
    root = rdlc.elaborate(top_def_name=RDL_TOP)

    specs: List[CsrResetSpec] = []
    for node in root.descendants(unroll=True):
        if not isinstance(node, RegNode):
            continue

        mask = 0
        expected = 0
        fields: List[Tuple[str, int, int, int]] = []

        for field in node.fields():
            if not field.is_sw_readable:
                continue
            reset = field.get_property("reset")
            if reset is None:
                continue

            width = field.width
            field_mask = ((1 << width) - 1) << field.low
            mask |= field_mask
            expected |= (int(reset) & ((1 << width) - 1)) << field.low
            fields.append((field.inst_name, field.low, width, int(reset)))

        if mask:
            specs.append(CsrResetSpec(
                name=node.get_path(),
                addr=node.absolute_address,
                mask=mask,
                expected=expected,
                fields=fields,
            ))

    return specs
