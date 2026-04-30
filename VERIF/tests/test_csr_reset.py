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

"""CSR reset-value readback test.

For both DUTs in the harness, immediately after reset (and *before*
APB activation -- so registers like ``aou_init`` are still in their
virgin reset state), read every register defined in
``csr/aou-core.rdl`` over APB and verify that every sw-readable,
reset-bearing field matches the reset value pinned down by the RDL.

The expected-value model is built once at import time from the RDL
itself, so the test self-updates whenever ``csr/aou-core.rdl`` changes.
"""

from __future__ import annotations

import cocotb

from axi_helpers import APB_DATA_WIDTH
from csr_reset_model import CsrResetSpec, build_csr_reset_specs
from dut_setup import (
    APB_READ_TIMEOUT_NS,
    OVERALL_TIMEOUT_US,
    await_with_message,
    bring_up,
)


# Expected-value table is built once per import: parsing the RDL is
# deterministic, so we can share the same spec list across DUTs.
_RESET_SPECS = build_csr_reset_specs()
_APB_BYTES = APB_DATA_WIDTH // 8


def _decode_field_deltas(spec: CsrResetSpec, read_value: int) -> list[str]:
    """Pretty-print every field whose readback disagrees with the RDL.

    Returns a list of human-readable lines so the caller can splice them
    into a single multi-line AssertionError message.
    """
    lines: list[str] = []
    for fname, low, width, reset in spec.fields:
        field_mask = (1 << width) - 1
        actual = (read_value >> low) & field_mask
        expected = reset & field_mask
        if actual != expected:
            lines.append(
                f"      field {fname}[{low + width - 1}:{low}] "
                f"expected=0x{expected:x} actual=0x{actual:x}"
            )
    return lines


async def _check_dut_resets(dut, label: str, apb) -> list[str]:
    """Read every spec entry on one DUT and return a list of failure msgs.

    We accumulate failures across all registers (per DUT) instead of
    bailing on the first mismatch so a single test run reports every
    deviation at once -- much faster bring-up debug than fix-one-rerun.
    """
    failures: list[str] = []
    for spec in _RESET_SPECS:
        read_op = await await_with_message(
            apb.read(spec.addr, _APB_BYTES),
            timeout_ns=APB_READ_TIMEOUT_NS,
            what=f"{label} APB read of {spec.name} @ 0x{spec.addr:x}",
            dut=dut,
        )
        read_value = int.from_bytes(bytes(read_op.data), "little")
        if (read_value & spec.mask) != spec.expected:
            header = (
                f"  [{label}] {spec.name} @ 0x{spec.addr:x}: "
                f"read=0x{read_value:08x} mask=0x{spec.mask:08x} "
                f"expected=0x{spec.expected:08x} "
                f"actual_masked=0x{read_value & spec.mask:08x}"
            )
            failures.append(header)
            failures.extend(_decode_field_deltas(spec, read_value))
    return failures


@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_csr_reset_values(dut):
    """Verify post-reset CSR contents match RDL reset values on both DUTs."""
    if not _RESET_SPECS:
        raise AssertionError(
            "csr_reset_model.build_csr_reset_specs() returned no specs; "
            "csr/aou-core.rdl is empty or unreadable"
        )

    bfms = await bring_up(dut, activate=False)
    dut._log.info(
        "CSR reset readback: checking %d registers per DUT against %s",
        len(_RESET_SPECS), "csr/aou-core.rdl",
    )

    failures: list[str] = []
    for label, key in (("DUT1", "d1_apb"), ("DUT2", "d2_apb")):
        failures.extend(await _check_dut_resets(dut, label, bfms[key]))

    if failures:
        msg = (
            f"CSR reset readback found {len(failures)} mismatches:\n"
            + "\n".join(failures)
        )
        dut._log.error(msg)
        raise AssertionError(msg)

    dut._log.info(
        "CSR reset readback PASS: %d registers x 2 DUTs all match RDL",
        len(_RESET_SPECS),
    )
