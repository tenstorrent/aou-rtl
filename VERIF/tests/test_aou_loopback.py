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

"""AOU_CORE_TOP dual-DUT FDI loopback test (cocotb).

  - Forward path : AxiMaster on u_dut1 SI -> FDI -> AxiRam on u_dut2 MI
  - Reverse path : AxiMaster on u_dut2 SI -> FDI -> AxiRam on u_dut1 MI
  - One AXI write + one AXI read per direction.
  - Pass criterion : the read data byte-for-byte matches what was written.

Common DUT bring-up (clock start, reset, BFM construction, APB activate)
lives in dut_setup.py and is shared with the CSR reset readback test.
"""

from __future__ import annotations

import logging

import cocotb
from cocotb.triggers import ClockCycles

from axi_helpers import D1_AXI_DATA_WIDTH, D2_AXI_DATA_WIDTH
from dut_setup import (
    AXI_READ_TIMEOUT_NS,
    AXI_WRITE_TIMEOUT_NS,
    OVERALL_TIMEOUT_US,
    await_with_message,
    bring_up,
)


# Mirrors the existing testbench's add_memory_region(64'h0, 64'h3F, ...).
TEST_ADDR = 0x0
TEST_LEN_BYTES = 64


def _make_payload(seed: int, length: int) -> bytes:
    """Deterministic payload so failures reproduce across simulators."""
    import random
    rng = random.Random(seed)
    return bytes(rng.randrange(256) for _ in range(length))


# -------------------------------------------------------------------------
# Direction helpers (write + read + check)
# -------------------------------------------------------------------------

async def _do_loopback(
    dut,
    *,
    direction: str,
    master,
    ram,
    si_data_width_bits: int,
    mi_data_width_bits: int,
    payload: bytes,
) -> None:
    """Perform one AXI write + one AXI read and verify round-trip data.

    ``master`` and ``ram`` are pre-constructed by ``bring_up`` so that
    every DUT input is held at clean 0 across the reset window. The TX
    path packs the AXI write into FDI flits which are then unpacked by
    the partner DUT and presented on its MI port (where the AxiRam
    absorbs them); the read path is symmetric.
    """
    log = logging.getLogger(f"loopback.{direction}")
    log.setLevel(logging.INFO)

    # Silence unused-parameter warnings; ram is referenced implicitly
    # because the DUT's MI traffic terminates in it.
    del ram

    log.info("[%s] AXI write: addr=0x%x len=%d (SI=%db, MI=%db)",
             direction, TEST_ADDR, len(payload),
             si_data_width_bits, mi_data_width_bits)
    await await_with_message(
        master.write(TEST_ADDR, payload),
        timeout_ns=AXI_WRITE_TIMEOUT_NS,
        what=(f"AXI write completion on {direction} bus "
              f"(addr=0x{TEST_ADDR:x}, len={len(payload)} B)"),
        dut=dut,
    )

    log.info("[%s] AXI read:  addr=0x%x len=%d", direction, TEST_ADDR, len(payload))
    read_op = await await_with_message(
        master.read(TEST_ADDR, len(payload)),
        timeout_ns=AXI_READ_TIMEOUT_NS,
        what=(f"AXI read completion on {direction} bus "
              f"(addr=0x{TEST_ADDR:x}, len={len(payload)} B)"),
        dut=dut,
    )
    read_data = bytes(read_op.data)

    if read_data != payload:
        for i, (w, r) in enumerate(zip(payload, read_data)):
            if w != r:
                log.error("[%s] mismatch at byte %d: wrote 0x%02x, read 0x%02x",
                          direction, i, w, r)
        raise AssertionError(
            f"[{direction}] read data does not match written data "
            f"(wrote {len(payload)} B, read {len(read_data)} B)"
        )

    log.info("[%s] PASS: %d bytes round-tripped through FDI loopback",
             direction, len(payload))


# -------------------------------------------------------------------------
# cocotb tests
# -------------------------------------------------------------------------

@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_forward_loopback(dut):
    """Forward path: u_dut1 SI -> FDI -> u_dut2 MI."""
    bfms = await bring_up(dut)
    await _do_loopback(
        dut,
        direction="FWD",
        master=bfms["d1_master"],
        ram=bfms["d2_ram"],
        si_data_width_bits=D1_AXI_DATA_WIDTH,
        mi_data_width_bits=D2_AXI_DATA_WIDTH,
        payload=_make_payload(seed=0xA0, length=TEST_LEN_BYTES),
    )
    await ClockCycles(dut.clk, 200)


@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_reverse_loopback(dut):
    """Reverse path: u_dut2 SI -> FDI -> u_dut1 MI."""
    bfms = await bring_up(dut)
    await _do_loopback(
        dut,
        direction="REV",
        master=bfms["d2_master"],
        ram=bfms["d1_ram"],
        si_data_width_bits=D2_AXI_DATA_WIDTH,
        mi_data_width_bits=D1_AXI_DATA_WIDTH,
        payload=_make_payload(seed=0xB0, length=TEST_LEN_BYTES),
    )
    await ClockCycles(dut.clk, 200)


@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_both_directions(dut):
    """Run forward and reverse paths concurrently to exercise both FDI lanes."""
    bfms = await bring_up(dut)

    fwd = cocotb.start_soon(_do_loopback(
        dut,
        direction="FWD",
        master=bfms["d1_master"],
        ram=bfms["d2_ram"],
        si_data_width_bits=D1_AXI_DATA_WIDTH,
        mi_data_width_bits=D2_AXI_DATA_WIDTH,
        payload=_make_payload(seed=0xC0, length=TEST_LEN_BYTES),
    ))
    rev = cocotb.start_soon(_do_loopback(
        dut,
        direction="REV",
        master=bfms["d2_master"],
        ram=bfms["d1_ram"],
        si_data_width_bits=D2_AXI_DATA_WIDTH,
        mi_data_width_bits=D1_AXI_DATA_WIDTH,
        payload=_make_payload(seed=0xD0, length=TEST_LEN_BYTES),
    ))

    await fwd
    await rev
    await ClockCycles(dut.clk, 200)
    dut._log.info("Both directions PASS")
