# Table of Contents

- [1. Module Overview](#1-module-overview)
  - [1.1 Purpose and Function](#11-purpose-and-function)
  - [1.2 Key Features](#12-key-features)
- [2. Parameter List](#2-parameter-list)
- [3. Interface Signals](#3-interface-signals)
  - [3.1 Clock and Reset](#31-clock-and-reset)
  - [3.2 APB Slave Interface](#32-apb-slave-interface)
  - [3.3 AXI Master (RX) – AR Channel](#33-axi-master-rx--ar-channel)
  - [3.4 AXI Master (RX) – R Channel](#34-axi-master-rx--r-channel)
  - [3.5 AXI Master (RX) – AW Channel](#35-axi-master-rx--aw-channel)
  - [3.6 AXI Master (RX) – W and B Channels](#36-axi-master-rx--w-and-b-channels)
  - [3.7 AXI Slave (TX) – AR Channel](#37-axi-slave-tx--ar-channel)
  - [3.8 AXI Slave (TX) – R Channel](#38-axi-slave-tx--r-channel)
  - [3.9 AXI Slave (TX) – AW, W, B Channels](#39-axi-slave-tx--aw-w-b-channels)
  - [3.10 PHY and FDI (Flit Data Interface)](#310-phy-and-fdi-flit-data-interface)
  - [3.11 Interrupt and Error (to Error Handler)](#311-interrupt-and-error-to-error-handler)
  - [3.12 UCIe / External Control and Status](#312-ucie--external-control-and-status)
  - [3.13 DFT](#313-dft)
- [4. Software Operation Guide](#4-software-operation-guide)
  - [4.1 Register Programming Offsets](#41-register-programming-offsets)
- [5. Interrupts](#5-interrupts)
- [6. Activation Flow](#6-activation-flow)
  - [6.1 Credit Management Type](#61-credit-management-type)
  - [6.2 Activation Start](#62-activation-start)
  - [6.3 Deactivation Start](#63-deactivation-start)
    - [6.3.1 Deactivation Sequence Flow](#631-deactivation-sequence-flow)
  - [6.4 Activation/Deactivation Interrupt](#64-activationdeactivation-interrupt)
  - [6.5 PM Entry / LinkReset / LinkDisabled Sequence](#65-pm-entry--linkreset--linkdisabled-sequence)
    - [6.5.1 PM Entry SW Sequence](#651-pm-entry-sw-sequence)
    - [6.5.2 Link Disable SW Sequence](#652-link-disable-sw-sequence)
    - [6.5.3 Link Reset SW Sequence](#653-link-reset-sw-sequence)
- [7. Debugging Features](#7-debugging-features)
  - [7.1 AXI ID mismatch error](#71-axi-id-mismatch-error)
  - [7.2 LinkReset](#72-linkreset)
  - [7.3 R/B response error debug feature](#73-rb-response-error-debug-feature)
  - [7.4 WRITE_EARLY_RESPONSE](#74-write_early_response)

# AOU_CORE_TOP Integration Guide

## 1. Module Overview

Figure 1 shows high level block diagram of AOU CORE TOP.

![Figure 1 - AOU Core Top](images/block_diagram.png)

### 1.1 Purpose and Function

The AOU_CORE_TOP is a bridge between AXI interface and the UCIe FDI interface, defined in AoU
standard, AXI over UCIe Protocol Specification v0.7.

To achieve low latency, AOU_CORE directly handles signals related to the UCIe FDI interface
data flow control and processes data in 64-byte chunks in a cut-through manner, without
converting them to 256-byte flit data. It receives AXI messages from its own AXI slave
interface, packs them into 64-byte chunks, and transmits these chunks to the remote AoU device via UCIe. The remote AoU receives the 64-byte chunks from the UCIe FDI interface, unpacks them into AXI messages, and delivers the data through its AXI master interface.
It supports flow control for all exceptional cases defined in the UCIe standard. First, it handles
the chunk valid/cancel signal, including the alternative implementation method described in the
UCIe specification. Second, it handles the stall request signal received from the D2D Adapter
while maintaining the Flit-aligned boundary.

Interoperability is also supported when the remote device uses a different AXI data width.
AOU_CORE supports a configurable number of Resource Plane(RPs), with both the number of
RPs and each RP’s AXI data width fully parameterizable. A dedicated field in the SFR allows
software to configure the target RP, enabling flexible RP mapping. For each RP, the AW, W and
AR channel support three arbitration modes: Round Robin, AXI QoS scheme, and Port QoS
scheme. Additionally, a starvation-prevention mechanism is implemented to ensure fair
arbitration across all RP channels.

The block consists of the following sub blocks

- AOU_CORE
  - AOU_CORE_RP
    Manages a AXI interface for write request, read request, write data, read data and write response busses
  - AOU_CORE_SFR
    This implements control and status register of the AOU core. It has a 32bit APB interface for programming. It configures all the blocks in the core.
  - AOU_TX_CORE
    This block packs the arbitrated AXI channels, credits, and activation messages and packs them into 64 byte FDI chunks. It follows AOU specifications to pack the messages into 256 byte flit data. It then passes it onto UCIe controller over the FDI interface for transmission.
  - AOU_CRD_CTRL
    This block manages credits available for TX. It gets remote credits available from AOU_RX_CORE, and used credits from AOU_TX_CORE and creates final credits that can be used for TX.
  - AOU_RX_CORE
    This block processed 64 byte FDI chunks received by UCIe controller and passed to the core over the FDI interface. It decodes different message types which encapsulate different AXI channel transactions. These messages are buffered and then passed onto AOU_CORE_RP for presenting the transaction to its corresponding AXI interface.
  - AOU_TX_FDI_IF
    This block receives 64 byte data chunks from AOU_TX_CORE and buffers them. It does handshake with UCIe controller FDI RX interface and passes the data chunks downstream to be sent to remote chiplet.
  - AOU_ACT_CTRL
    This block manages activation and deactivation control of the AOU bridge. It initiates activate and deactivate messages to remote AOU bridge when configured via APB.
- AOU_FIFO_RP
  This block buffers decoded messages from AOU_RX_CORE. It separates the messages based on resource plane (RP) indicator and writes them into dedicated FIFOs. These FIFOs feed the corresponding AOU_CORE_RP which manage a single AXI interface.
- ASYNC_APB_BRIDGE
  This block synchronizes APB transactions to the local core clock.

### 1.2 Key Features

- Single APB interface
  Configuration/control/status register access

- Multiple AXI master & slave interface
  - Configurable RP port & RP remapping supported
  - Supports variable data widths and burst length requests. Configurable FIFO Depth
- UCIe 256B latency-optimized flit(Format 6) support only
- Message packing and unpacking are handled in a unit of 64 bytes, corresponding to the
- FDI data width (64B@1 GHz).
- Selectable Early response by setting SFR8
- Selectable 32B and 64B FDI mode
- Parameterized  number of Resource Plane and each RP’s AXI data width
- RP Remapping
- QoS scheme between RP with AW, W, AR channel
- Interoperability with different data width remote die
- Handling of flit cancel and stall request as specified in the UCIe specification
- Selectable AXI Aggregator added for BUS efficiency

---

## 2. Parameter List

| Parameter | Type | Default / Note | Description |
| :---- | :---- | :---- | :---- |
| RP_COUNT | parameter | 2 | Number of receive ports (AXI M/S pairs). |
| RP0_RX_AW_FIFO_DEPTH | parameter | 44 | RX AW FIFO depth for RP0. |
| RP0_RX_AR_FIFO_DEPTH | parameter | 44 | RX AR FIFO depth for RP0. |
| RP0_RX_W_FIFO_DEPTH | parameter | 88 | RX W FIFO depth for RP0. |
| RP0_RX_R_FIFO_DEPTH | parameter | 88 | RX R FIFO depth for RP0. |
| RP0_RX_B_FIFO_DEPTH | parameter | 44 | RX B FIFO depth for RP0. |
| RP1_RX_AW_FIFO_DEPTH | parameter | 44 | RX AW FIFO depth for RP1. |
| RP1_RX_AR_FIFO_DEPTH | parameter | 44 | RX AR FIFO depth for RP1. |
| RP1_RX_W_FIFO_DEPTH | parameter | 88 | RX W FIFO depth for RP1. |
| RP1_RX_R_FIFO_DEPTH | parameter | 88 | RX R FIFO depth for RP1. |
| RP1_RX_B_FIFO_DEPTH | parameter | 44 | RX B FIFO depth for RP1. |
| RP2_RX_AW_FIFO_DEPTH | parameter | 44 | RX AW FIFO depth for RP2. |
| RP2_RX_AR_FIFO_DEPTH | parameter | 44 | RX AR FIFO depth for RP2. |
| RP2_RX_W_FIFO_DEPTH | parameter | 88 | RX W FIFO depth for RP2. |
| RP2_RX_R_FIFO_DEPTH | parameter | 88 | RX R FIFO depth for RP2. |
| RP2_RX_B_FIFO_DEPTH | parameter | 44 | RX B FIFO depth for RP2. |
| RP3_RX_AW_FIFO_DEPTH | parameter | 44 | RX AW FIFO depth for RP3. |
| RP3_RX_AR_FIFO_DEPTH | parameter | 44 | RX AR FIFO depth for RP3. |
| RP3_RX_W_FIFO_DEPTH | parameter | 88 | RX W FIFO depth for RP3. |
| RP3_RX_R_FIFO_DEPTH | parameter | 88 | RX R FIFO depth for RP3. |
| RP3_RX_B_FIFO_DEPTH | parameter | 44 | RX B FIFO depth for RP3. |
| RP0_AXI_DATA_WD | parameter | 512 | AXI data width for RP0 (bits). |
| RP1_AXI_DATA_WD | parameter | 512 | AXI data width for RP1 (bits). |
| RP2_AXI_DATA_WD | parameter | 512 | AXI data width for RP2 (bits). |
| RP3_AXI_DATA_WD | parameter | 512 | AXI data width for RP3 (bits). |
| AXI_PEER_DIE_MAX_DATA_WD | parameter | 1024 | Maximum peer data width (bits). |
| APB_ADDR_WD | parameter | 32 | APB address width. |
| APB_DATA_WD | parameter | 32 | APB data width. |
| S_RD_MO_CNT | parameter | 32 | Slave read outstanding count. |
| S_WR_MO_CNT | parameter | 32 | Slave write outstanding count. |
| M_RD_MO_CNT | parameter | 32 | Master read outstanding count. |
| M_WR_MO_CNT | parameter | 32 | Master write outstanding count. |
| RP_AXI_DATA_WD_MAX | localparam | max4(RP0..RP3_AXI_DATA_WD) | Maximum AXI data width across RPs. |
| RP_AXI_STRB_WD_MAX | localparam | RP_AXI_DATA_WD_MAX/8 | Maximum strobe width. |
| AXI_ADDR_WD | localparam | 64 | AXI address width. |
| AXI_ID_WD | localparam | 10 | AXI ID width. |
| AXI_LEN_WD | localparam | 8 | AXI length field width. |
| AXI_MAX_STRB_WD | localparam | AXI_PEER_DIE_MAX_DATA_WD/8 | Maximum strobe width for peer data. |
| AW_AR_FIFO_WIDTH | localparam | (derived) | Combined width for AW/AR FIFO payload. |
| B_FIFO_WIDTH | localparam | (derived) | B channel FIFO payload width. |
| R_FIFO_EXT_DATA_WIDTH | localparam | (derived) | R channel extended metadata width. |

---

## 3. Interface Signals

### 3.1 Clock and Reset

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_CLK | input | 1 | Core system clock (AOU_CORE and AOU_FIFO_RP). |
| I_RESETN | input | 1 | Active-low asynchronous reset. |
| I_PCLK | input | 1 | APB clock (slave side of async bridge). |
| I_PRESETN | input | 1 | APB domain reset. |

### 3.2 APB Slave Interface

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_AOU_APB_SI0_PSEL | input | 1 | APB select. |
| I_AOU_APB_SI0_PENABLE | input | 1 | APB enable. |
| I_AOU_APB_SI0_PADDR | input | APB_ADDR_WD | APB address. |
| I_AOU_APB_SI0_PWRITE | input | 1 | APB write. |
| I_AOU_APB_SI0_PWDATA | input | APB_DATA_WD | APB write data. |
| O_AOU_APB_SI0_PRDATA | output | APB_DATA_WD | APB read data. |
| O_AOU_APB_SI0_PREADY | output | 1 | APB ready. |
| O_AOU_APB_SI0_PSLVERR | output | 1 | APB slave error. |

### 3.3 AXI Master (RX) – AR Channel

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| O_AOU_RX_AXI_M_ARID | output | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Read address ID. |
| O_AOU_RX_AXI_M_ARADDR | output | [RP_COUNT-1:0][AXI_ADDR_WD-1:0] | Read address. |
| O_AOU_RX_AXI_M_ARLEN | output | [RP_COUNT-1:0][AXI_LEN_WD-1:0] | Burst length. |
| O_AOU_RX_AXI_M_ARSIZE | output | [RP_COUNT-1:0][2:0] | Transfer size. |
| O_AOU_RX_AXI_M_ARBURST | output | [RP_COUNT-1:0][1:0] | Burst type. |
| O_AOU_RX_AXI_M_ARLOCK | output | [RP_COUNT-1:0] | Lock. |
| O_AOU_RX_AXI_M_ARCACHE | output | [RP_COUNT-1:0][3:0] | Cache attributes. |
| O_AOU_RX_AXI_M_ARPROT | output | [RP_COUNT-1:0][2:0] | Protection. |
| O_AOU_RX_AXI_M_ARQOS | output | [RP_COUNT-1:0][3:0] | QoS. |
| O_AOU_RX_AXI_M_ARVALID | output | [RP_COUNT-1:0] | AR valid. |
| I_AOU_RX_AXI_M_ARREADY | input | [RP_COUNT-1:0] | AR ready. |

### 3.4 AXI Master (RX) – R Channel

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_AOU_TX_AXI_M_RID | input | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Read data ID. |
| I_AOU_TX_AXI_M_RDATA | input | [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] | Read data. |
| I_AOU_TX_AXI_M_RRESP | input | [RP_COUNT-1:0][1:0] | Read response. |
| I_AOU_TX_AXI_M_RLAST | input | [RP_COUNT-1:0] | Read last. |
| I_AOU_TX_AXI_M_RVALID | input | [RP_COUNT-1:0] | R valid. |
| O_AOU_TX_AXI_M_RREADY | output | [RP_COUNT-1:0] | R ready. |

### 3.5 AXI Master (RX) – AW Channel

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| O_AOU_RX_AXI_M_AWID | output | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Write address ID. |
| O_AOU_RX_AXI_M_AWADDR | output | [RP_COUNT-1:0][AXI_ADDR_WD-1:0] | Write address. |
| O_AOU_RX_AXI_M_AWLEN | output | [RP_COUNT-1:0][AXI_LEN_WD-1:0] | Burst length. |
| O_AOU_RX_AXI_M_AWSIZE | output | [RP_COUNT-1:0][2:0] | Transfer size. |
| O_AOU_RX_AXI_M_AWBURST | output | [RP_COUNT-1:0][1:0] | Burst type. |
| O_AOU_RX_AXI_M_AWLOCK | output | [RP_COUNT-1:0] | Lock. |
| O_AOU_RX_AXI_M_AWCACHE | output | [RP_COUNT-1:0][3:0] | Cache attributes. |
| O_AOU_RX_AXI_M_AWPROT | output | [RP_COUNT-1:0][2:0] | Protection. |
| O_AOU_RX_AXI_M_AWQOS | output | [RP_COUNT-1:0][3:0] | QoS. |
| O_AOU_RX_AXI_M_AWVALID | output | [RP_COUNT-1:0] | AW valid. |
| I_AOU_RX_AXI_M_AWREADY | input | [RP_COUNT-1:0] | AW ready. |

### 3.6 AXI Master (RX) – W and B Channels

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| O_AOU_RX_AXI_M_WDATA | output | [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] | Write data. |
| O_AOU_RX_AXI_M_WSTRB | output | [RP_COUNT-1:0][RP_AXI_STRB_WD_MAX-1:0] | Write strobe. |
| O_AOU_RX_AXI_M_WLAST | output | [RP_COUNT-1:0] | Write last. |
| O_AOU_RX_AXI_M_WVALID | output | [RP_COUNT-1:0] | W valid. |
| I_AOU_RX_AXI_M_WREADY | input | [RP_COUNT-1:0] | W ready. |
| I_AOU_TX_AXI_M_BID | input | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Write response ID. |
| I_AOU_TX_AXI_M_BRESP | input | [RP_COUNT-1:0][1:0] | Write response. |
| I_AOU_TX_AXI_M_BVALID | input | [RP_COUNT-1:0] | B valid. |
| O_AOU_TX_AXI_M_BREADY | output | [RP_COUNT-1:0] | B ready. |

### 3.7 AXI Slave (TX) – AR Channel

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_AOU_TX_AXI_S_ARID | input | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Read address ID. |
| I_AOU_TX_AXI_S_ARADDR | input | [RP_COUNT-1:0][AXI_ADDR_WD-1:0] | Read address. |
| I_AOU_TX_AXI_S_ARLEN | input | [RP_COUNT-1:0][AXI_LEN_WD-1:0] | Burst length. |
| I_AOU_TX_AXI_S_ARSIZE | input | [RP_COUNT-1:0][2:0] | Transfer size. |
| I_AOU_TX_AXI_S_ARBURST | input | [RP_COUNT-1:0][1:0] | Burst type. |
| I_AOU_TX_AXI_S_ARLOCK | input | [RP_COUNT-1:0] | Lock. |
| I_AOU_TX_AXI_S_ARCACHE | input | [RP_COUNT-1:0][3:0] | Cache attributes. |
| I_AOU_TX_AXI_S_ARPROT | input | [RP_COUNT-1:0][2:0] | Protection. |
| I_AOU_TX_AXI_S_ARQOS | input | [RP_COUNT-1:0][3:0] | QoS. |
| I_AOU_TX_AXI_S_ARVALID | input | [RP_COUNT-1:0] | AR valid. |
| O_AOU_TX_AXI_S_ARREADY | output | [RP_COUNT-1:0] | AR ready. |

### 3.8 AXI Slave (TX) – R Channel

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| O_AOU_RX_AXI_S_RID | output | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Read data ID. |
| O_AOU_RX_AXI_S_RDATA | output | [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] | Read data. |
| O_AOU_RX_AXI_S_RRESP | output | [RP_COUNT-1:0][1:0] | Read response. |
| O_AOU_RX_AXI_S_RLAST | output | [RP_COUNT-1:0] | Read last. |
| O_AOU_RX_AXI_S_RVALID | output | [RP_COUNT-1:0] | R valid. |
| I_AOU_RX_AXI_S_RREADY | input | [RP_COUNT-1:0] | R ready. |

### 3.9 AXI Slave (TX) – AW, W, B Channels

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_AOU_TX_AXI_S_AWID | input | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Write address ID. |
| I_AOU_TX_AXI_S_AWADDR | input | [RP_COUNT-1:0][AXI_ADDR_WD-1:0] | Write address. |
| I_AOU_TX_AXI_S_AWLEN | input | [RP_COUNT-1:0][AXI_LEN_WD-1:0] | Burst length. |
| I_AOU_TX_AXI_S_AWSIZE | input | [RP_COUNT-1:0][2:0] | Transfer size. |
| I_AOU_TX_AXI_S_AWBURST | input | [RP_COUNT-1:0][1:0] | Burst type. |
| I_AOU_TX_AXI_S_AWLOCK | input | [RP_COUNT-1:0] | Lock. |
| I_AOU_TX_AXI_S_AWCACHE | input | [RP_COUNT-1:0][3:0] | Cache attributes. |
| I_AOU_TX_AXI_S_AWPROT | input | [RP_COUNT-1:0][2:0] | Protection. |
| I_AOU_TX_AXI_S_AWQOS | input | [RP_COUNT-1:0][3:0] | QoS. |
| I_AOU_TX_AXI_S_AWVALID | input | [RP_COUNT-1:0] | AW valid. |
| O_AOU_TX_AXI_S_AWREADY | output | [RP_COUNT-1:0] | AW ready. |
| I_AOU_TX_AXI_S_WDATA | input | [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] | Write data. |
| I_AOU_TX_AXI_S_WSTRB | input | [RP_COUNT-1:0][RP_AXI_STRB_WD_MAX-1:0] | Write strobe. |
| I_AOU_TX_AXI_S_WLAST | input | [RP_COUNT-1:0] | Write last. |
| I_AOU_TX_AXI_S_WVALID | input | [RP_COUNT-1:0] | W valid. |
| O_AOU_TX_AXI_S_WREADY | output | [RP_COUNT-1:0] | W ready. |
| O_AOU_RX_AXI_S_BID | output | [RP_COUNT-1:0][AXI_ID_WD-1:0] | Write response ID. |
| O_AOU_RX_AXI_S_BRESP | output | [RP_COUNT-1:0][1:0] | Write response. |
| O_AOU_RX_AXI_S_BVALID | output | [RP_COUNT-1:0] | B valid. |
| I_AOU_RX_AXI_S_BREADY | input | [RP_COUNT-1:0] | B ready. |

### 3.10 PHY and FDI (Flit Data Interface)

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_PHY_TYPE | input | 1 | PHY width mode (e.g., 32B vs 64B). |
| I_FDI_PL_32B_VALID | input | 1 | 32B flit valid from PHY. |
| I_FDI_PL_32B_DATA | input | 256 | 32B flit data. |
| I_FDI_PL_32B_FLIT_CANCEL | input | 1 | 32B flit cancel. |
| I_FDI_PL_64B_VALID | input | 1 | 64B flit valid from PHY. |
| I_FDI_PL_64B_DATA | input | 512 | 64B flit data. |
| I_FDI_PL_64B_FLIT_CANCEL | input | 1 | 64B flit cancel. |
| I_FDI_PL_32B_TRDY | input | 1 | 32B PHY ready. |
| I_FDI_PL_32B_STALLREQ | input | 1 | 32B stall request. |
| I_FDI_PL_32B_STATE_STS | input | [3:0] | 32B state status. |
| O_FDI_LP_32B_DATA | output | 256 | 32B flit data to PHY. |
| O_FDI_LP_32B_VALID | output | 1 | 32B flit valid. |
| O_FDI_LP_32B_IRDY | output | 1 | 32B link ready. |
| O_FDI_LP_32B_STALLACK | output | 1 | 32B stall acknowledge. |
| I_FDI_PL_64B_TRDY | input | 1 | 64B PHY ready. |
| I_FDI_PL_64B_STALLREQ | input | 1 | 64B stall request. |
| I_FDI_PL_64B_STATE_STS | input | [3:0] | 64B state status. |
| O_FDI_LP_64B_DATA | output | 512 | 64B flit data to PHY. |
| O_FDI_LP_64B_VALID | output | 1 | 64B flit valid. |
| O_FDI_LP_64B_IRDY | output | 1 | 64B link ready. |
| O_FDI_LP_64B_STALLACK | output | 1 | 64B stall acknowledge. |

### 3.11 Interrupt and Error (to Error Handler)

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| INT_REQ_LINKRESET | output | 1 | Link reset request. |
| INT_SI0_ID_MISMATCH | output | 1 | Slave interface ID mismatch. |
| INT_MI0_ID_MISMATCH | output | 1 | Master interface ID mismatch. |
| INT_EARLY_RESP_ERR | output | 1 | Early response error. |
| INT_ACTIVATE_START | output | 1 | Activate start. |
| INT_DEACTIVATE_START | output | 1 | Deactivate start. |

### 3.12 UCIe / External Control and Status

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| I_INT_FSM_IN_ACTIVE | input | 1 | Initialization done / FSM in active state indicator. |
| I_MST_BUS_CLEANY_COMPLETE | input | 1 | Master bus cleany complete. |
| I_SLV_BUS_CLEANY_COMPLETE | input | 1 | Slave bus cleany complete. |
| O_AOU_ACTIVATE_ST_DISABLED | output | 1 | Activation state disabled. |
| O_AOU_ACTIVATE_ST_ENABLED | output | 1 | Activation state enabled. |
| O_AOU_REQ_LINKRESET | output | 1 | AOU link reset request. |

### 3.13 DFT

| Signal | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| TIEL_DFT_MODESCAN | input | 1 | DFT mode scan tie-off. |

---

## 4. Software operation Guide

This section gives information about operation guide for the AOU_CORE.

### 4.1 Register Programming Offsets

| Register  | Offset  | Bit field name  | Bit   field | Type  | Reset value |
| :---: | :---: | :---: | :---: | :---: | :---: |
| IP_VERSION  | 0x0000  |  |  |  | 0x00010000 |
|  |  | MAJOR_VERSION  | [31:16]  |   RO  | 0x0001 |
|  |  | MINOR_VERSION  | [15:0]  |   RO  | 0x0 |
| AOU_CON0  | 0x0004  |  |  |  | 0x00000000 |
|  |  | Rsvd | [31:28] |   RO  |   0x0 |
|  |  | RP3_ERROR_INFO_ACCESS_EN  | [27] |   RW |   0x0 |
|  |  | RP2_ERROR_INFO_ACCESS_EN  | [26] |   RW |   0x0 |
|  |  | RP1_ERROR_INFO_ACCESS_EN  | [25] |   RW |   0x0 |
|  |  | RP0_ERROR_INFO_ACCESS_EN  | [24] |   RW |   0x0 |
|  |  | RP3_AXI_AGGREGATOR_EN  | [23] |   RW |   0x0 |
|  |  | RP2_AXI_AGGREGATOR_EN  | [22] |   RW |   0x0 |
|  |  | RP1_AXI_AGGREGATOR_EN  | [21] |   RW |   0x0 |
|  |  | RP0_AXI_AGGREGATOR_EN  | [20] |   RW |   0x0 |
|  |  | TX_LP_MODE_THRESHOLD | [19:12] |   RW |   0x0 |
|  |  | TX_LP_MODE | [11] |   RW |   0x0 |
|  |  | Rsvd  | [10:5]  | RO  | 0x0 |
|  |  | AOU_SW_RESET  | [4]  | RW  | 0x0 |
|  |  | CREDIT_MANAGE  | [3]  | RW  | 0x0 |
|  |  | AXI_SPLIT_TR_EN  | [2]  | RW  | 0x0 |
|  |  | WRITEFULL_MSGTYPE_EN  | [1]  | RW  | 0x0 |
|  |  | Rsvd  | [0]  | RO  | 0x0 |
| AOU_INIT  | 0x0008  |  |  |  | 0x00000004 |
|  |  | Rsvd  | [31:20]  | RO  | 0x0 |
|  |  | MST_TR_COMPLETE  | [10]  | RO  | 0x1 |
|  |  | SLV_TR_COMPLETE  | [9]  | RO  | 0x1 |
|  |  | INT_ACTIVATE_START  | [8]  | W1C  | 0x0 |
|  |  |                              INT_DEACTIVATE_START  | [7]  | W1C  | 0x0 |
|  |  | DEACTIVATE_TIME_OUT_VALUE  | [6:4]  | RW  | 0x0 |
|  |  | ACTIVATE_STATE_DISABLED  | [3]  | RO  | 0x1 |
|  |  | ACTIVATE_STATE_ENABLED  | [2]  | RO  | 0x0 |
|  |  | DEACTIVATE_START  | [1]  | RW  | 0x0 |
|  |  | ACTIVATE_START  | [0]  | RW  | 0x0 |
| AOU_INTERRUPT_MASK | 0x000C  |  |  |  |  |
|  |  | Rsvd  | [31:9]  | RO  | 0x0 |
|  |  | INT_REQ_LINKRESET_ACT_ACK_MASK | [8] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_DEACT_ACK_MASK | [7] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_INVALID_ACTMSG_MASK | [6] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_MSGCREDIT_TIMEOUT_MASK | [5] | RW | 0x0 |
|  |  | INT_EARLY_RESP_MASK | [4] | RW | 0x0 |
|  |  |  INT_MI0_ID_MISMATCH_MASK | [3] | RW | 0x0 |
|  |  | INT_SI0_ID_MISMATCH_MASK | [2] | RW | 0x0 |
|  |  | Rsvd | [1]  | RO  | 0x0 |
|  |  | Rsvd | [0]  | RO  | 0x0 |
| LP_LINKRESET | 0x0010 |  |  |  |  |
|  |  | Rsvd  | [31:14]  | RO  | 0x0 |
|  |  | ACK_TIME_OUT_VALUE  | [13:11]  | RW  | 0x0 |
|  |  | MSGCREDIT_TIME_OUT_VALUE  | [10:8]  |   RW  | 0x0 |
|  |  | ACT_ACK_ERR | [7]  | W1C  | 0x0 |
|  |  | DEACT_ACK_ERR  | [6]  | W1C  | 0x0 |
|  |  | INVALID_ACTMSG_INFO | [5:2]  |   RO  | 0x0 |
|  |  | INVALID_ACTMSG_ERR | [1] | W1C |  |
|  |  | MSGCREDIT_ERR | [0] | W1C |  |
| DEST_RP  | 0x0014 |  |  |  |  |
|  |  | Rsvd  | [31:14]  | RO  | 0x0 |
|  |  | RP3_DEST  | [13:12]  | RW  | 0x3 |
|  |  | Rsvd  | [11:10]  | RO  | 0x0 |
|  |  | RP2_DEST  | [9:8]  | RW  | 0x2 |
|  |  | Rsvd  | [7:6]  | RO  | 0x0 |
|  |  | RP1_DEST  | [5:4]  | RW  | 0x1 |
|  |  | Rsvd  | [3:2]  | RO  | 0x0 |
|  |  | RP0_DEST  | [1:0]  | RW  | 0x0 |
| PRIOR_RP_AXI | 0x0018 |  |  |  |  |
|  |  | Rsvd  | [31:28]  | RO  | 0x0 |
|  |  | AXI_QOS_TO_NP  | [27:24]  | RW  | 0xA |
|  |  | AXI_QOS_TO_HP | [23:20]  | RW  | 0x3 |
|  |  | Rsvd  | [19:18]  | RO  | 0x0 |
|  |  | RP3_PRIOR | [17:16]  | RW  | 0x3 |
|  |  | Rsvd  | [15:14]  | RO  | 0x0 |
|  |  | RP2_PRIOR | [13:12]  | RW  | 0x2 |
|  |  | Rsvd  | [11:10]  | RO  | 0x0 |
|  |  | RP1_PRIOR | [9:8]  | RW  | 0x1 |
|  |  | Rsvd  | [7:6]  | RO  | 0x0 |
|  |  | RP0_PRIOR  | [5:4]  | RW  | 0x0 |
|  |  | Rsvd  | [3:2]  | RO  | 0x0 |
|  |  | ARB_MODE | [1:0]  | RW  | 0x1 |
| PRIOR_TIMER | 0x001C |  |  |  | 0x0 |
|  |  | TIMER_RESOLUTION | [31:16]  | RW  | 0x0 |
|  |  | TIMER_THRESHOLD | [15:0]  | RW  | 0x0 |
| AXI_SPLIT_TR_RP0 | 0x0020 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:16]  | RO  | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8]  | RW  | 0x0 |
|  |  | MAX_ARBURSTLEN | [7:0]  | RW  | 0x0 |
| ERROR_INFO_RP0 | 0x0024 |  |  |  |    0x0 |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR  | [1]  | W1C  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR  | [0]  | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP0  | 0x0028 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:15]  | RO  | 0x0 |
|  |  | WRITE_RESP_DONE  | [14]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR  | [13]  | W1C  | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO  | [12:11]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1]  | RW  | 0x0 |
|  |  | EARLY_BRESP_EN  | [0]  | RO  | 0x0 |
| AXI_ERROR_INFO0_RP0 | 0x002C |  |  |  |  |
|  |  | DEBUG_UPPER_ADDR | [31:0]  | RW  | 0x0 |
| AXI_ERROR_INFO1_RP0  | 0x0030 |  |  |  |  |
|  |  | DEBUG_LOWER_ADDR | [31:0]  | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP0   | 0x0034 |  |  |  |  |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1]  | W1C  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0]  | W1C | 0x0 |
| AXI_SPLIT_TR_RP1 | 0x0038 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:16]  | RO  | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8]  | RW  | 0x0 |
|  |  | MAX_ARBURSTLEN | [7:0]  | RW  | 0x0 |
| ERROR_INFO_RP1 | 0x003C |  |  |  |    0x0 |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR  | [1]  | W1C  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR  | [0]  | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP1 | 0x0040 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:15]  | RO  | 0x0 |
|  |  | WRITE_RESP_DONE  | [14]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR  | [13]  | W1C  | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO  | [12:11]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1]  | RW  | 0x0 |
|  |  | EARLY_BRESP_EN  | [0]  | RO  | 0x0 |
| AXI_ERROR_INFO0_RP1 | 0x0044 |  |  |  |  |
|  |  | DEBUG_UPPER_ADDR | [31:0]  | RW  | 0x0 |
| AXI_ERROR_INFO1_RP1  | 0x0048 |  |  |  |  |
|  |  | DEBUG_LOWER_ADDR | [31:0]  | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP1  | 0x004C |  |  |  |  |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1]  | W1C  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0]  | W1C | 0x0 |
| AXI_SPLIT_TR_RP2 | 0x0050 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:16]  | RO  | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8]  | RW  | 0x0 |
|  |  | MAX_ARBURSTLEN | [7:0]  | RW  | 0x0 |
| ERROR_INFO_RP2 | 0x0054 |  |  |  |    0x0 |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR  | [1]  | W1C  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR  | [0]  | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP2 | 0x0058 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:15]  | RO  | 0x0 |
|  |  | WRITE_RESP_DONE  | [14]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR  | [13]  | W1C  | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO  | [12:11]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1]  | RW  | 0x0 |
|  |  | EARLY_BRESP_EN  | [0]  | RO  | 0x0 |
| AXI_ERROR_INFO0_RP2 | 0x005C |  |  |  |  |
|  |  | DEBUG_UPPER_ADDR | [31:0]  | RW  | 0x0 |
| AXI_ERROR_INFO1_RP2  | 0x0060 |  |  |  |  |
|  |  | DEBUG_LOWER_ADDR | [31:0]  | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP2  | 0x0064 |  |  |  |  |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1]  | W1C  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0]  | W1C | 0x0 |
| AXI_SPLIT_TR_RP3 | 0x0068 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:16]  | RO  | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8]  | RW  | 0x0 |
|  |  | MAX_ARBURSTLEN | [7:0]  | RW  | 0x0 |
| ERROR_INFO_RP3 | 0x006C |  |  |  |    0x0 |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR  | [1]  | W1C  | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR  | [0]  | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP3 | 0x0070 |  |  |  | 0x0 |
|  |  | Rsvd  | [31:15]  | RO  | 0x0 |
|  |  | WRITE_RESP_DONE  | [14]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR  | [13]  | W1C  | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO  | [12:11]  | RO  | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1]  | RW  | 0x0 |
|  |  | EARLY_BRESP_EN  | [0]  | RO  | 0x0 |
| AXI_ERROR_INFO0_RP3 | 0x0074 |  |  |  |  |
|  |  | DEBUG_UPPER_ADDR | [31:0]  | RW  | 0x0 |
| AXI_ERROR_INFO1_RP3  | 0x0078 |  |  |  |  |
|  |  | DEBUG_LOWER_ADDR | [31:0]  | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP3 | 0x007C |  |  |  |  |
|  |  | Rsvd  | [31:22]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO  | [21:12]  | RO  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO  | [11:2]  | RO  | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1]  | W1C  | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0]  | W1C | 0x0 |

## 5. Interrupts

- **INT_ACTIVATE_START**
  An interrupt that occurs when activation of the AoU Protocol layer is required. The interrupt can be cleared by writing '1' to the AOU_CORE.AOU_INIT.INT_ACTIVATE_START SFR.

- **INT_DEACTIVATE_START**
  An interrupt that occurs when deactivation of the AoU Protocol layer is required. The interrupt can be cleared by writing '1' to the AOU_CORE.AOU_INIT.INT_DEACTIVATE_START SFR.

- **INT_SI0_ID_MISMATCH**
  An interrupt that occurs on the AXI Slave Interface when a B or R channel response is received with an ID that was not previously issued as a request. SW can check the mismatched AXI ID by reading AOU_CORE.AXI_SLV_ID_MISMATCH_ERR SFR. The interrupt can be cleared by writing '1' to the AOU_CORE.AXI_SLV_ID_MISMATCH_ERR.SLV_B/RRESP_ERR SFR.

- **INT_MI0_ID_MISMATCH**
  An interrupt that occurs on the AXI Master Interface when a B or R channel response is received with an ID that was not previously issued as a request. SW can check the mismatched AXI ID by reading AOU_CORE.ERROR_INFO SFR. The interrupt can be cleared by writing '1' to the AOU_CORE.ERROR_INFO.SPLIT_B/RID_MISMATCH_ERR SFR.

- **INT_EARLY_RESP_ERR**
  An interrupt that occurs when, due to the Write Early Response feature, a B response has already
  been sent through the AXI Slave Interface, and a subsequent actual B response arrives with an Error. SW can check the ID and error type of the transaction in which the error occurred by reading AOU_CORE.WRITE_EARLY_RESPONSE SFR. The interrupt can be cleared by writing '1' to the AOU_CORE.WRITE_EARLY_RESPONSE.WRITE_RESP_ERR SFR.

- **INT_REQ_LINKRESET**
  An interrupt that occurs when AOU_CORE receives AOU_CORE protocol violation. Refer 7.2 Debugging features, LinkReset. When AOU_CORE receives protocol violation. SW needs to do SW reset AOU_CORE and re-enter activation sequence.

## 6. Activation Flow

The Activation of AOU_CORE begins after the UCIe Link-up process has been successfully
completed. The completion of UCIe link-up is indicated by the **I_INT_FSM_IN_ACTIVE**
signal of the **AOU_CORE_TOP**.
There is no dependency between the activation of the local die and the remote die. Each die may
initiate the activation sequence independently, which means the timing of sending **ActivateReq**
can differ. Both dies must exchange **ActivateReq** and **ActivateAck** messages to transition to the **ENABLED** state, at which point credited messages can be transmitted.

Regardless of its own activation state, a die must send an ActivateAck in response to an
ActivateReq from the other die, to acknowledge receipt of the request.

### 6.1 Credit Management Type

There are two types of Credit Management Type. Since current AOU_SPEC cannot resolve
pending AXI response without Activate again. When Credit Management type is set to 1, during
Deactivated state, AOU_CORE can resolve pending AXI response itself.

It can be configured through AOU_CON0.CREDIT_MANAGE, and the default value is 0.

| Credit Management Type  | Specification  | Description |
| ----- | :---: | ----- |
| 0 (default) | Based on AoU v0.5 | After deactivation, if a new request is received from the remote die, no response message can be sent. To deliver the corresponding response, the system must go through activation again after deactivation. Credit management and transmission availability for both Request-related messages and Response-related messages are controlled together. Credited messages must not be sent, after the DeactivateReq message is sent. Credits must not be sent after the DeactivateAck message is sent. The Activate Interrupt and Deactivate Interrupt that occur in the process of resuming the exchange of response messages impose mandatory requirements to set Activate and Deactivate SFR. |
| 1 | Proposal by BOS | When the AoU Activity state is DEACTIVATE, manage Request-related messages (WREQ, RREQ,WDATA) and Response-related messages (RDATA, WRESP) separately. RDATA, WRESP Credited messages can be sent, after the DeactivateReq message is sent. Credits for RDATA, WRESP messages must be sent after the DeactivateAck message is sent. The Deactivate interrupt only provides a hint indicating that the remote die has started to activate / deactivate. |

### 6.2 Activation Start

Activation can be initiated by setting ACTIVATE_START SFR:
In the current implementation, credits are granted based on the depth of the RX FIFO, so it is
required to ensure that all messages in the RX FIFO are popped before sending the ActivateReq message.

Activation START (via SFR AOU_INIT.ACTIVATE_START SFR)

- Activation can be triggered by setting ACTIVATE_START.
- Activation does not proceed until I_INT_FSM_IN_ACTIVE is asserted, since no flits can be transmitted beforehand.
  Therefore, it is allowed to set the ACTIVATE_START SFR before I_INT_FSM_IN_ACTIVE is asserted. If it is set before the assertion, the activation process will automatically proceed after I_INT_FSM_IN_ACTIVE becomes asserted.
- AOU_INIT.ACTIVATE_START SFR is automatically cleared to 0 once the activation is completed and AOU_ACTIVATE_STATE transitions to ENABLED.

### 6.3 Deactivation Start

Deactivation is initiated by setting the AOU_INIT.DEACTIVATE_START register. Setting this
register does not immediately trigger sending a DeactivateReq message. The detailed conditions
and sequence for deactivation can be found in the **Deactivation Sequence Flow** section. This
section will only describe AOU_INIT.DEACTIVATE_TIME_OUT_VALUE SFR.

- When software initiates a DeactivateReq by setting the SFR, there may still be outstanding requests that have not yet left AOU_CORE FDI outputs.
- To handle this safely, a timeout mechanism is implemented to ensure that no valid packets remain in the AOU_TX_CORE.
- If software guarantees that all responses to its issued requests have been received before setting the deactivation start SFR, the deactivate TIME_OUT_VALUE (AOU_INIT.DEACTIVATE_TIME_OUT_VALUE SFR) can be safely configured to a shorter duration.

The ACTIVATION_OP field encodes deactivation messages as follows:

- 2 = DeactivateReq
- 3= DeactivateAck

#### 6.3.1 Deactivation Sequence Flow

Once the local die issues a DeactivateReq, it can no longer provide responses to transactions
initiated by the remote die. If the remote die continues to send requests or waits for responses
without being notified, it may enter a hang state.

To manage this safely, the remote die must take explicit action upon receiving a DeactivateReq:

1. Immediately generate an interrupt to the CPU to inform the system software that a DeactivateReq has been received and that it must set the DEACTIVATE_START SFR. Although deactivation of the local die and the remote die operate independently, it is essential at the system level to communicate the deactivation & activation state through interrupts. This ensures that system software is explicitly informed of deactivation events and prevents the remote die from continuing to expect a response that will never arrive, thereby avoiding hang conditions.
2. This approach guarantees that once deactivation is initiated, both dies can coordinate the transition into safe and consistent DISABLED state.
3. If the software on both dies can explicitly coordinate to guarantee that all outstanding transactions have been completed and that no new transactions will be issued, then such a complicated implementation would not be necessary.

![Figure 2 - CREDIT_MANAGE 0 Deactivate Sequence Flow](images/deactivate_seq0.png)

![Figure 3 - CREDIT_MANAGE 1 Deactivate Sequence Flow](images/deactivate_seq1.png)

This system provides a bus cleanly-completion mechanism:

- Slave bus cleanly indicates whether the local die has received all responses to the requests it sent to the remote die.
- Master bus cleanly indicates whether the remote die has received all responses to the requests it sent to the local die.

After the local die sends a DeactivateReq, if the remote die issues a new request and expects a
response, the system must re-enter the activation sequence before any response can be provided.
Before sending a new ActivateReq, the Rx FIFO must be completely emptied – that is, all
messages must be popped.

After deactivation, the credit count is reset, and during the subsequent activation process, credits
are advertised based on the RX FIFO depth.

Therefore, before sending an ActivateReq, the local die must confirm, as described in the local
die’s sequence 10.1, that all messages in the RX FIFO have been popped.

To meet satisfy the condition in the local die’s sequence 10.1, no backpressure must occur on the
local die’s MI AW/AR/W channels.

### 6.4 Activation/Deactivation Interrupt

| Interrupt  | Description |
| ----- | ----- |
| INT_ACTIVATE_START | When this interrupt is detected, either the AOU_INIT.ACTIVATE_START SFR must be set to 1. When AOU_INIT.ACTIVATE_STATE_ENABLED becomes 1, you must write 1 to the AOU_INIT.INT_ACTIVATE_START W1C SFR must be set to 1. An interrupt occurs when the following conditions are met while both AOU_INIT.ACTIVATE_START SFR is not set. There is a message to send When AOU_CON0.CREDIT_MANAGE is set to 0, if a new request arrives from the remote die after the local die has sent a DeactivateReq, this interrupt is asserted because the local die is required to return a response to the remote die. When AOU_CON0.CREDIT_MANAGE is set to 1, this interrupt can also be asserted if a new request after the remote die has sent a DeactivateReq. There is a response to be received (I_SLV_BUS_CLEANY_COMPLETE == 0) When AOU_CON0.CREDIT_MANAGE is set to 0, this interrupt can be asserted if the local die issues new AXI requests after the remote die has sent a DeactivateReq. An ActivateReq message is received from the remote die.  |
| INT_DEACTIVATE_START | When AOU_CON0.CREDIT_MANAGE is set to 0, if the interrupt is detected, the master IP must stop sending new request messages and the AOU_INIT.DEACTIVATE_START SFR must be set to 1. When AOU_CON0.CREDIT_MANAGE is set to 1, if the interrupt is detected, this interrupt serves only as a hint that the remote die intends to deactivate. The local die can continue sending request messages. Once all messages have been sent, the AOU_INIT.DEACTIVATE_START SFR must be set. Otherwise, the remote die may end up in a state where it can never send requests again. When AOU_INIT.ACTIVATE_STATE_DISABLED becomes 1,  SW must write 1 to the AOU_INIT.INT_DEACTIVATE_START W1C SFR must be set to 1. An interrupt can be asserted when AOU_INIT.DEACTIVATE_START SFR is not set and the local die receives a DeactivateReq message from the remote die. |

###

### 6.5 PM Entry / LinkReset / LinkDisabled Sequence

For PM entry / LinkReset / LinkDisable entry sequence, UCIE_CORE should check AOU_CORE state and try to change state. For this sequence, resolving pending AXI transactions is necessary.

Since current AOU SPEC has no way to send AXI responses after sending DeactiveReq. CREDIT_MANAGE = 0 (Type 0) is matched with current AOU_SPEC. For this case, SW needs to check whether there is pending AXI transaction.

#### 6.51 PM Entry SW Sequence

1. Write AOU_INIT.DEACTIVATE_START to 1.

2. Polling AOU_INIT.ACTIVATE_STATE_DISABLED and AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.
   2.1 Although AOU_CORE state becomes DISABLED, there may be pending AXI transactions.
   2.2 AOU_CORE issues Interrupt for resolving pending AXI transactions.
   2.3 Activate AOU_CORE and resolve pending AXI transactions.
   2.4 Deactivate AOU_CORE

3. Polling AOU_INIT.ACTIVATE_STATE_DISABLED and AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

4. Do PM Entry Sequence on UCIE_CORE.

![Figure 4 - PM Entry Sequence](images/pm_entry.png)

#### 6.52 Link Disable SW Sequence

Same as PM entry, before doing UCIe state transition, AOU_CORE needs to be Disabled properly.

1. Write AOU_INIT.DEACTIVATE_START to 1.

2. Polling AOU_INIT.ACTIVATE_STATE_DISABLED and AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.
   2.1 Although AOU_CORE state becomes DISABLED, there may be pending AXI transactions.
   2.2 AOU_CORE issues Interrupt for resolving pending AXI transactions.
   2.3 Activate AOU_CORE and resolve pending AXI transactions.
   2.4 Deactivate AOU_CORE

3. Polling AOU_INIT.ACTIVATE_STATE_DISABLED and AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

4. Do LinkReset / LinkDisable Sequence on UCIE_CORE.

#### 6.53 Link Reset SW Sequence

If AOU_CORE faces an uncorrectable error (ex. AOU SPEC violation), AOU_CORE sends LinkReset to CPU and D2D adapter. LinkReset indicates that an error has occurred which requires the Link to go down.

While handling LinkReset, SW needs  to do AOU_CORE SW reset by setting AOU_CON0.AOU_SW_RESET.

## 7. Debugging Features

AOU_CORE includes several features for debugging. SFR name including ERROR is related to
debugging features.

### 7.1. AXI ID mismatch error

For AOU_CORE AXI interface, core generates interrupt when it receives AXI ID that was not
Issued earlier. If error is detected on AXI slave interface, SW can check the AXI ID on
AXI_SLV_ID_MISMATCH_ERR field and clear the interrupt by setting AXI_SLV_ID_MISMATCH_ERR.AXI_SLV_*ID_MISMATCH_ERR. If error is detected on AXI master interface, SW can check the AXI ID on ERROR_INFO field and clear the interrupt by setting ERROR_INFO.SPLIT_*ID_MISMATCH_ERR.

### 7.2. LinkReset

For Activation/Deactivation error, core drives interrupt by INT_REQ_LINKRESET and
AOU_REQ_LINKRESET to FDI. The Protocol layer requests the CPU to Reset the Link. There are
several cases for which AOU_REQ_LINKRESET is asserted.

- **Request to Acknowledge message timeout error**
  If the remote die does not return an Acknowledge within the configured timeout, the local die may report a Request to Acknowledge timeout. As per the AOU_SPEC, when the local die issues an Activation or Deactivation request, the remote die should respond with an Acknowledgement message indicating successful receipt of the request. If no Acknowledgement message is received before the timeout value, the AOU_CORE asserts INT_AOU_REQ_LINKRESET to CPU and SW should do LinkReset sequence. SW can configure timeout value by setting LP_LINKRESET.ACK_TIME_OUT_VALUE.

- **Invalid ACTMSG**
  If an ACTMSG that is not permitted in the current Activation state is received, AOU_CORE will treat it as a protocol violation and assert INT_AOU_REQ_LINKRESET. In AOU specification, each activation state defines allowable ACTMSG opcodes. Any ACTMSG outside this will trigger INT_AOU_REQ_LINKRESET in the next cycle. SW can debug Invalid OPCODE of ACTMSG and should do LinkReset sequence.

- **ActivateAck to MSGCREDIT timeout error**
  MSGCREDIT should send to the remote die indicating how many resource planes the local die has. If local die does not receive MSGCREDIT within the configured timeout, local die may report msgcredit error.  SW should do a LinkReset sequence. SW can configure timeout value by setting LP_LINKRESET.MSGCREDIT_TIME_OUT_VALUE.

### 7.3. R/B response error debug feature

When AOU_CORE receives AXI R/B response error from master interface, it internally stores
the AXI ID, Address, Resp in a dedicated FIFO. After Remote die receive AXI response error, it
can access this error information by AXI read. Error information is stored up to 4 entries.

Unlike normal AXI transactions, accessing the error information requires an explicit enable
and a dedicated address. First, set DEBUG_UPPER_ADDR and DEBUG_LOWER_ADDR to
define the target address and set ERROR_INFO_ACCESS_EN to 1 to enable access. When an
AXI read is issued to the address, the remote die can read out the corresponding error
information. Remote die can write 1 to the dedicated address to pop the debug information.

### 7.4. WRITE_EARLY_RESPONSE

The error is generated when Write Early Response is enabled and a BRESP error arrives for a
previously sent early response. When a BRESP error occurs, an interrupt is issued and SW can
check the BRESP AXI ID and error type by reading SFR and clear the error.
