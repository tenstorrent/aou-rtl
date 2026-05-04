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

"""AOU_CORE_TOP dual-DUT FDI loopback stress test (cocotb).

  - Forward path : AxiMaster on u_dut1 SI -> FDI -> AxiRam on u_dut2 MI
  - Reverse path : AxiMaster on u_dut2 SI -> FDI -> AxiRam on u_dut1 MI
  - 1024 randomized AXI write/read transaction pairs per direction.
  - Each pair uses a randomized 64 B payload + randomized 64 B-aligned
    address within the 4 KB AxiRam window.
  - Random idle of 0..128 core-clock cycles between pairs to exercise
    the LP-mode engage/disengage transitions on DUT1 (which is brought
    up with tx_lp_mode=1, tx_lp_mode_threshold=0).
  - Pass criterion : every read byte-for-byte matches its prior write.

Common DUT bring-up (clock start, reset, BFM construction, APB activate)
lives in dut_setup.py and is shared with the CSR reset readback test.
"""

from __future__ import annotations

import logging
import random

import cocotb
from cocotb.triggers import ClockCycles

from axi_helpers import D1_AXI_DATA_WIDTH, D2_AXI_DATA_WIDTH
from dut_setup import (
    AXI_READ_TIMEOUT_NS,
    AXI_WRITE_TIMEOUT_NS,
    OVERALL_TIMEOUT_US,
    RAM_SIZE_BYTES,
    await_with_message,
    bring_up,
)


# Per-iteration AXI payload size (also the address alignment).
TEST_LEN_BYTES = 64

# Number of randomized write/read pairs per direction.
NUM_ITERATIONS = 1024

# Random idle (core clock cycles) between consecutive pairs. 0 cycles =
# back-to-back stress, 128 cycles = link goes fully idle so DUT1's LP
# engaged trigger + pop-gate seed override are exercised on every pair.
MAX_DELAY_CYCLES = 128

# Progress-log cadence (in iterations).
LOG_EVERY = 128


# -------------------------------------------------------------------------
# Direction helpers (1024 randomized write+read pairs)
# -------------------------------------------------------------------------

async def _do_loopback_stream(
    dut,
    *,
    direction: str,
    master,
    ram,
    si_data_width_bits: int,
    mi_data_width_bits: int,
    seed: int,
    num_iterations: int = NUM_ITERATIONS,
) -> None:
    """Run ``num_iterations`` randomized write+read pairs through the loopback.

    Each iteration picks a fresh 64 B payload and a fresh 64 B-aligned
    AxiRam address, performs an AXI write, then an AXI read of the same
    slot, and asserts byte-for-byte equality. A random 0..MAX_DELAY_CYCLES
    core-clock idle is inserted between pairs to exercise the LP-mode
    engage/disengage transitions on DUT1.

    ``master`` and ``ram`` are pre-constructed by ``bring_up`` so that
    every DUT input is held at clean 0 across the reset window.
    """
    log = logging.getLogger(f"loopback.{direction}")
    log.setLevel(logging.INFO)

    # ram is implicitly used (terminates the partner DUT's MI traffic).
    del ram

    rng = random.Random(seed)
    num_slots = RAM_SIZE_BYTES // TEST_LEN_BYTES

    log.info("[%s] starting %d random write/read pairs (SI=%db, MI=%db, "
             "len=%d B, max_delay=%d cyc, seed=0x%x)",
             direction, num_iterations,
             si_data_width_bits, mi_data_width_bits,
             TEST_LEN_BYTES, MAX_DELAY_CYCLES, seed)

    for i in range(num_iterations):
        addr = rng.randrange(num_slots) * TEST_LEN_BYTES
        payload = bytes(rng.randrange(256) for _ in range(TEST_LEN_BYTES))

        await await_with_message(
            master.write(addr, payload),
            timeout_ns=AXI_WRITE_TIMEOUT_NS,
            what=(f"AXI write iter {i}/{num_iterations} on {direction} "
                  f"(addr=0x{addr:x}, len={TEST_LEN_BYTES} B)"),
            dut=dut,
        )
        read_op = await await_with_message(
            master.read(addr, TEST_LEN_BYTES),
            timeout_ns=AXI_READ_TIMEOUT_NS,
            what=(f"AXI read iter {i}/{num_iterations} on {direction} "
                  f"(addr=0x{addr:x}, len={TEST_LEN_BYTES} B)"),
            dut=dut,
        )
        read_data = bytes(read_op.data)

        if read_data != payload:
            first_mismatch = -1
            for j, (w, r) in enumerate(zip(payload, read_data)):
                if w != r:
                    log.error("[%s] iter %d byte %d: wrote 0x%02x, read 0x%02x",
                              direction, i, j, w, r)
                    if first_mismatch < 0:
                        first_mismatch = j
            raise AssertionError(
                f"[{direction}] iter {i}/{num_iterations} mismatch "
                f"at addr=0x{addr:x} (first bad byte={first_mismatch})"
            )

        delay = rng.randrange(MAX_DELAY_CYCLES + 1)
        if delay:
            await ClockCycles(dut.clk, delay)

        if (i + 1) % LOG_EVERY == 0:
            log.info("[%s]  iter %d / %d ok", direction, i + 1, num_iterations)

    log.info("[%s] PASS: %d randomized pairs round-tripped through FDI loopback",
             direction, num_iterations)


# -------------------------------------------------------------------------
# cocotb tests
# -------------------------------------------------------------------------

@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_forward_loopback(dut):
    """Forward path: u_dut1 SI -> FDI -> u_dut2 MI."""
    bfms = await bring_up(dut)
    await _do_loopback_stream(
        dut,
        direction="FWD",
        master=bfms["d1_master"],
        ram=bfms["d2_ram"],
        si_data_width_bits=D1_AXI_DATA_WIDTH,
        mi_data_width_bits=D2_AXI_DATA_WIDTH,
        seed=0xA0_C0FFEE,
    )
    await ClockCycles(dut.clk, 200)


@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_reverse_loopback(dut):
    """Reverse path: u_dut2 SI -> FDI -> u_dut1 MI."""
    bfms = await bring_up(dut)
    await _do_loopback_stream(
        dut,
        direction="REV",
        master=bfms["d2_master"],
        ram=bfms["d1_ram"],
        si_data_width_bits=D2_AXI_DATA_WIDTH,
        mi_data_width_bits=D1_AXI_DATA_WIDTH,
        seed=0xB0_C0FFEE,
    )
    await ClockCycles(dut.clk, 200)


@cocotb.test(timeout_time=OVERALL_TIMEOUT_US, timeout_unit="us")
async def test_both_directions(dut):
    """Run forward and reverse paths concurrently to exercise both FDI lanes."""
    bfms = await bring_up(dut)

    fwd = cocotb.start_soon(_do_loopback_stream(
        dut,
        direction="FWD",
        master=bfms["d1_master"],
        ram=bfms["d2_ram"],
        si_data_width_bits=D1_AXI_DATA_WIDTH,
        mi_data_width_bits=D2_AXI_DATA_WIDTH,
        seed=0xC0_C0FFEE,
    ))
    rev = cocotb.start_soon(_do_loopback_stream(
        dut,
        direction="REV",
        master=bfms["d2_master"],
        ram=bfms["d1_ram"],
        si_data_width_bits=D2_AXI_DATA_WIDTH,
        mi_data_width_bits=D1_AXI_DATA_WIDTH,
        seed=0xD0_C0FFEE,
    ))

    await fwd
    await rev
    await ClockCycles(dut.clk, 200)
    dut._log.info("Both directions PASS (%d pairs each)", NUM_ITERATIONS)
