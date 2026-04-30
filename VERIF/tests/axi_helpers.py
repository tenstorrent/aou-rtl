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

"""AxiBus / ApbBus signal-map factories for the AOU harness interfaces.

The harness ``aou_cocotb_top`` exposes its AXI and APB interfaces with
cocotbext-axi's canonical naming (``s_axi_d1_*``, ``m_axi_d1_*``,
``s_axi_d2_*``, ``m_axi_d2_*``, ``apb1_*``, ``apb2_*``) so we can use
``AxiBus.from_prefix()`` / ``ApbBus.from_prefix()`` directly. This
module provides thin convenience factories so the test file does not
have to repeat the prefix strings.

Bus widths:
    s_axi_d1, m_axi_d1 : 512-bit data, 64-bit addr, 10-bit ID
    s_axi_d2, m_axi_d2 : 256-bit data, 64-bit addr, 10-bit ID
    apb1, apb2         : 32-bit data, 32-bit addr (AOU CSR slave)
"""

from __future__ import annotations

from cocotbext.axi import ApbBus, AxiBus


D1_AXI_DATA_WIDTH = 512
D2_AXI_DATA_WIDTH = 256
AXI_ADDR_WIDTH = 64
AXI_ID_WIDTH = 10
APB_ADDR_WIDTH = 32
APB_DATA_WIDTH = 32


def make_d1_si_bus(dut) -> AxiBus:
    """DUT1 slave interface (driven by an AxiMaster from cocotb)."""
    return AxiBus.from_prefix(dut, "s_axi_d1")


def make_d1_mi_bus(dut) -> AxiBus:
    """DUT1 master interface (terminated by an AxiRam in cocotb)."""
    return AxiBus.from_prefix(dut, "m_axi_d1")


def make_d2_si_bus(dut) -> AxiBus:
    """DUT2 slave interface (driven by an AxiMaster from cocotb)."""
    return AxiBus.from_prefix(dut, "s_axi_d2")


def make_d2_mi_bus(dut) -> AxiBus:
    """DUT2 master interface (terminated by an AxiRam in cocotb)."""
    return AxiBus.from_prefix(dut, "m_axi_d2")


def make_d1_apb_bus(dut) -> ApbBus:
    """DUT1 APB slave interface (driven by an ApbMaster from cocotb)."""
    return ApbBus.from_prefix(dut, "apb1")


def make_d2_apb_bus(dut) -> ApbBus:
    """DUT2 APB slave interface (driven by an ApbMaster from cocotb)."""
    return ApbBus.from_prefix(dut, "apb2")
