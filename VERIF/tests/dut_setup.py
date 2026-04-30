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

"""Shared cocotb test setup for the AOU dual-DUT FDI loopback harness.

Centralises the watchdog, signal-init, BFM construction, clocking, reset,
and APB activate plumbing used by every test in this directory so that
new tests (e.g. CSR reset readback) can reuse the same machinery without
import side effects from another test module.

Public API:
    OVERALL_TIMEOUT_US, RESET_TIMEOUT_NS, APB_WRITE_TIMEOUT_NS,
    APB_READ_TIMEOUT_NS, AXI_WRITE_TIMEOUT_NS, AXI_READ_TIMEOUT_NS

    await_with_message(awaitable, *, timeout_ns, what, dut)

    init_dut_inputs(dut)
    make_bfms(dut) -> dict
    start_clocks(dut)         (coroutine)
    reset_dut(dut)            (coroutine)
    apb_activate(dut, bfms)   (coroutine)
    bring_up(dut, *, activate=True) -> dict   (coroutine)
"""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.result import SimTimeoutError
from cocotb.triggers import ClockCycles, with_timeout
from cocotb.utils import get_sim_time
from cocotbext.axi import ApbMaster, AxiMaster, AxiRam

from axi_helpers import (
    APB_DATA_WIDTH,
    make_d1_apb_bus,
    make_d1_mi_bus,
    make_d1_si_bus,
    make_d2_apb_bus,
    make_d2_mi_bus,
    make_d2_si_bus,
)


# Core clock @ 1 GHz, APB clock @ 100 MHz (matches INTEG/constraints/aou_core_top.sdc).
CORE_CLK_PERIOD_NS = 1
APB_CLK_PERIOD_NS = 10

# Sized to comfortably hold this TB's small AXI payloads.
RAM_SIZE_BYTES = 0x1000


# -------------------------------------------------------------------------
# Watchdog budgets
# -------------------------------------------------------------------------
# Overall hard backstop per @cocotb.test (sim time, microseconds).
OVERALL_TIMEOUT_US      = 500

# Per-phase fine-grained budgets (sim time, nanoseconds). Tune if your
# simulator is slow or your scenario legitimately needs more time.
RESET_TIMEOUT_NS        = 5_000     # 20 pclk @ 10ns + headroom
APB_WRITE_TIMEOUT_NS    = 50_000    # one APB activate write per DUT
APB_READ_TIMEOUT_NS     = 50_000    # one APB read of a single CSR
AXI_WRITE_TIMEOUT_NS    = 100_000   # 64 B write through FDI loopback
AXI_READ_TIMEOUT_NS     = 100_000   # 64 B read through FDI loopback


# -------------------------------------------------------------------------
# Watchdog helper
# -------------------------------------------------------------------------

# Signals dumped on a watchdog timeout. Best-effort -- missing signals are
# silently skipped, so the same dump works in any phase.
_WATCHDOG_DUMP_SIGNALS = (
    "resetn", "presetn",
    "apb1_psel", "apb1_penable", "apb1_pwrite", "apb1_pready", "apb1_pslverr",
    "apb2_psel", "apb2_penable", "apb2_pwrite", "apb2_pready", "apb2_pslverr",
    "s_axi_d1_awvalid", "s_axi_d1_awready",
    "s_axi_d1_wvalid",  "s_axi_d1_wready",  "s_axi_d1_wlast",
    "s_axi_d1_bvalid",  "s_axi_d1_bready",
    "s_axi_d1_arvalid", "s_axi_d1_arready",
    "s_axi_d1_rvalid",  "s_axi_d1_rready",  "s_axi_d1_rlast",
    "s_axi_d2_awvalid", "s_axi_d2_awready",
    "s_axi_d2_wvalid",  "s_axi_d2_wready",  "s_axi_d2_wlast",
    "s_axi_d2_bvalid",  "s_axi_d2_bready",
    "s_axi_d2_arvalid", "s_axi_d2_arready",
    "s_axi_d2_rvalid",  "s_axi_d2_rready",  "s_axi_d2_rlast",
    "m_axi_d1_awvalid", "m_axi_d1_awready",
    "m_axi_d1_arvalid", "m_axi_d1_arready",
    "m_axi_d2_awvalid", "m_axi_d2_awready",
    "m_axi_d2_arvalid", "m_axi_d2_arready",
)


async def await_with_message(awaitable, *, timeout_ns: int, what: str, dut):
    """Await ``awaitable`` with a sim-time budget and a named-phase error.

    On timeout, log a ``WATCHDOG: stuck waiting for '<what>' for <N> ns``
    line plus a snapshot of the signals in ``_WATCHDOG_DUMP_SIGNALS``,
    then raise ``AssertionError`` so the test fails (rather than spinning).
    """
    try:
        return await with_timeout(awaitable, timeout_ns, "ns")
    except SimTimeoutError:
        now = get_sim_time("ns")
        dut._log.error(
            "WATCHDOG: stuck waiting for '%s' for %d ns "
            "(sim time now %.0f ns)",
            what, timeout_ns, now,
        )
        for sig in _WATCHDOG_DUMP_SIGNALS:
            try:
                handle = getattr(dut, sig)
                dut._log.error("  %-20s = %s", sig, handle.value)
            except (AttributeError, Exception):
                pass
        raise AssertionError(
            f"WATCHDOG: stuck waiting for '{what}' for {timeout_ns} ns"
        )


# -------------------------------------------------------------------------
# Setup helpers
# -------------------------------------------------------------------------

# All DUT input signals on every AXI bus, grouped by who drives them in
# normal operation. We pre-set these to 0 before constructing the BFMs to
# work around a cocotbext-axi quirk: AxiMaster/AxiRam/ApbMaster's stream
# constructor samples each data/addr/strb signal and, if it reads X,
# writes X right back via setimmediatevalue
# (cocotbext/axi/stream.py:122-133). Any signal that is X at construction
# time stays X until the first real transaction drives it -- which is
# enough to feed X into the AOU TX path during reset/APB-activate and
# propagate into the FDI granule packing logic. Under VCS that produces a
# hard X-prop failure; Verilator hides it because it 2-states everything
# to 0.

# AXI master-driven inputs to a slave-side DUT bus (AxiMaster drives these).
S_AXI_INPUT_SIGS = (
    "awid",  "awaddr", "awlen", "awsize", "awburst", "awlock",
    "awcache", "awprot", "awqos", "awvalid",
    "wdata", "wstrb", "wlast", "wvalid",
    "bready",
    "arid",  "araddr", "arlen", "arsize", "arburst", "arlock",
    "arcache", "arprot", "arqos", "arvalid",
    "rready",
)

# AXI slave-driven inputs to a master-side DUT bus (AxiRam drives these).
M_AXI_INPUT_SIGS = (
    "awready",
    "wready",
    "bid", "bresp", "bvalid",
    "arready",
    "rid", "rdata", "rresp", "rlast", "rvalid",
)

# APB master-driven inputs to a slave-side DUT bus (ApbMaster drives these).
# pstrb is required by ApbBus' signal map even though AOU does not consume
# it; the harness exposes a dangling pstrb port so the bus introspection
# succeeds and the BFM idle-drives it to 0.
APB_INPUT_SIGS = (
    "psel", "penable", "paddr", "pwrite", "pwdata", "pstrb",
)


def init_dut_inputs(dut) -> None:
    """Set every DUT input to a clean 0 before any BFM is constructed.

    Uses ``setimmediatevalue`` (no scheduler delta needed) so that the
    very next AxiMaster/AxiRam/ApbMaster constructor sees 0, not X, on
    the data bus signals it samples in __init__.
    """
    dut.resetn.setimmediatevalue(0)
    dut.presetn.setimmediatevalue(0)
    for prefix in ("s_axi_d1", "s_axi_d2"):
        for sig in S_AXI_INPUT_SIGS:
            handle = getattr(dut, f"{prefix}_{sig}", None)
            if handle is not None:
                handle.setimmediatevalue(0)
    for prefix in ("m_axi_d1", "m_axi_d2"):
        for sig in M_AXI_INPUT_SIGS:
            handle = getattr(dut, f"{prefix}_{sig}", None)
            if handle is not None:
                handle.setimmediatevalue(0)
    for prefix in ("apb1", "apb2"):
        for sig in APB_INPUT_SIGS:
            handle = getattr(dut, f"{prefix}_{sig}", None)
            if handle is not None:
                handle.setimmediatevalue(0)


def make_bfms(dut) -> dict:
    """Construct all six BFMs. Must be called *after* init_dut_inputs.

    Returns a dict so the test code can pull out whichever master/ram/apb
    triple the direction under test needs. BFMs are tied to the matching
    reset (resetn for AXI, presetn for APB) so they hold their idle
    outputs at 0 across the reset window.
    """
    return {
        "d1_master": AxiMaster(
            make_d1_si_bus(dut), dut.clk, dut.resetn, reset_active_level=False,
        ),
        "d2_master": AxiMaster(
            make_d2_si_bus(dut), dut.clk, dut.resetn, reset_active_level=False,
        ),
        "d1_ram": AxiRam(
            make_d1_mi_bus(dut), dut.clk, dut.resetn,
            reset_active_level=False, size=RAM_SIZE_BYTES,
        ),
        "d2_ram": AxiRam(
            make_d2_mi_bus(dut), dut.clk, dut.resetn,
            reset_active_level=False, size=RAM_SIZE_BYTES,
        ),
        "d1_apb": ApbMaster(
            make_d1_apb_bus(dut), dut.pclk, dut.presetn, reset_active_level=False,
        ),
        "d2_apb": ApbMaster(
            make_d2_apb_bus(dut), dut.pclk, dut.presetn, reset_active_level=False,
        ),
    }


async def start_clocks(dut) -> None:
    """Launch the core and APB clocks."""
    cocotb.start_soon(Clock(dut.clk, CORE_CLK_PERIOD_NS, units="ns").start())
    cocotb.start_soon(Clock(dut.pclk, APB_CLK_PERIOD_NS, units="ns").start())


async def reset_dut(dut) -> None:
    """Hold both resets low for 20 APB cycles, then release.

    Wrapped under RESET_TIMEOUT_NS so a misconfigured / non-toggling pclk
    fails with a clear watchdog message instead of hanging silently.
    Resets were already pre-driven to 0 in init_dut_inputs(); we just
    re-assert here for clarity, then deassert after the hold window.
    """
    dut.resetn.value = 0
    dut.presetn.value = 0
    await await_with_message(
        ClockCycles(dut.pclk, 20),
        timeout_ns=RESET_TIMEOUT_NS,
        what="20 pclk cycles for reset assertion (is pclk toggling?)",
        dut=dut,
    )
    dut.resetn.value = 1
    dut.presetn.value = 1
    dut._log.info("Resets de-asserted")


# AOU activation register: write 0x1 to paddr 0x8 to enable the DUT.
APB_ACTIVATE_PADDR = 0x8
APB_ACTIVATE_PWDATA = 0x1


async def apb_activate(dut, bfms: dict) -> None:
    """Drive the post-reset AOU activate write on both DUTs via ApbMaster.

    Replaces the SV-side initial/forever activate loop. Each test resets
    the design, so this must run after every reset deassertion.
    """
    payload = APB_ACTIVATE_PWDATA.to_bytes(APB_DATA_WIDTH // 8, "little")
    for label, key in (("DUT1", "d1_apb"), ("DUT2", "d2_apb")):
        await await_with_message(
            bfms[key].write(APB_ACTIVATE_PADDR, payload),
            timeout_ns=APB_WRITE_TIMEOUT_NS,
            what=(f"APB activate write on {label} "
                  f"(paddr=0x{APB_ACTIVATE_PADDR:x}, "
                  f"pwdata=0x{APB_ACTIVATE_PWDATA:x})"),
            dut=dut,
        )
    dut._log.info("APB activation complete on both DUTs")
    # Match the existing testbench's 50-pclk settle delay before AXI traffic.
    await ClockCycles(dut.pclk, 50)


async def bring_up(dut, *, activate: bool = True) -> dict:
    """Pre-init -> construct BFMs -> start clocks -> reset [-> APB activate].

    Returns the dict of BFMs (see make_bfms) so the test can pick the
    master/ram/apb triple for whichever direction it is exercising.

    Order matters:
      1. init_dut_inputs zeroes everything BEFORE any BFM exists, so the
         BFMs' constructor-time sample() captures clean 0s on data signals.
      2. make_bfms instantiates all six BFMs while inputs are still at 0.
         From now on they will idle-drive 0 instead of latching X.
      3. start_clocks launches the simulator clocks. Resets are already 0.
      4. reset_dut holds reset low for 20 pclk then releases.
      5. apb_activate drives the AOU activate write on both DUTs through
         their ApbMaster (skipped when ``activate=False`` so callers like
         the CSR reset readback test can observe virgin reset state).
    """
    init_dut_inputs(dut)
    bfms = make_bfms(dut)
    await start_clocks(dut)
    await reset_dut(dut)
    if activate:
        await apb_activate(dut, bfms)
    return bfms
