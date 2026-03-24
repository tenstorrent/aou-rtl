Apache License Release

AOU_CORE
Microarchitecture specification

Version 1.00, Feb.27 2026

# BOS Semiconductors

**Contents**

- [1. Introduction](#1-introduction)
  - [1.1. Overview](#11-overview)
- [2. Features](#2-features)
  - [2.1. Basic features](#21-basic-features)
- [3. Architecture](#3-architecture)
  - [3.1. Block diagram](#31-block-diagram)
  - [3.2. TX_CORE](#32-tx_core)
    - [3.2.1. TX_CORE QoS Scheme](#321-tx_core-qos-scheme)
  - [3.3. RX_CORE](#33-rx_core)
  - [3.4. Message FIFO](#34-message-fifo)
  - [3.5. Data width converter](#35-data-width-converter)
  - [3.6. AXI Transaction Splitter](#36-axi-transaction-splitter)
  - [3.7. Write Early Response Controller](#37-write-early-response-controller)
  - [3.8. AXI Aggregator](#38-axi-aggregator)
  - [3.9. Credit Controller](#39-credit-controller)
  - [3.10. RP Remapping](#310-rp-remapping)
  - [3.11. UCIe Flit cancel mechanism](#311-ucie-flit-cancel-mechanism)
- [4. Interrupt](#4-interrupt)
- [5. Error](#5-error)
- [6. Integration guide](#6-integration-guide)
  - [6.1. I/O descriptions](#61-io-descriptions)
  - [6.2. Clocks](#62-clocks)
  - [6.3. Resets](#63-resets)
  - [6.4. Configurable Parameters](#64-configurable-parameters)
- [7. Software operation guide](#7-software-operation-guide)
  - [7.1. SFR setting](#71-sfr-setting)
  - [7.2. Debugging features](#72-debugging-features)
  - [7.3. Activation & Deactivation Flow](#73-activation--deactivation-flow)
    - [7.3.1. Credit Management Type](#731-credit-management-type)
    - [7.3.2. Activation start](#732-activation-start)
    - [7.3.3. Deactivation start](#733-deactivation-start)
    - [7.3.4. Deactivation Sequence Flow](#734-deactivation-sequence-flow)
    - [7.3.5. Activation/Deactivation Interrupt](#735-activationdeactivation-interrupt)
    - [7.3.6. PM entry / LinkReset / LinkDisabled sequence](#736-pm-entry--linkreset--linkdisabled-sequence)
- [8. PPA](#8-ppa)
  - [8.1. Performance](#81-performance)
  - [8.2. Power](#82-power)
  - [8.3. Area](#83-area)
- [Appendix A. Records of Changes](#appendix-a-records-of-changes)
- [Appendix B. Referenced Documents](#appendix-b-referenced-documents)

# 1. Introduction

This microarchitecture specification includes detailed functional
description of AOU_CORE.

The contents of this document are given as follows. Section 1 is for
overview. Section 2 is for features, implementation specific features,
and asumptions. In section 3, the architecture and operation of AoU IP
are given. Section 4 includes the integration guidelines such as clocks,
reset, interrupts, errors, and I/O description. Section 5 includes the
software programming guide including register map. Section 6 includes
performance, power and area information.

## 1.1. Overview

The AOU_CORE is a bridge between AXI interface and the UCIe FDI
interface, defined in AoU standard v0.7 spec.
To achieve low latency, AOU_CORE directly handles signals related to the
UCIe FDI interface data flow control and processes data in 64-byte or
32-bytes chunks in a cut-through manner, without converting them to
256-byte flit data. It receives AXI messages from its own AXI slave
interface, packs them into 64-byte or 32-byte chunks, and transmits
these chunks to the remote AoU device via UCIe. The remote AoU receives
the 64-byte or 32-byte chunks from the UCIe FDI interface, unpacks them
into AXI messages, and delivers the data through its AXI master
interface.
The one-way AoU latency, measured from the AXI input of the local device
to the AXI output of the remote device over a back-to-back connection in
a single clock domain, is 7 cycles for read requests, 8 cycles for read
data, 9 cycles for write requests, 9 cycles for write data, and 6 cycles
for write responses. For applications using UCIe, including those with
some CDC domains, the round-trip time (RTT) latency from an AXI read
request to the corresponding AXI read response through this AoU IP over
UCIe is approximately 45 cycles, excluding the memory latency of the
remote device.

To achieve high efficiency, all TX requests and data messages are packed
in a compact format, ensuring that no AoU payload slots are wasted. The
current payload is even updated when the UCIe stalls the current chunk
and space remains available. As a result, the throughput matches the
values defined in the AoU specification. In each cycle, the RX can
process the maximum number of messages defined in the AoU standard: 4
read requests, 4 write requests, 2 read data, 2 write data, and 12 write
responses, respectively.

It supports flow control for all exceptional cases defined in the UCIe
standard. First, it handles the chunk valid/cancel signal, including the
alternative implementation method described in the UCIe specification.
Second, it handles the stall request signal received from the D2D
Adapter while maintaining the Flit-aligned boundary.
Interoperability is also supported when the remote device uses a
different AXI data width.

AOU_CORE supports a configurable number of Resource Plane(RPs), with
both the number of RPs and each RP's AXI data width fully
parameterizable. A dedicated field in the SFR allows software to
configure the target RP, enabling flexible RP mapping. For each RP, the
AW, W and AR channel support three arbitration modes: Round Robin, AXI
QoS scheme, and Port QoS scheme. Additionally, a starvation-prevention
mechanism is implemented to ensure fair arbitration across all RP
channels.

The operating frequency of AOU_CORE targets 1 GHz and meets timing
requirements without relying on multi-cycle paths. The TX buffer is
configured with a minimal number of FIFO entries, while the RX Data
buffer is designed with 88 entries to avoid any performance drop caused
by AoU. The entry size takes into account the round-trip latency for
credit consumption and return.

# 2. Features

<a id="figure-1"></a>
![Figure 1. Block Diagram of AOU_CORE and function description](./media/image1.png)

*Figure 1. Block Diagram of AOU_CORE and function description*

## 2.1. Basic features

- Single APB slave interface

  - Configuration/control/status register access

- Multiple AXI slave & master interface

  - Configurable RP port & RP remapping supported

  - Supports variable data widths and burst length requests.
    Configurable FIFO Depth

- UCIe 256B latency-optimized flit(Format 6) support only

- Message packing and unpacking are handled in a unit of 64 bytes or 32
  bytes, corresponding to the FDI data width (64B@1 GHz or 32@1 GHz).

- Selectable Early response by setting SFR

- 64B and 32B FDI mode support

- Configurable number of Resource Plane and each RP's AXI data width

- RP Remapping

- QoS scheme between RP with AW, W, AR channel

- Interoperability with different data width remote die

- Handling of flit cancel and stall request as specified in the UCIe
  specification

- Selectable AXI Aggregator added for BUS efficiency

- According to the AoU specification, except for the AXI data width, the
  parameters AXI_ADDR_WD, AXI_ID_WD, and AXI_LEN_WD are fixed. Porting
  to match the width of the connected ports must be handled externally
  to AOU_CORE_TOP.

- Returning read data that exceeds the AXI data width of the remote die
  is treated as a violation.

- For a Read Request received from the remote die,
  if ARSIZE is 5 or less, it returns a Read Data message with DLEN =
  2'b00;
  if ARSIZE is 6, it returns a Read Data message with DLEN = 2'b01;
  if ARSIZE is 7, it returns a Read Data message with DLEN = 2'b10;
  Accordingly, if the local die receives a read data message from the
  remote die whose size is smaller than its own AXI data width, it
  duplicates the data to match its own AXI data width.

# 3. Architecture

This section describes the block diagram of AOU_CORE.

## 3.1. Block diagram

<a id="figure-2"></a>
![Figure 2. Architecture of AOU_CORE](./media/image2.png)

*Figure 2. Architecture of AOU_CORE*

[Figure 2](#figure-2) shows block diagram of current AOU_CORE. The AXI interface
supports both Master and Slave transactions for message transmission and
reception. AOU_CORE may issue AR and AW requests to the remote die using
the local bus width. Consequently, R-data from the remote die and W-data
from the local die are constrained to the local bus width. However,
since the remote die can transmit data with variable DLEN, AOU_CORE must
support all possible data lengths. This functionality is managed by
AXI4MUX_3X1_TOP, which receives variable DLEN data from RX_CORE, aligns
it to the local bus width, and splits the burst length into segments
matching the local bus burst size.

Inside AXI4MUX_3X1_TOP, AXI aggregator is added for improving bus
utilization. AXI aggregator combines narrow read & write data and send
it to BUS. This functionality may modify AXI Len & Size. For example,
AXI AR with 256-bit size & 16 burst length may transfer into 1024-bit
size & 4 burst length. This operation can be controlled via SFR setting.

AOU_CORE provides 64B FDI interface.

## 3.2. TX_CORE

<a id="figure-3"></a>
![Figure 3. Block Diagram of Single RP AOU_TX_CORE](./media/image3.png)

*Figure 3. Block Diagram of Single RP AOU_TX_CORE*

[Figure 3](#figure-3) shows the simplified block diagram of single RP AOU_TX_CORE.
The module receives AXI messages for Remote Die. AOU_TX_AXI_BUFFER
captures AXI messages from the system bus. When AOU_TX_CORE obtains
sufficient credit from AOU_CRD_CTRL, it packs the AXI message into an
AOU message and stores it in the ring buffer. Once there is enough space
to hold all messages, messages are stored to the ring buffer in
parallel. The ring buffer subsequently performs handshake operations
with the FDI interface.

### 3.2.1. TX_CORE QoS Scheme

<a id="figure-4"></a>
![Figure 4. TX_CORE QoS Scheme](./media/image4.png)

*Figure 4. TX_CORE QoS Scheme*

When multiple RP requests are issued from the TX core, a QoS scheme is
applied.
The TX core supports three QoS schemes: **Round-Robin**, **Port QoS**,
and **AXI QoS**.
Each transaction supports three QoS level: **High, Normal, Low.**

**Round-Robin (ARB_MODE = 2'b00)** :
Round-robin arbitration between valid RP. When a handshake occurs, the
RP that will receive the next grant is determined.
<a id="figure-5"></a>
![Figure 5. Round-Robin arbitration example](./media/image5.png)

*Figure 5. Round-Robin arbitration example*

**Port QoS (ARB_MODE = 2'b01):**
For each RP, the QoS level is configured by an SFR. Arbitration is
performed based on the QoS value is the SFR. The AXI QoS field is not
used for arbitration.

The port QoS is divided into three levels: High, Normal, and Low
priority.
Port QoS can be configured by setting PRIOR_RP_AXI.PRx_PRIOR. A 2-bit
field is used for QoS and supports values from 1 to 3. If the field is
set to 0, it is treated as 1.

By default, arbitration is performed in the order **High → Normal →
Low**. If a timeout occurs while a request is at Normal or Low priority,
the request is promoted and treated as High priority.
Timeout value can be configured by setting PRIOR_TIMER.TIMER_THRESHOLD.
The resolution used for timeout determination can be configured through
PRIOR_TIMER.TIMER_RESOLUTION.

If multiple RPs have the same priority, arbitration among them is
performed in a round-robin manner.
<a id="figure-6"></a>
![Figure 6. Port QoS arbitration example](./media/image6.png)

*Figure 6. Port QoS arbitration example*

**AXI QoS (ARB_MODE = 2'b10):**
For each RP, the QoS level is determined by the value of the AXI QoS
field.
Arbitration is performed based on the AXI QoS value. For the 4-bit AXI
QoS field, boundary of High priority and Normal Priority can be
configured by SFR setting.
The port QoS is divided into three levels: **High**, **Normal**, and
**Low** priority.
By default, arbitration is performed in the order **High → Normal →
Low**. If a timeout occurs while a request is at Normal or Low priority,
the request is promoted and treated as High priority.
If multiple RPs have the same priority, arbitration among them is
performed in a round-robin manner.
<a id="figure-7"></a>
![Figure 7. AXI QoS arbitration example](./media/image7.png)

*Figure 7. AXI QoS arbitration example*

## 3.3. RX_CORE

<a id="figure-8"></a>
![Figure 8. Block Diagram of AOU_RX_CORE](./media/image8.png)

*Figure 8. Block Diagram of AOU_RX_CORE*

[Figure 8](#figure-8) shows the simplified block diagram of AOU_RX_CORE. AOU_RX_CORE
is a submodule that interfaces directly with the D2D adapter, receiving
I_FDI_PL_VALID, I_FDI_PL_DATA, and I_FDI_PL_FLIT_CANCEL signals to
determine the validity of incoming chunks, and unpacking messages in
accordance with the AOU specification. Within RX_CORE, there is a
submodule called RX_FDI_IF, which is designed to handle flit cancel as
defined in the UCIe specification. This module forwards only valid
chunks to the Chunk Decoder.

To ensure that the local die can support AXI transfers regardless of the
AXI data width of the remote die, AOU_RX_CORE integrates both Downsizer
and Upsizer modules internally.

AOU_RX_CORE includes a splitter that can divide burst lengths so that
AXI messages with any burst length from the remote die can be supported
on the local bus. The AW, W, and AR messages received from the remote
die are sent to the AXI Master interface, while the B and R messages
received from the remote die are directed to the AXI Slave interface.
The R data may be smaller than the local die AXI data width depending on
the ARSIZE of the corresponding AR requests, but R 4M1S FIFO duplicate
values so that it is delivered to the AXI Slave interface with the same
width as the local die AXI data width.
Furthermore, the B responses corresponding to the AW and W AXI transfers
issued through the Master interface are routed into the AXI_3X1_MUX
before being sent to the AOU_TX_CORE.

As illustrated in the figure above, the granularity of data transmitted
from the FIFO, whether directed to the bus or to the AXI_3X1_MUX, is
conveyed to the AOU_CRD_CTRL.

<a id="figure-9"></a>
![Figure 9. Architecture of Chunk Decoder](./media/image9.png)

*Figure 9. Architecture of Chunk Decoder*

[Figure 9](#figure-9) shows the architecture of the Chunk Decoder which is central
submodule of RX_CORE. It consists of shift registers and multiple
decoders that decode each message, based on the received valid chunk
along with its associated msg_idx and msg_valid information. Since AXI
messages differ in the number of granules, the time required for
decoding also varies.

For example, a B message has a size of 1 granule and can therefore be
decoded immediately once a valid chunk is received from RX_FDI_IF. In
contrast, Rdata or Wdata, which have a data width of 1024 bits, require
27-30 granules, and thus cannot be decoded immediately. Instead, they
are decoded after approximately three cycles. Because messages of 27-30
granules may span up to four flits during transmission.

## 3.4. Message FIFO

<a id="figure-10"></a>
![Figure 10. Data FIFO](./media/image10.png)

*Figure 10. Data FIFO*

<a id="figure-11"></a>
![Figure 11. Req / Resp FIFO](./media/image11.png)

*Figure 11. Req / Resp FIFO*

The Turn-Around-Time(TAT) of AOU_CORE, including the D2D adaptor, is
approximately 40 ns (equivalent to 40 cycles at 1 GHz). Therefore, the
depth of the AW, AR, and B FIFOs is set to 44 regarding the margin.

The width of the Req and Resp FIFOs is equal to the length of the
corresponding message. Since 12 granules are currently being decoded at
once, up to 4 AW/AR requests and up to 12 B responses can be written
into the FIFO in a single cycle. Therefore, the AW/AR FIFO is
implemented as a 4S1M FIFO and B FIFO is implemented as a 12S1M FIFO.

In contrast, for the Wdata and Rdata FIFOs, the FIFO width and depth is
defined differently.

The width of a data message varies depending on the bus data width.
Therefore, the width of the Data FIFO corresponds to the message width
in the case of the minimum bus data width.

For example, the width of the RDATA FIFO is 279 bits, which consists of
256 bits for the minimum bus data width, 10 bits for RID, 2 bits for
RRESP, 1 bit for RLAST, and additional sdlen 2 bits to identify message
width.

In aspect of WDATA FIFO, the width is 290bit. It contains 256 bits for
the minimum bus data widths, 32bits for the minimum strb data widths,
and additional sdlen 2bits to identify message width.

If the data received from the remote die has sdlen of 0(256bit data),
the message will be stored in a single entry of the DATA FIFO. If the
data received from the remote die has sdlen of 1(512bit data), the
message will be stored across two entries of the Data FIFO. Similarly,
if the data received from the remote die has sdlen of 2(1024bit), the
message will be stored across four entries of the Data FIFO.

In addition, the depth of the Data FIFO is not 44. The depth has been
determined under the assumption that the current bus data width is 512
bits. When the bus data width is 512 bits, a W message occupies 15
granules. Since the decoder in RX_CORE can decode 12 granules per cycle,
the maximum W message can reach the FIFO once every 1.25 cycles (15G ÷
12G/cycle = 1.25 cycles). Furthermore, as mentioned above, when the bus
data width is 512 bits, each message is stored across two FIFO entries.
Therefore, if the maximum turnaround time (TAT) to be covered is 50 ns
(50 cycles), the depth can be set to 80 (50 / 1.25 x 2 = 80).
Regarding the margin, Data FIFO's depth is set to 88.

FIFOs are allocated for each RP, and the depth of the FIFOs for each RP
is configurable.

## 3.5. Data width converter

<a id="figure-12"></a>
![Figure 12. AXI4MUX_3X1_TOP](./media/image12.png)

*Figure 12. AXI4MUX_3X1_TOP*

According to the AoU specification, even if the data width differs
between chips, they must be able to transmit AXI transfers to each
other. Because the remote die may issue read or write transactions with
data widths of 256, 512, or 1024bits, the local die is responsible for
converting the data to align with its own bus data width. The response
must then be reformatted to match the original request size before being
returned.
Within AOU_CORE_TOP, the AOU_AXI4MUX_3X1_TOP performs this function.
[Figure 12](#figure-12) shows how the structure of the Bypass, AXI Downsizer, and AXI
Upsizer varies depending on the AXI data width of the local die.
The Write Data message field does not contain a WLAST signal, so the
WLAST_GEN module generates the WLAST signal by aligning the phases of
the WriteReq and Write Data messages. The DLEN field of the Write Data
message determines which of the three paths the data is routed through,
while the ARSIZE field of the Read Request message determines the
routing path for read transactions.
Finally, the Read Data and Write Response messages are reformatted
according to the selected path to match the original request before
being delivered to the remote die through the TX CORE.

## 3.6. AXI Transaction Splitter

In the AoU specification, the AXI LEN field is fixed at 8 bits, allowing
the remote die to issue burst transactions up to the maximum supported
by an 8-bit AXI LEN. However, because the local die's bus may not
support the full 8-bit burst length, inbound AXI transactions must be
split into bursts that the local bus can handle and then reassembled to
match the original request.
Even if the burst length increases as a result of data-width conversion,
the AXI transactions are always split to ensure they do not exceed the
maximum burst length supported by the local bus.
This maximum burst length can be configured in the
AOU_SPLIT_TR.MAX_AxBURSTLEN SFR.
AXI Transaction Splitter exists for each RP, and the maximum burst
length can be configured differently for each RP.

## 3.7. Write Early Response Controller

The AOU_EARLY_BRESP_CTRL_AWCACHE module is connected to the AXI slave
interface and can issue an write early response once both a write
request and its corresponding last write data have been received. This
feature can be enabled or disabled through an
WRITE_EARLY_RESPONSE.EARLY_BRESP_EN SFR, and the setting can be changed
only after pending write transactions have completed.
You can check for the presence of pending write transactions by
accessing the WRITE_EARLY_RESPONSE.WRITE_RESP_DONE SFR.
Currently, an early response occurs only when the AWCACHE[0]
Bufferable bit is set to 1. Even if Bufferable and Non-Bufferable
transactions with the same ID are mixed, the early response is still
issued while maintaining the ID ordering rule.
When the actual B response for a transaction that has already received
an early response arrives, it is consumed.
If an error is detected in the actual B response of a transaction that
has received an early response, an interrupt is generated, and the BID
and error type (BRESP) of the failing transaction are recorded in the
WRITE_EARLY_RESPONSE.WRITE_RESP_ID_INFO and
WRITE_EARLY_RESPONSE.WRITE_RESP_TYPE_INFO SFRs, respectively.
When the interrupt is detected, after reading the Error Info SFR, you
must write 1 to the WRITE_EARLY_RESPONSE.WRITE_RESP_ERR SFR to clear the
interrupt.

Write early response controller exists for each RP, and it can be
configured differently for each RP through SFR to turn it on or off.

## 3.8. AXI Aggregator

AXI aggregator combines narrow read & write data and send it to BUS. AXI
aggregator is added to improve BUS efficiency. This functionality may
modify AXI Len & Size.
For example, for the read aggregator, an incoming AR with size 256-bit
and burst length 16 is converted to size 1024-bit and burst length 4,
then issued on the AXI master interface (AR). When R data returns to the
aggregator, it is split to restore the original format.
For the write aggregator, an incoming AW with size 256-bit and burst
length 16 is converted to size 1024-bit and burst length 4 and sent on
the AXI master interface (AW/W). The aggregator then forwards the
received B response.
This operation can be controlled via SFR setting.

AXI aggregator exists for each RP, and it can be configured differently
for each RP through SFR to turn it on or off.

## 3.9. Credit Controller

<a id="figure-13"></a>
![Figure 13. Block Diagram of AOU_CRD_CTRL](./media/image13.png)

*Figure 13. Block Diagram of AOU_CRD_CTRL*

[Figure 13](#figure-13) shows the simplified block diagram of AOU_CRD_CTRL. The Credit
Controller manages both the credits granted to the remote die and the
credits received from the remote die. It considers the credit consumed
when the TX CORE packs an AXI message into the ring buffer, and
considers the credit returned when an AXI message is popped from the RX
CORE FIFO. The credit controller always grants the maximum credits
available and uses only one of the two methods - either the Misc Credit
Grant messages or the Message Credit field - to grant credits.**

Rx Credit**

The local die is responsible for tracking the credits advertised to the
remote die and issuing new credits once they are returned. Rx Credit
accounts for both advertised and returned credits and is managed by the
AOU_RX_CRD_CTRL module inside AOU_CRD_CTRL.

More specifically, Rx Credit refers to the credit provided by the local
die to the remote die. The remote die uses this credit to transmit
messages, which are then received and unpacked by the local Rx Core.
Because the processing and unpacking occur within the Rx Core, this
credit is defined as Rx Credit. The maximum available Rx Credit is
determined by the depth of the Rx FIFO.

To ensure that no data is lost under flow control, credits shall not be
granted when sufficient buffer space is unavailable. Therefore, the
amount of credit advertised shall be determined conservatively by
considering the worst-case condition. Here, the worst case is defined as
the condition in which the smallest amount of credit can be advertised.
Consequently, the maximum available is specified as the minimum value
among all possible cases when credits are fully advertised:

```
MAX AVAILABLE CREDIT = min(max advertised credit case1, max advertised credit case2, ..., max advertised credit caseN)
```

Assuming all PROFEXTLEN values are set to 0, the maximum advertised
credit is calculated as follows:
**For WREQ, RREQ, WRESPCRED**, each FIFO entry is considered to be
allocated according to the granule size of each message.

```
RX AW MAX CREDIT = RX AW FIFO DEPTH x WriteReq Granules
RX AR MAX CREDIT = RX AR FIFO DEPTH x ReadReq Granules
RX B  MAX CREDIT = RX B  FIFO DEPTH x WriteResp Granules
```
**In the case of WDATA**, data widths of 256, 512 or 1024 may be
received. Separate FIFOs are provided for data and for strobe, each with
the same FIFO depth. Each FIFO entry is 256 bits wide for DATA and 32
bits wide for STRB, ensuring efficient utilization of the FIFO.
Accordingly, 512-bit width data occupies two entries, while 1024-bit
width data occupies four entries. As illustrated in [Figure 13](#figure-13), for
non-Writefull message types, WDATA is stored in the DATA FIFO and WSTRB
is stored in the STRB FIFO.

<a id="figure-14"></a>
![Figure 14. Example of WDATA and WSTRB FIFO Operation](./media/image14.png)

*Figure 14. Example of WDATA and WSTRB FIFO Operation*

```
Occupying Data entry per message = WDATA Width / DATA FIFO Width
```

<a id="table-1"></a>
| WDATA width | Granule size per message | Occupying Data entry per message | Granules per Data FIFO entry | Granules per Strb FIFO entry | Granules per FIFO entry |
| --- | --- | --- | --- | --- | --- |
| 256b | 8 | 1 | 8 | - | 8 |
| 512b | 15 | 2 | 7.5 | - | 7.5 |
| 1024b | 30 | 4 | 7.5 | - | 7.5 |

*Table 1. WriteData Credit Calculation*

<a id="table-2"></a>
| WDATA width | Granule size per message | Occupying Data entry per message | Granules per Data FIFO entry | Granules per Strb FIFO entry | Granules per FIFO entry |
| --- | --- | --- | --- | --- | --- |
| 256b | 7 | 1 | 7 | - | 7 |
| 512b | 14 | 2 | 7 | - | 7 |
| 1024b | 27 | 4 | 6.75 | - | 6.75 |

*Table 2. WriteDataFull Credit Calculation*

[Table 1](#table-1) and [Table 2](#table-2) illustrates all possible writedata, writedatafull
message types and the credit calculation when messages consist solely of
one type. The minimum advertised credit occurs when only 1024bit
writedatafull messages are received. According the maximum available
credit for WDATA is defined as follows:
```
RX W MAX CREDIT = (RX W FIFO DEPTH / 4) x WriteData Full1024bit Granules
```

**In the case of RDATA,** Receiving RDATA from the remote die implies
that the local die has already issued a ReadReq message. The ARSIZE used
when sending is determined by the AXI_DATA_WD of the local die. For
example, if AXI_DATA_WD is 512, the AR will request RDATA of 512 bits or
less, and the received RDATA will therefore be 512 or 256 bits wide.

<a id="figure-15"></a>
![Figure 15. Example of RDATA FIFO Operation](./media/image15.png)

*Figure 15. Example of RDATA FIFO Operation*

<a id="table-3"></a>
| RDATA Width | Granule size | Occupying entry (RDATA width / FIFO width) | Granules per FIFO entry (Granule size / Occupying entry) |
| --- | --- | --- | --- |
| 256 | 8 | 1 | 8 |
| 512 | 14 | 2 | 7 |
| 1024 | 27 | 4 | 6.75 |

*Table 3. ReadData Credit Calculation*

Similarly, for RDATA, credits must be advertised conservatively by
considering the maximum data width associated with AXI_DATA_WD. As
AXI_DATA_WD increases, the maximum credit that can be advertised
decreases. Therefore, credit shall always be calculated based on
AXI_DATA_WD. For example, if AXI_DATA_WD is 512, the possible RDATA
widths are 256, 512, and credit must be determined under the
conservative assumption that all RDATA widths are 512bits. Likewise, if
AXI_DATA_WD is 1024, the possible RDATA widths are 256, 512, and 1024,
and credits must be determined under the conservative assumption that
all RDATA are 1024bits.

```
RX R MAX CREDIT = {RX R FIFO DEPTH / (AXI_DATA_WD / 256)} x AXI_DATA_WD RDATA Granule Size
```

**Tx Max Credit**

- Tx Credit refers to the credit that the local die receives from the
  remote die. Based on this credit, the Tx Core is permitted to pack
  messages into flits and transmit them. For this reason, the term is
  defined as Tx Credit.

- Tx Credit is managed by the AOU_TX_CRD_CTRL in AOU_CRD_CTRL, which is
  responsible for counting the credits received from the remote die and
  tracking the credits consumed during message packing.

- It is recommended that Tx Max Credit parameter be set to the maximum
  credit value that the remote die is capable of granting.

  - If Tx Max Credit is configured to a value lower than the maximum
    credit issued by the remote die, credit accounting shall be limited
    to the Tx Max Credit value. In this case, flow control operates
    strictly within the range defined by Tx Max Credit, regardless of
    the remote die's capability.

  - If Tx Max Credit is configured to a value greater than or equal to
    the maximum grantable credit of the remote die, the local die can
    fully utilize all credits actually granted by the remote die.

  - This behavior implies that the Tx Max Credit setting is not
    dependent on the remote die's internal configuration. The local die
    shall simply make use of the credits that are actually granted to
    it.

**Credit Advertisement Mechanism**

Upon receipt of an ActivateReq from the remote die, AOU_CORE_TOP
responds with an ActivateAck and, at the same time, advertises credit
through a Misc CreditGrant Message. Only the initial credit
advertisement is performed through this Misc message. Because only a
single Resource Plane is implemented, after the initial advertisement,
subsequent credit advertisements are carried by the Message Credit field
within the protocol header. In multiple-RP configuration, credit
advertisement is likewise delivered exclusively through the Message
Credit field within the protocol header. Credits for multiple RPs are
advertised in a round-robin manner. A grant is issued only when at least
one of the credit fields - wreq, wdata, rreq, rdata, or wresp - contains
a non-zero value to be advertised.

**Definition of Tx Credit Consumption and Rx Credit Advertisement/Return
Timing**

- The Tx Credit is increased immediately upon receipt of a credit
  message from the Rx Core, within the updated value taking effect in
  the following cycle. Credit is decremented when the Tx Core packs a
  message and places it into the ring buffer. The consumption point is
  defined at the time of insertion into the per-RP Tx FIFO.

- The AOU_RX_CRD_CTRL exchanges credit messages (PLP protocol header
  MsgCredit field, dedicated Misc message) with the Tx core through
  valid/ready signaling. Tx core asserts CRDTGRANT_READY when the Tx
  core can pack a Misc Credit Message or asserts MSGCREDIT_CRED_READY
  when a protocol header is required to be transmitted. A credit is
  considered advertised at the point when the credit message handshake
  (valid and ready both asserted) occurs. At that instant, the
  advertised credits are treated as already reserved for the RX FIFO.
  Accordingly, a credit is not considered returned when a message leaves
  the RX Core, but only when data is actually dequeued from the RX FIFO,
  releasing the previously reserved credit.

## 3.10. RP Remapping

The Resource Plane(RP) operates based on the smaller RP count between
the local and remote dies and follows a strict one-to-one mapping. RP
assignments are configured through the **DEST_RP** SFR. The values of
RP3_DEST, RP2_DEST, RP1_DEST, and RP0_DEST must be unique, and for any
RP that is utilized, the configuration on the local and remote dies must
be symmetrical. For AXI messages, the Tx Core encodes the destination
RP, while for credit grants, it encodes its own RP. These rules apply
even when the local and remote dies are configured with different
numbers of RPs. This configuration must remain static and must not be
altered during normal operation.

<a id="figure-16"></a>
![Figure 16. Resource Plane Remapping](./media/image16.png)

*Figure 16. Resource Plane Remapping*

## 3.11. UCIe Flit cancel mechanism

AOU_CORE supports all of UCIe flit cancel mechanisms.

<a id="figure-17"></a>
![Figure 17. UCIe Flit Cancel - Retransmit case](./media/image17.png)

*Figure 17. UCIe Flit Cancel - Retransmit case*

<a id="figure-18"></a>
![Figure 18. UCIe Flit Cancel - Flit Partially Valid case](./media/image18.png)

*Figure 18. UCIe Flit Cancel - Flit Partially Valid case*

<a id="figure-19"></a>
![Figure 19. UCIe Flit Cancel - Full Flit Cancel case](./media/image19.png)

*Figure 19. UCIe Flit Cancel - Full Flit Cancel case*

The RX_FDI_IF submodule within RX_CORE temporarily stores each incoming
chunk and forwards only the valid data that has not been canceled by
flit cancel to RX_CORE.

As a result, RX_CORE performs message decoding exclusively with valid
chunks.

The figure below illustrates an example of how only valid chunk data is
delivered to RX_CORE.

Within the design, pl_data, pl_valid, and pl_flit_cancel are defined as
part of the FDI interface. In contrast, rx_chunk_data and
rx_chunk_data_valid represent the signals responsible for delivering
valid chunks to RX_CORE.

<a id="figure-20"></a>
![Figure 20. Example of selecting valid chunks for RX_CORE](./media/image20.png)

*Figure 20. Example of selecting valid chunks for RX_CORE*

# 4. Interrupt

<a id="table-4"></a>
| Interrupt Name | Access | Description |
|----|----|----|
| INT_ACTIVATE_START | W1C | Asserted when activation of the AoU Protocol layer is required. |
| INT_DEACTIVATE_START | W1C | Asserted when deactivation of the AOU Protocol layer is required. |
| INT_SI0_ID_MISMATCH | W1C | Asserted when AXI slave port received with an AXI ID response that does not match any transaction |
| INT_MI0_ID_MISMATCH | W1C | Asserted when AXI master port received with an AXI ID response that does not match any transaction |
| INT_EARLY_RESP_ERR | W1C | Asserted when B response error occurs on early responsed B response |
| INT_REQ_LINKRESET | W1C | Asserted when AOU_CORE encounters AOU SPEC protocol violation. Request link to go LinkReset. |

*Table 4. Interrupt Sources*

- **INT_ACTIVATE_START**

An interrupt that occurs when activation of the AoU Protocol layer is
required. The interrupt can be cleared by writing '1' to the
AOU_CORE.AOU_INIT.INT_ACTIVATE_START SFR.
For details, please refer to the Interrupt description in Section 7.3
"Activation & Deactivation Flow".

- **INT_DEACTIVATE_START**

An interrupt that occurs when deactivation of the AoU Protocol layer is
required. The interrupt can be cleared by writing '1' to the
AOU_CORE.AOU_INIT.INT_DEACTIVATE_START SFR.
For details, please refer to the Interrupt description in Section 3.10
"Activation & Deactivation Flow".

- **INT_SI0_ID_MISMATCH**

An interrupt that occurs on the AXI Slave Interface when a B or R
channel response is received with an ID that was not previously issued
as a request.

SW can check the mismatched AXI ID by reading
AOU_CORE.AXI_SLV_ID_MISMATCH_ERR SFR. The interrupt can be cleared by
writing '1' to the AOU_CORE.AXI_SLV_ID_MISMATCH_ERR.SLV_B/RRESP_ERR SFR.

- **INT_MI0_ID_MISMATCH**

An interrupt that occurs on the AXI Master Interface when a B or R
channel response is received with an ID that was not previously issued
as a request.
SW can check the mismatched AXI ID by reading AOU_CORE.ERROR_INFO SFR.
The interrupt can be cleared by writing '1' to the
AOU_CORE.ERROR_INFO.SPLIT_B/RID_MISMATCH_ERR SFR.

- **INT_EARLY_RESP_ERR**

An interrupt that occurs when, due to the Write Early Response feature,
a B response has already been sent through the AXI Slave Interface, and
a subsequent actual B response arrives with an error.
SW can check the ID and error type of the transaction in which the error
occured by reading AOU_CORE.WRITE_EARLY_RESPONSE SFR. The interrupt can
be cleared by writing '1' to the
AOU_CORE.WRITE_EARLY_RESPONSE.WRITE_RESP_ERR SFR.

- **INT_REQ_LINKRESET**

An interrupt that occurs when AOU_CORE receive AOU_CORE protocol
violation. Refer 7.2 Debugging features, LinkReset. When AOU_CORE
receives protocol violation. SW needs to do SW reset AOU_CORE and
re-enter activation sequence.

# 5. Error

**TBD**

# 6. Integration guide

The details of integration for AOU_CORE are provided in this section.
Number of AXI channels is configurable. I/O descriptions is for 2 AXI
ports.

## 6.1. I/O descriptions

<a id="table-5"></a>
<table>
<thead>
<tr>
<th colspan="2"><strong>Type</strong></th>
<th><strong>Size</strong></th>
<th><strong>Signal Name</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>Clock, Reset</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_PCLK</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_CLK</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_PRESETN</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_RESETN</td>
</tr>
<tr>
<td>　</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>APB interface</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_AOU_APB_SI0_PSEL</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_AOU_APB_SI0_PENABLE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[31:0]</td>
<td>I_AOU_APB_SI0_PADDR</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_AOU_APB_SI0_PWRITE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[31:0]</td>
<td>I_AOU_APB_SI0_PWDATA</td>
</tr>
<tr>
<td>　</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>　</td>
<td>I_AOU_APB_SI0_PREADY</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[31:0]</td>
<td>I_AOUAPB_SI0_PRDATA</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>　</td>
<td>I_AOU_APB_SI0_PSLVERR</td>
</tr>
<tr>
<td>　</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>AXI slave interface</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][9:0]</td>
<td>I_AOU_TX_AXI_S_ARID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][63:0]</td>
<td>I_AOU_TX_AXI_S_ARADDR</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][7:0]</td>
<td>I_AOU_TX_AXI_S_ARLEN</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][2:0]</td>
<td>I_AOU_TX_AXI_S_ARSIZE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][1:0]</td>
<td>I_AOU_TX_AXI_S_ARBURST</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_ARLOCK</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][3:0]</td>
<td>I_AOU_TX_AXI_S_ARCACHE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][2:0]</td>
<td>I_AOU_TX_AXI_S_ARPROT</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0][3:0]</td>
<td>I_AOU_TX_AXI_S_ARQOS</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_ARVALID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_RREADY</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [9:0]</td>
<td>I_AOU_TX_AXI_S_AWID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [63:0]</td>
<td>I_AOU_TX_AXI_S_AWADDR</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [3:0]</td>
<td>I_AOU_TX_AXI_S_AWLEN</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [2:0]</td>
<td>I_AOU_TX_AXI_S_AWSIZE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [1:0]</td>
<td>I_AOU_TX_AXI_S_AWBURST</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_AWLOCK</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [3:0]</td>
<td>I_AOU_TX_AXI_S_AWCACHE</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [2:0]</td>
<td>I_AOU_TX_AXI_S_AWPROT</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [3:0]</td>
<td>I_AOU_TX_AXI_S_AWQOS</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_AWVALID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [9:0]</td>
<td>I_AOU_TX_AXI_S_WID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [511:0]</td>
<td>I_AOU_TX_AXI_S_WDATA</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [63:0]</td>
<td>I_AOU_TX_AXI_S_WSTRB</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_WLAST</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_WVALID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_S_BREADY</td>
</tr>
<tr>
<td>　</td>
<td>　</td>
<td></td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_ARREADY</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [9:0]</td>
<td>O_AOU_RX_AXI_S_RID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [511:0]</td>
<td>O_AOU_RX_AXI_S_RDATA</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [1:0]</td>
<td>O_AOU_RX_AXI_S_RRESP</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_RLAST</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_RVALID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_AWREADY</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_WREADY</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [9:0]</td>
<td>O_AOU_RX_AXI_S_BID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [1:0]</td>
<td>O_AOU_RX_AXI_S_BRESP</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_S_BVALID</td>
</tr>
<tr>
<td>　</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>AXI master interface</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_ARREADY</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [11:0]</td>
<td>I_AOU_TX_AXI_M_RID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [511:0]</td>
<td>I_AOU_TX_AXI_M_RDATA</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [1:0]</td>
<td>I_AOU_TX_AXI_M_RRESP</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_RLAST</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_RVALID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_AWREADY</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_WREADY</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [11:0]</td>
<td>I_AOU_TX_AXI_M_BID</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0] [1:0]</td>
<td>I_AOU_TX_AXI_M_BRESP</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>[1:0]</td>
<td>I_AOU_TX_AXI_M_BVALID</td>
</tr>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [11:0]</td>
<td>O_AOU_RX_AXI_M_ARID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [63:0]</td>
<td>O_AOU_RX_AXI_M_ARADDR</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_ARLEN</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [2:0]</td>
<td>O_AOU_RX_AXI_M_ARSIZE</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [1:0]</td>
<td>O_AOU_RX_AXI_M_ARBURST</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_ARLOCK</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_ARCACHE</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [2:0]</td>
<td>O_AOU_RX_AXI_M_ARPROT</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_ARQOS</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_ARVALID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_RREADY</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [11:0]</td>
<td>O_AOU_RX_AXI_M_AWID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [63:0]</td>
<td>O_AOU_RX_AXI_M_AWADDR</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_AWLEN</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [2:0]</td>
<td>O_AOU_RX_AXI_M_AWSIZE</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [1:0]</td>
<td>O_AOU_RX_AXI_M_AWBURST</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_AWLOCK</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_AWCACHE</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [2:0]</td>
<td>O_AOU_RX_AXI_M_AWPROT</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [3:0]</td>
<td>O_AOU_RX_AXI_M_AWQOS</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_AWVALID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [11:0]</td>
<td>O_AOU_RX_AXI_M_WID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [511:0]</td>
<td>O_AOU_RX_AXI_M_WDATA</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0] [63:0]</td>
<td>O_AOU_RX_AXI_M_WSTRB</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_WLAST</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_WVALID</td>
</tr>
<tr>
<td>　</td>
<td>output</td>
<td>[1:0]</td>
<td>O_AOU_RX_AXI_M_BREADY</td>
</tr>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>FDI interface (64B)</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 64B VALID</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td>[511:0]</td>
<td>I_FDI PL 64B DATA</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 64B FLIT CANCEL</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 64B TRDY</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 64B STALLREQ</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td>[3:0]</td>
<td>I FDI PL 64B STATE STS　</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td>[511:0]</td>
<td>O FDI LP 64B DATA</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 64B VALID</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 64B IRDY</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 64B STALLACK</td>
</tr>
<tr>
<td>FDI interface (32B)</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 32B VALID</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td>[255:0]</td>
<td>I_FDI PL 32B DATA</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 32B FLIT CANCEL</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 32B TRDY</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I FDI PL 32B STALLREQ</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td>[3:0]</td>
<td>I FDI PL 32B STATE STS　</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td>[255:0]</td>
<td>O FDI LP 32B DATA</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 32B VALID</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 32B IRDY</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O FDI LP 32B STALLACK</td>
</tr>
<tr>
<td>Activation related signal</td>
<td>　</td>
<td>　</td>
<td>　</td>
</tr>
<tr>
<td>　</td>
<td>input</td>
<td>　</td>
<td>I_INT_FSM_IN_ACTIVE</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I MST BUS CLEANY COMPLETE</td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>I SLV BUS CLEANY COMPLETE</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O_AOU_ACTIVATE_ST_DISABLED</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O_AOU_ACTIVATE_ST_ENABLED</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>O_AOU_REQ_LINKRESET</td>
</tr>
<tr>
<td>Interrupt</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_REQ_LINKRESET</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_SI0_ID_MISMATCH</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_MI0_ID_MISMATCH</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_EARLY_RESP_ERR</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_ACTIVATE_START</td>
</tr>
<tr>
<td></td>
<td>output</td>
<td></td>
<td>INT_DEACTIVATE_START</td>
</tr>
<tr>
<td>DFT signal</td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td></td>
<td>input</td>
<td></td>
<td>TIEL_DFT_MODESCAN</td>
</tr>
</tbody>
</table>

*Table 5. AOU_CORE_TOP Interface*

**[Activation related signal]**

- **I_INT_FSM_IN_ACTIVE** is an input signal that indicates that the
  link up is complete. When starting the test, I_INT_FSM_IN_ACTIVE
  should be 0, and when you want to activate AOU_CORE,
  I_INT_FSM_IN_ACTIVE should be 1.
  When testing with IP standalone, you must force I_INT_FSM_IN_ACTIVE.

- **I_MST_BUS_CLEANY_COMPLETE** (signal of AOU_CORE_TOP) is asserted
  when all responses to the remote die's requests have been completed.
  The signal originates from the BUS_CLEANY. If the BUS_CLEANY feature
  is not used, the corresponding port must be tied to 1.

- **I_SLV_BUS_CLEANY_COMPLETE** is asserted when all responses from the
  remote die have been received for the requests sent by the local die.
  The signal originates from the BUS_CLEANY. If the BUS_CLEANY feature
  is not used, the corresponding port must be tied to 1.

- After AOU_CORE deactivation, the activation status transitions to
  DISABLED, allowing the UCIe link to go down. Once deactivation
  completes, the **O_AOU_ACTIVATE_ST_DISABLED** (signal of AOU_CORE_TOP)
  is asserted to notify the UCIE_CORE.

- When the AOU_CORE is in the ENABLED state,
  **O_AOU_ACTIVATE_ST_ENABLED** is asserted to notify the UCIE_CORE.

- **O_AOU_REQ_LINKRESET** is a signal that is asserted together with
  INT_REQ_LINKRESET when the AOU_CORE detects an AoU protocol
  violation.
  O_AOU_REQ_LINKRESET is used to notify the UCIE_CORE.

## 6.2. Clocks

There are 2 clock: I_PCLK and I_CLK.

## 6.3. Resets

There are 2 reset: I_PRESETN and I_RESETN.

## 6.4. Configurable Parameters

<a id="table-6"></a>
<table>
<tbody>
<tr>
<td><strong>Name</strong></td>
<td><strong>Values</strong></td>
<td><strong>Note</strong></td>
</tr>
<tr>
<td>RP_COUNT</td>
<td>2</td>
<td>Equal to the count of RP.</td>
</tr>
<tr>
<td>RP*_AXI_DATA_WD</td>
<td>512</td>
<td>Equal to the bus data width.</td>
</tr>
<tr>
<td>AXI_PEER_DIE_MAX_DATA_WD</td>
<td>1024</td>
<td>Maximum data width sent by the remote
die. Fixed to 1024.</td>
</tr>
<tr>
<td>RP*_RX_AW_FIFO_DEPTH</td>
<td>44</td>
<td rowspan="5">FIFO Depth for storing
messages received from the remote die.
The RX FIFO DEPTH should be determined by considering the
Turn-Around-Time(TAT) between the local die and the remote die, so that
no performance drop occurs due to AoU.<br />
TAT refers to the time in an environment integrated with UCIe, measured
from when the local die sends a message until the credit is received
back from the remote die.</td>
</tr>
<tr>
<td>RP*_RX_AR_FIFO_DEPTH</td>
<td>44</td>
</tr>
<tr>
<td>RP*_RX_W_FIFO_DEPTH</td>
<td>88</td>
</tr>
<tr>
<td>RP*_RX_R_FIFO_DEPTH</td>
<td>88</td>
</tr>
<tr>
<td>RP*_RX_B_FIFO_DEPTH</td>
<td>44</td>
</tr>
<tr>
<td>APB_ADDR_WD</td>
<td>32</td>
<td>APB Address width.</td>
</tr>
<tr>
<td>APB_DATA_WD</td>
<td>32</td>
<td>APB data width.</td>
</tr>
<tr>
<td>S_RD_MO_CNT</td>
<td>32</td>
<td>Slave Read Multiple Outstanding Count.
It refers to the number of table entries used to record information
about requests received from the local die.</td>
</tr>
<tr>
<td>S_WR_MO_CNT</td>
<td>32</td>
<td>Slave Write Multiple Outstanding Count.
It refers to the number of table entries used to record information
about requests received from the local die.</td>
</tr>
<tr>
<td>M_RD_MO_CNT</td>
<td>32</td>
<td>Master Read Multiple Outstanding Count.
It refers to the number of table entries used to record information
about requests received from the remote die.</td>
</tr>
<tr>
<td>M_WR_MO_CNT</td>
<td>32</td>
<td>Master Write Multiple Outstanding Count.
It refers to the number of table entries used to record information
about requests received from the remote die.</td>
</tr>
</tbody>
</table>

*Table 6. AOU_CORE_TOP Configurable Parameters*

# 7. Software operation guide

This section gives information about operation guide for the AOU_CORE.

## 7.1. SFR setting

<a id="table-7"></a>
| **Register** | **Offset** | **Bit field name** | **Bit field** | **Type** | **Reset value** |
|:---|:---|:---|:---|:---|:---|
| IP_VERSION | 0x0000 |  |  |  | 0x00010000 |
|  | 　 | MAJOR_VERSION | [31:16] | RO | 0x0001 |
|  | 　 | MINOR_VERSION | [15:0] | RO | 0x0000 |
| AOU_CON0 | 0x0004 |  |  |  | 0x00000000 |
|  |  | Rsvd | [31:28] | RO | 0x0 |
|  |  | RP3_ERROR_INFO_ACCESS_EN | [27] | RW | 0x0 |
|  |  | RP2_ERROR_INFO_ACCESS_EN | [26] | RW | 0x0 |
|  |  | RP1_ERROR_INFO_ACCESS_EN | [25] | RW | 0x0 |
|  |  | RP0_ERROR_INFO_ACCESS_EN | [24] | RW | 0x0 |
|  |  | RP3_AXI_AGGREGATOR_EN | [23] | RW | 0x0 |
|  |  | RP2_AXI_AGGREGATOR_EN | [22] | RW | 0x0 |
|  |  | RP1_AXI_AGGREGATOR_EN | [21] | RW | 0x0 |
|  |  | RP0_AXI_AGGREGATOR_EN | [20] | RW | 0x0 |
|  |  | TX_LP_MODE_THRESHOLD | [19:12] | RW | 0x4 |
|  |  | TX_LP_MODE | [11] | RW | 0x0 |
|  |  | Rsvd | [10:5] | RO | 0x0 |
|  |  | AOU_SW_RESET | [4] | RW | 0x0 |
|  |  | CREDIT_MANAGE | [3] | RW | 0x0 |
|  |  | AXI_SPLIT_TR_EN | [2] | RW | 0x0 |
|  |  | Rsvd | [1:0] | RO | 0x0 |
| AOU_INIT | 0x0008 |  |  |  | 0x00004608 |
|  |  | Rsvd | [31:11] | RO | 0x0 |
|  |  | MST_TR_COMPLETE | [10] | RO | 0x1 |
|  |  | SLV_TR_COMPLETE | [9] | RO | 0x1 |
|  |  | INT_ACTIVATE_START | [8] | W1C | 0x0 |
|  |  | INT_DEACTIVATE_START | [7] | W1C | 0x0 |
|  |  | DEACTIVATE_TIME_OUT_VALUE | [6:4] | RW | 0x0 |
|  |  | ACTIVATE_STATE_DISABLED | [3] | RO | 0x1 |
|  |  | ACTIVATE_STATE_ENABLED | [2] | RO | 0x0 |
|  |  | DEACTIVATE_START | [1] | RW | 0x0 |
|  |  | ACTIVATE_START | [0] | RW | 0x0 |
| AOU_INTERRUPT_MASK | 0x000C |  |  |  |  |
|  |  | Rsvd | [31:9] | RO | 0x0 |
|  |  | INT_REQ_LINKRESET_ACT_ACK_MASK | [8] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_DEACT_ACK_MASK | [7] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_INVALID_ACTMSG_MASK | [6] | RW | 0x0 |
|  |  | INT_REQ_LINKRESET_MSGCREDIT_TIMEOUT_MASK | [5] | RW | 0x0 |
|  |  | INT_EARLY_RESP_MASK | [4] | RW | 0x0 |
|  |  | INT_MI0_ID_MISMATCH_MASK | [3] | RW | 0x0 |
|  |  | INT_SI0_ID_MISMATCH_MASK | [2] | RW | 0x0 |
|  |  | Rsvd | [1] | RO | 0x0 |
|  |  | Rsvd | [0] | RO | 0x0 |
| LP_LINKRESET | 0x0010 |  |  |  |  |
|  |  | Rsvd | [31:14] | RO | 0x0 |
|  |  | ACK_TIME_OUT_VALUE | [13:11] | RW | 0x4 |
|  |  | MSGCREDIT_TIME_OUT_VALUE | [10:8] | RW | 0x4 |
|  |  | ACT_ACK_ERR | [7] | W1C | 0x0 |
|  |  | DEACT_ACK_ERR | [6] | W1C | 0x0 |
|  |  | INVALID_ACTMSG_INFO | [5:2] | RO | 0x0 |
|  |  | INVALID_ACTMSG_ERR | [1] | W1C | 0x0 |
|  |  | MSGCREDIT_ERR | [0] | W1C | 0x0 |
| DEST_RP | 0x0014 |  |  |  | 0x00000000 |
|  |  | Rsvd | [31:14] | RO | 0x0 |
|  |  | RP3_DEST | [13:12] | RW | 0x3 |
|  |  | Rsvd | [11:10] | RO | 0x0 |
|  |  | RP2_DEST | [9:8] | RW | 0x2 |
|  |  | Rsvd | [7:6] | RO | 0x0 |
|  |  | RP1_DEST | [5:4] | RW | 0x1 |
|  |  | Rsvd | [3:2] | RO | 0x0 |
|  |  | RP0_DEST | [1:0] | RW | 0x0 |
| PRIOR_RP_AXI | 0x0018 |  |  |  |  |
|  |  | Rsvd | [31:28] | RO | 0x0 |
|  |  | AXI_QOS_TO_NP | [27:24] | RW | 0xA |
|  |  | AXI_QOS_TO_HP | [23:20] | RW | 0x5 |
|  |  | Rsvd | [19:18] | RO | 0x0 |
|  |  | RP3_PRIOR | [17:16] | RW | 0x3 |
|  |  | Rsvd | [15:14] | RO | 0x0 |
|  |  | RP2_PRIOR | [13:12] | RW | 0x2 |
|  |  | Rsvd | [11:10] | RO | 0x0 |
|  |  | RP1_PRIOR | [9:8] | RW | 0x1 |
|  |  | Rsvd | [7:6] | RO | 0x0 |
|  |  | RP0_PRIOR | [5:4] | RW | 0x0 |
|  |  | Rsvd | [3:2] | RO | 0x0 |
|  |  | ARB_MODE | [1:0] | RW | 0x0 |
| PRIOR_TIMER | 0x001C |  |  |  | 0x00000000 |
|  |  | TIMER_RESOLUTION | [31:16] | RW | 0x0 |
|  |  | TIMER_THRESHOLD | [15:0] | RW | 0x0 |
| AXI_SPLIT_TR_RP0 | 0x0020 |  |  |  | 0x00000F0F |
|  |  | Rsvd | [31:16] | RO | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8] | RW | 0xF |
|  |  | MAX_ARBURSTLEN | [7:0] | RW | 0xF |
| ERROR_INFO_RP0 | 0x0024 |  |  |  | 0x0 |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP0 | 0x0028 |  |  |  | 0x0 |
|  |  | Rsvd | [31:15] | RO | 0x0 |
|  |  | WRITE_RESP_DONE | [14] | RO | 0x0 |
|  |  | WRITE_RESP_ERR | [13] | W1C | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO | [12:11] | RO | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1] | RO | 0x0 |
|  |  | EARLY_BRESP_EN | [0] | RW | 0x0 |
| AXI_ERROR_INFO0_RP0 | 0x002C |  |  |  | 0x0 |
|  |  | DEBUG_UPPER_ADDR | [31:0] | RW | 0x0 |
| AXI_ERROR_INFO1_RP0 | 0x0030 |  |  |  | 0x0 |
|  |  | DEBUG_LOWER_ADDR | [31:0] | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP0 | 0x0034 |  |  |  |  |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| AXI_SPLIT_TR_RP1 | 0x0038 |  |  |  | 0x00000F0F |
|  |  | Rsvd | [31:16] | RO | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8] | RW | 0xF |
|  |  | MAX_ARBURSTLEN | [7:0] | RW | 0xF |
| ERROR_INFO_RP1 | 0x003C |  |  |  | 0x0 |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP1 | 0x0040 |  |  |  | 0x0 |
|  |  | Rsvd | [31:15] | RO | 0x0 |
|  |  | WRITE_RESP_DONE | [14] | RO | 0x0 |
|  |  | WRITE_RESP_ERR | [13] | W1C | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO | [12:11] | RO | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1] | RO | 0x0 |
|  |  | EARLY_BRESP_EN | [0] | RW | 0x0 |
| AXI_ERROR_INFO0_RP1 | 0x0044 |  |  |  | 0x0 |
|  |  | DEBUG_UPPER_ADDR | [31:0] | RW | 0x0 |
| AXI_ERROR_INFO1_RP1 | 0x0048 |  |  |  | 0x0 |
|  |  | DEBUG_LOWER_ADDR | [31:0] | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP1 | 0x004C |  |  |  |  |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| AXI_SPLIT_TR_RP2 | 0x0050 |  |  |  | 0x00000F0F |
|  |  | Rsvd | [31:16] | RO | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8] | RW | 0xF |
|  |  | MAX_ARBURSTLEN | [7:0] | RW | 0xF |
| ERROR_INFO_RP2 | 0x0054 |  |  |  | 0x0 |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP2 | 0x0058 |  |  |  | 0x0 |
|  |  | Rsvd | [31:15] | RO | 0x0 |
|  |  | WRITE_RESP_DONE | [14] | RO | 0x0 |
|  |  | WRITE_RESP_ERR | [13] | W1C | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO | [12:11] | RO | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1] | RO | 0x0 |
|  |  | EARLY_BRESP_EN | [0] | RW | 0x0 |
| AXI_ERROR_INFO0_RP2 | 0x005C |  |  |  | 0x0 |
|  |  | DEBUG_UPPER_ADDR | [31:0] | RW | 0x0 |
| AXI_ERROR_INFO1_RP2 | 0x0060 |  |  |  | 0x0 |
|  |  | DEBUG_LOWER_ADDR | [31:0] | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP2 | 0x0064 |  |  |  |  |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| AXI_SPLIT_TR_RP3 | 0x0068 |  |  |  | 0x00000F0F |
|  |  | Rsvd | [31:16] | RO | 0x0 |
|  |  | MAX_AWBURSTLEN | [15:8] | RW | 0xF |
|  |  | MAX_ARBURSTLEN | [7:0] | RW | 0xF |
| ERROR_INFO_RP3 | 0x006C |  |  |  | 0x0 |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | SPLIT_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | SPLIT_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | SPLIT_RID_MISMATCH_ERR | [0] | W1C | 0x0 |
| WRITE_EARLY_RESPONSE_RP3 | 0x0070 |  |  |  | 0x0 |
|  |  | Rsvd | [31:15] | RO | 0x0 |
|  |  | WRITE_RESP_DONE | [14] | RO | 0x0 |
|  |  | WRITE_RESP_ERR | [13] | W1C | 0x0 |
|  |  | WRITE_RESP_ERR_TYPE_INFO | [12:11] | RO | 0x0 |
|  |  | WRITE_RESP_ERR_ID_INFO | [10:1] | RO | 0x0 |
|  |  | EARLY_BRESP_EN | [0] | RW | 0x0 |
| AXI_ERROR_INFO0_RP3 | 0x0074 |  |  |  | 0x0 |
|  |  | DEBUG_UPPER_ADDR | [31:0] | RW | 0x0 |
| AXI_ERROR_INFO1_RP3 | 0x0078 |  |  |  | 0x0 |
|  |  | DEBUG_LOWER_ADDR | [31:0] | RW | 0x0 |
| AXI_SLV_ID_MISMATCH_ERR_RP3 | 0x007C |  |  |  |  |
|  |  | Rsvd | [31:22] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_INFO | [21:12] | RO | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_INFO | [11:2] | RO | 0x0 |
|  |  | AXI_SLV_BID_MISMATCH_ERR | [1] | W1C | 0x0 |
|  |  | AXI_SLV_RID_MISMATCH_ERR | [0] | W1C | 0x0 |

*Table 7. Register Map*

**ERR SET is restricted to change the value while the system is
running**

For details on the ACTIVATE and DEACTIVATE SFRs, please refer to Section
3.5: Activation/Deactivation & Flow.

**AOU_INIT.ACTIVATE_START**

- After link-up is completed, AOU_CORE can send or receive an
  ActivateReq message.

<!-- -->

- AoU Activation Request can only be triggered by
  AOU_INIT.ACTIVATE_START, and it is allowed to be set before and after
  the completion of the UCIe Link-up.

**AOU_INIT.DEACTIVATE_START**

- AOU_CORE must exchange both DeactivateReq and DeactivateAck messages
  before the UCIe Core transitions to the Link Down state.

- The DEACTIVATE_START field in AOU_INIT initiates deactivation and
  ensures that a DeactivateReq is issued only after both conditions
  below are satisfied:

  1.  All outstanding responses to remote die requests have been
      completed.

  2.  No additional messages remain to be transmitted within a window
      defined by **TIME_OUT_VALUE.**

- **AOU_INIT.DEACTIVATE_TIME_OUT_VALUE** configures the timeout value
  used for this condition. This field is 3 bits wide and encodes a
  timeout of **2^(DEACTIVATE_TIME_OUT_VALUE + 3)** cycles.

**MAX BURSTLEN**

- The **MAX_AWBURSTLEN** and **MAX_ARBURSTLEN** register fields define
  the maximum burst length that the splitter may issue to the local bus.

- The splitter inside **AOU_CORE** issues AXI transfers with burst
  lengths less than or equal to the configured values
  (**MAX_AWBURSTLEN**, **MAX_ARBURSTLEN**).

- If **AOU_CORE** receives a larger burst length from the remote die,
  the splitter divides it into smaller bursts based on MAX_AxBURSTLEN.

- Since Splitter only supports maximum burst lengths in the form of 2^n,
  the field must be configured with one of the following: 1, 3, 5, 7,
  15, 31, 63, 127 or 255.

**ACTIVATE_STATE_ENABLED/DISABLED**

- This signal indicates the activation status of the
  AOU_ACTIVATION_CTRL.

- The ENABLE signal is asserted to indicate that activation has been
  completed.

The DISABLED signal is asserted to indicate that deactivation has been
completed.

**MST_TR_COMPLETE/SLV_TR_COMPLETE**

- This signal indicates that there are no pending transactions in both
  local die and remote die.

**ACK_TIME_OUT_VALUE/MSG_CREDIT_TIME_OUT_VALUE**

- After sending an AoU Activation/Deactivation Request message, if an
  Ack message is not received within the specified ACK_TIME_OUT_VALUE, a
  LinkReset interrupt is sent to the SW.

- After receiving the Activation Ack message from the remote die, if a
  creditgrant message is not received within the specified
  MSGCREDIT_TIME_OUT_VALUE, a LinkReset interrupt is sent to the SW.

- This fields are 3 bits wide and encodes a timeout of 2
  ^(TIME_OUT_VALUE + 8) cycles.

**WRITE_EARLY_RESPONSE**

- For the EARLY_RESPONSE_EN SFR setting to enable or disable early
  response, there must be no pending write requests.

- EARLY_RESPONSE_EN: If this field is set(1), It performs the early
  response function.

- WRITE_RESP_DONE: It indicates that there are no pending write requests
  and all write responses have been received from the remote die.

- WRITE_RESP_ERR: It indicated that although the early response feature
  was enabled and an early response has already been delivered to the
  local die, an error occurred later in the write response received from
  the remote die. The BRESP value of the error is stored in
  WRITE_RESP_ERR_TYPE_INFO, and the BID of the transaction that caused
  the error is stored in WRITE_RESP_ERR_ID_INFO SFR.
  When an error occurs, an interrupt is generated. Afterward, writing 1
  to the WRITE_RESP_ERR SFR clears ERR_TYPE_INFO, ERR_ID_INFO, and
  RESP_ERR.

**Low Power mode**

- For lowering power, AOU_CORE uses low power mode.
  By setting AOU_CON0.TX_LP_MODE = 1, AOU_CORE only sends payload to FDI
  when there are remaining AXI messages to send. Since AOU_CORE need to
  send Credit when there are no remaining AXI messages, by setting
  AOU_CON0.TX_LP_MODE_THRESHOLD value, SW can configure the message
  transmission frequency.

<a id="figure-21"></a>
![Figure 21. Bubble inserted when Transmitter de-assert LP_VALID](./media/image21.png)

*Figure 21. Bubble inserted when Transmitter de-assert LP_VALID*

- Default value is 0. AOU_CORE always sends messages to FDI for lowering
  latency

## 7.2. Debugging features

AOU_CORE includes several features for debugging. SFR name including
ERROR is related to debugging features.

**1. AXI ID mismatch error**
For AOU_CORE AXI interface, it generates interrupt when receive AXI ID
that was not issued, an interrupt occurs.
If error detected on AXI slave interface, SW can check the AXI ID on
AXI_SLV_ID_MISMATCH_ERR field and clear the interrupt by setting
AXI_SLV_ID_MISMATCH_ERR.AXI_SLV_*ID_MISMATCH_ERR.
If error has detected on AXI master interface, SW can check the AXI ID
on ERROR_INFO field and clear the interrupt by setting
ERROR_INFO.SPLIT_*ID_MISMATCH_ERR.

**2.** **LinkReset**
For Activation/Deactivation error, it drives interrupt by
INT_REQ_LINKRESET and AOU_REQ_LINKRESET to FDI. Protocol layer requests
CPU to Reset the Link. There are several cases for AOU_REQ_LINKRESET
goes high.

- **Request to Acknowledge message timeout error**
  If the remote die does not return an Acknowledge within the configured
  timeout, the local die may report a Request to Acknowledge timeout.
  Per the AOU_SPEC, when the local die issues an Activation or
  Deactivation request, the remote die may respond with an Acknowledge
  indicating successful receipt of the request. If no Acknowledge is
  received before the timeout value, the AOU_CORE assert
  INT_AOU_REQ_LINKRESET to SW and SW should do LinkReset sequence. SW
  can configure timeout value by setting
  LP_LINKRESET.ACK_TIME_OUT_VALUE.

- **Invalid ACTMSG**
  If an ACTMSG that is not permitted in the current Activation state is
  received, AOU_CORE may treat it as a protocol violation and assert
  INT_AOU_REQ_LINKRESET. In AOU specification, each activation state
  defines the allowable ACTMSG opcode. Any ACTMSG outside this may
  trigger INT_AOU_REQ_LINKRESET in next cycle. SW can debug Invalid
  OPCODE of ACTMSG and should do LinkReset sequence.

- **ActivateAck to MSGCREDIT timout error**
  MSGCREDIT should send to remote die indicating how many resource plane
  does local die have. If local die does not receive MSGCREDIT within
  the configured timeout, local die may reports msgcredit error. SW can
  configure timeout value by setting
  LP_LINKRESET.MSGCREDIT_TIME_OUT_VALUE and should do LinkReset
  sequence.

**3. R/B response error debug feature**
When AOU_CORE receive AXI R/B response error from master interface, It
internally store the AXI ID, Address, Resp in dedicated FIFO. After
Remote die receive AXI response error, it can access this error
information by AXI read. Error information is stored up to 4.

<a id="figure-22"></a>
![Figure 22. Error Information Access Flow](./media/image22.png)

*Figure 22. Error Information Access Flow*

> Unlike normal AXI transactions, accessing the error information
> requires an explicit enable and a dedicated address. First, set
> DEBUG_UPPER_ADDR and DEBUG_LOWER_ADDR to define the target address and
> set ERROR_INFO_ACCESS_EN to 1 to enable access. When an AXI read is
> issued to the address, the remote die can read out the corresponding
> error information. Remote die can write 1 to the dedicated address to
> pop the debug information.

**5. WRITE_EARLY_RESPONSE**
The error is generated when Write Early Response is enabled and a BRESP
error arrives for a previously sent early response. When a BRESP error
occurs, an interrupt is issued and SW can check the BRESP AXI ID and
error type by reading SFR and clear the error.****

## 7.3. Activation & Deactivation Flow

The Activation of AOU_CORE begins after the UCIe Link-up process has
been successfully completed. The completion of UCIe link-up is indicated
by the **I_INT_FSM_IN_ACTIVE** signal of the **AOU_CORE_TOP**.

There is no dependency between the activation of the local die and the
remote die. Each die may initiate the activation sequence independently,
which means the timing of sending **ActivateReq** can differ. Both dies
must exchange **ActivateReq** and **ActivateAck** messages to transition
to the **ENABLED** state, at which point credited messages can be
transmitted.
<a id="figure-23"></a>
![Figure 23. Independent Activation Flow](./media/image23.png)

*Figure 23. Independent Activation Flow*

Regardless of its own activation state, a die must send an ActivateAck
in response to an ActivateReq from the other die, to acknowledge receipt
of the request.

### 7.3.1. Credit Management Type

There are two types of Credit Management Type. Since current AOU_SPEC
cannot resolve pending AXI response without Activate again. When Credit
Management type is set to 1, During Deactivate state, AOU_CORE can
resolve pending AXI response itself.
It can be configured through AOU_CON0.CREDIT_MANAGE, and the default
value is 0.

- 0 (default) Based on AoU v0.5
  - After deactivation, if a new request is received from the remote die, no response message can be sent.
  - To deliver the corresponding response, the system must go through activation again after deactivation.
  - Credit management and transmission availability for both Request-related messages and Response-related message are controlled together.
  - Credited messages must not be sent, after the DeactivateReq message is sent.
  - Credits must not be sent after the DeactivateAck message is sent.
  - The Activate Interrupt and Deactivate Interrupt that occur in the process of resuming the exchange of response messages impose mandatory requirement to set Activate and Deactivate SFR.

- 1 Proposal by BOS.
  - When the AoU Activity state is DEACTIVATE, manage Request-related messages(WERQ, RREQ, WDATA) and Response-related messages(RDATA, WRESP) separately.
  - RDATA, WRESP Credited messages can be sent, after the DeactivateReq message is sent.
  - Credits for RDATA, WRESP messages must be sent after the DeactivateAck message is sent.
  - The Deactivate interrupt only provides a hint indicating that the remote die has started activate/deactivate.


### 7.3.2. Activation start

Activation can be initiated by setting ACTIVATE_START SFR:
In the current implementation, credits are granted based on the depth of
the RX FIFO, so it is required to ensure that all messages in the RX
FIFO have been popped before sending the ActivateReq message.

Activation START(via SFR AOU_INIT.ACTIVATE_START SFR)

- Activation can be triggered by setting ACTIVATE_START.

- Activation does not proceed until I_INT_FSM_IN_ACTIVE is asserted,
  since no flits can be transmitted beforehand.
  Therefore, it is allowed to set the ACTIVATE_START SFR before
  I_INT_FSM_IN_ACTIVE is asserted. If it is set before the assertion,
  the activation process will automatically proceed after
  I_INT_FSM_IN_ACTIVE becomes asserted.

- AOU_INIT.ACTIVATE_START SFR is automatically cleared to 0 once the
  activation is completed and AOU_ACTIVATE_STATE transitions to ENABLED.

### 7.3.3. Deactivation start

Deactivation is initiated by setting the AOU_INIT.DEACTIVATE_START
register. Setting this register does not immediately trigger sending a
DeactivateReq message. The detailed conditions and sequence for
deactivation can be found in the **Deactivation Sequence Flow** section.
This section will only describe AOU_INIT.DEACTIVATE_TIME_OUT_VALUE SFR.

- When software initiates a DeactivateReq by setting the SFR, there may
  still be outstanding requests that have not yet reached out AOU_CORE.

- To handle this safely, a timeout mechanism is implemented to ensure
  that no valid packets remain in the AOU_TX_CORE.

- If software guarantees that all responses to its issued requests have
  been received before setting the deactivation start SFR, the
  deactivate TIME_OUT_VALUE(AOU_INIT.DEACTIVATE_TIME_OUT_VALUE SFR) can
  be safely configured to a shorter duration.

The ACTIVATION_OP field encodes deactivation messages as follows:

- 2 = DeactivateReq

- 3= DeactivateAck

<a id="figure-24"></a>
![Figure 24. Deactivation sequence with DEACTIVATE_START](./media/image24.png)

*Figure 24. Deactivation sequence with DEACTIVATE_START*

### 7.3.4. Deactivation Sequence Flow

Once the local die issues a DeactivateReq, it can no longer provide
responses to transactions initiated by the remote die. If the remote die
continues to send requests or waits for responses without being
notified, it may enter a hang state.
To manage this safely, the remote die must take explicit action upon
receiving a DeactivateReq:
1. Immediately generate an interrupt to the CPU to inform the system
software that a DeactivateReq has been received and that it must set the
DEACTIVATE_START SFR.

Although deactivation of the local die and the remote die operate
independently, it is essential at the system level to communicate the
deactivation & activation state through interrupts. This ensures that
system software is explicitly informed of deactivation events and
prevents the remote die from continuing to expect response that will
never arrive, thereby avoiding hang conditions.
This approach guarantees that once deactivation is initiated, both dies
can coordinate the transition into safe and consistent DISABLED state.

If the software on both dies can explicitly coordinate to guarantee that
all outstanding transactions have been completed and that no new
transactions will be issued, then such an complicated implementation
would not be necessary.

[Figure 24](#figure-24) illustrates the current activate/deactivate implementation of
AOU_CORE.

<a id="figure-25"></a>
![Figure 25. CREDIT_MANAGE 1 Deactivate sequence flow](./media/image25.png)

*Figure 25. CREDIT_MANAGE 1 Deactivate sequence flow*

<a id="figure-26"></a>
![Figure 26. CREDIT_MANAGE 0 Deactivate sequence flow](./media/image26.png)

*Figure 26. CREDIT_MANAGE 0 Deactivate sequence flow*

This system provides a bus cleany mechanism:

- Slave bus cleanly indicates whether the local die has received all
  responses to the requests it sent to the remote die.

- Master bus cleanly indicates whether the remote die has received all
  responses to the requests it sent to the local die.

After the local die sends a DeactivateReq, if the remote die issues a
new request and expects a response, the system must re-enter the
activation sequence before any response can be provided.

Before sending a new ActivateReq, the Rx FIFO must be completely emptied
- that is, all messages must be popped.
After deactivation, the credit count is reset, and during the subsequent
activation process, credits are advertised based on the RX FIFO depth.
Therefore, before sending an ActivateReq, the local die must confirm, as
described in the local die's sequence 10.1, that all messages in the RX
FIFO have been popped.

To meet satisfy the condition in the local die's sequence 10.1, no
backpressure must occur on the local die's MI AW/AR/W channels.

### 7.3.5. Activation/Deactivation Interrupt

**INT_ACTIVATE_START**

- When this interrupt is detected, AOU_INIT.ACTIVATE_START SFR must be set to 1.
- When AOU_INIT.ACTIVATE_STATE_ENABLED becomes 1, write 1 to clear the AOU_INIT.INT_ACTIVATE_START W1C SFR.
- An interrupt occurs when AOU_INIT.ACTIVATE_START SFR is not set and any of the following conditions are met:
  1. There is a message to send
     - When AOU_CON0.CREDIT_MANAGE = 0, if a new request arrives from the remote die after the local die has sent a DeactivateReq, this interrupt is asserted because the local die must return a response.
     - When AOU_CON0.CREDIT_MANAGE = 1, this interrupt can also be asserted if a new request arrives after the remote die has sent a DeactivateReq.
  2. There is a response to be received (I_SLV_BUS_CLEANY_COMPLETE == 0)
     - When AOU_CON0.CREDIT_MANAGE = 0, this interrupt can be asserted if the local die issues new AXI requests after the remote die has sent a DeactivateReq.
  3. An ActivateReq message is received from the remote die.

**INT_DEACTIVATE_START**

- When AOU_CON0.CREDIT_MANAGE = 0: if the interrupt is detected, the master IP must stop sending new request messages and AOU_INIT.DEACTIVATE_START SFR must be set to 1.
- When AOU_CON0.CREDIT_MANAGE = 1: if the interrupt is detected, this serves only as a hint that the remote die intends to deactivate. The local die can continue sending request messages. Once all messages have been sent, AOU_INIT.DEACTIVATE_START SFR must be set. Otherwise, the remote die may end up in a state where it can never send requests again.
- When AOU_INIT.ACTIVATE_STATE_DISABLED becomes 1, write 1 to clear the AOU_INIT.INT_DEACTIVATE_START W1C SFR.
- An interrupt is asserted when AOU_INIT.DEACTIVATE_START SFR is not set and the local die receives a DeactivateReq message from the remote die.

### 7.3.6. PM entry / LinkReset / LinkDisabled sequence

For PM entry / LinkReset / LinkDisable entry sequence, UCIE_CORE check
AOU_CORE state and try to change state. For this sequence, resolving
pending AXI transactions is necessary.

Since current AOU SPEC has no way to send AXI response after sending
DeactiveReq. CREDIT_MANAGE = 0 (Type 0) is matched with current
AOU_SPEC. For this case, SW need to check whether there is pending AXI
transaction.

- **PM entry SW sequence**

1.  Write AOU_INIT.DEACTIVATE_START to 1.

2.  Polling AOU_INIT.ACTIVATE_STATE_DISABLED and
    AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

    1.  Although AOU_CORE state becomes DISABLED, there may have pending
        AXI transaction.

    2.  AOU_CORE issue Interrupt for resolving pending AXI transactions.

    3.  Activate AOU_CORE and resolve pending AXI transactions.

    4.  Deactivate AOU_CORE

3.  Polling AOU_INIT.ACTIVATE_STATE_DISABLED and
    AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

4.  Do PM Entry Sequence on UCIE_CORE.

<a id="figure-27"></a>
![Figure 27. PM Entry Sequence](./media/image27.png)

*Figure 27. PM Entry Sequence*

- **LinkDisable SW sequence**

Same as PM entry, before doing UCIE state transition, AOU_CORE need to
Disabled properly.

1.  Write AOU_INIT.DEACTIVATE_START to 1.

2.  Polling AOU_INIT.ACTIVATE_STATE_DISABLED and
    AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

    1.  Although AOU_CORE state becomes DISABLED, there may have pending
        AXI transaction.

    2.  AOU_CORE issue Interrupt for resolving pending AXI transactions.

    3.  Activate AOU_CORE and resolve pending AXI transactions.

    4.  Deactivate AOU_CORE

3.  Polling AOU_INIT.ACTIVATE_STATE_DISABLED and
    AOU_INIT.SLV_TR_COMPLETE & AOU_INIT.MST_TR_COMPLETE.

4.  Do LinkReset/LinkDisabled Sequence on UCIE_CORE.

- **LinkReset sequence**

If AOU_CORE faces uncorrectable error (ex. AOU SPEC violation), AOU_CORE
sends LinkReset to CPU and D2D adapter. LinkReset indicates that an
error has occurred which requires the Link to go down.

While handling LinkReset, SW needs to do AOU_CORE SW reset by setting
AOU_CON0.AOU_SW_RESET.

# 8. PPA

## 8.1. Performance

Performance evaluation is conducted in both 512-bit local die and
512-bit remote die environments. The initial latency is measured from
the AXI input of the local AOU_CORE to the AXI output of the remote
AOU_CORE.

<a id="table-8"></a>
| AXI Channel | AoU Latency on B2B connection |
| --- | --- |
| Read Request (AR) | 9 |
| Read Data (R) | 11 |
| Write Request (AW) | 12 |
| Write Data (W) | 12 |
| Write Response (B) | 10 |
| Misc | 9 |

*Table 8. AOU_CORE Initial Latency (Cycles)*

The reason of two additional latency for AW and W CH is from WLAST
signal generator, and data width converter.

<a id="figure-28"></a>
![Figure 28. Initial Latency of AOU_CORE with UCIe (Cycle)](./media/image28.png)

*Figure 28. Initial Latency of AOU_CORE with UCIe (Cycle)*

<a id="figure-29"></a>
![Figure 29. AoU Bandwidth Efficiency with Respect to UCIe FDI Latency](./media/image29.png)

*Figure 29. AoU Bandwidth Efficiency with Respect to UCIe FDI Latency*

The results of efficiency measurements for read and write operations
with varying burst lengths are presented. For write operations, two
cases were evaluated. Normal Write and Write Full, where no write strobe
bits are transmitted. The measured values and the corresponding expected
values are as follows.

<a id="table-9"></a>
<table>
<thead>
<tr>
<th colspan="2">Data transfer
efficiency</th>
<th colspan="2">Uni-direction transfer</th>
<th colspan="2">Bi-direction transfer</th>
</tr>
</thead>
<tbody>
<tr>
<td>AXI burst length</td>
<td>Data type</td>
<td>Measured</td>
<td>AoU limit by spec</td>
<td>Measured</td>
<td>AoU limit by spec</td>
</tr>
<tr>
<td rowspan="3">16 burst</td>
<td>Read data</td>
<td>85.3%*</td>
<td>85.7%</td>
<td>85.3%</td>
<td>84.6%</td>
</tr>
<tr>
<td>Write data</td>
<td>79.0%</td>
<td>79.0%</td>
<td>78.5%</td>
<td>78.7%</td>
</tr>
<tr>
<td>WriteFull data**</td>
<td>84.2%</td>
<td>84.6%</td>
<td>84.2%</td>
<td>84.2%</td>
</tr>
<tr>
<td rowspan="3">1 Burst</td>
<td>Read data</td>
<td>85.3%</td>
<td>85.7%</td>
<td>71.9%</td>
<td>70.6%</td>
</tr>
<tr>
<td>Write data</td>
<td>66.7%</td>
<td>66.7%</td>
<td>63.3%</td>
<td>63.1%</td>
</tr>
<tr>
<td>WriteFull data</td>
<td>70.3%</td>
<td>70.6%</td>
<td>67.0%</td>
<td>66.7%</td>
</tr>
</tbody>
</table>

*Table 9. AOU_CORE Data Transfer Efficiency*

* 0.4% performance drop is not from IP, but just from transfer data
size. If the transfer data size is the multiples of 6 burst such 132
beats, it shows the same performance number with the limit in AoU spec.
Everything is the same case. Note that the efficiency is measured with
128/(cycle_from_1st_valid_to_last_valid + 1), where 1 is the hidden
bubble right before the first valid. It is indispensable since AoU data
message size can not covered in a single 64B chunk, unlike local AXI
bus.

## 8.2. Power

TBD

## 8.3. Area

<a id="figure-30"></a>
![Figure 30. Area of 1 RP AOU](./media/image30.png)

*Figure 30. Area of 1 RP AOU*

The area for each 1 RP AOU submodule is shown in the figure above.

Among them, the RX_W_FIFO and RX_R_FIFO, which store write data and read
data respectively, occupy the largest portion of the AOU area. These
FIFOs are currently implemented as register-based FIFOs.

FIFO Depths : TX = 2 entries / RX = 88 entries for R/W data, and 44
entries for AW/AR/B.
The Expected R/W data for 128GBs/s is 176 entries.

**v0.4 AOU_CORE**

With 2 RP, each AXI bandwidth is 512 bit and 256 bit, AOU_CORE area was
197k um^2.

The FIFO depth of the two RPs are identical.

<a id="table-10"></a>
| AoU Area (um^2) | 64GB/s |
| --- | --- |
| 1RP<br />
(AXI : 512bit) | <strong>97K</strong> |
| 2RP<br />
(AXI : 256bit &amp; 512bit) | 197K |

*Table 10. AOU_CORE Area*

# Appendix A. Records of Changes

<a id="table-11"></a>
| Version | Date | Author | Reviewer | Description of Change |
| --- | --- | --- | --- | --- |
| v0.1 | 2025/08/20 | Soyoung Min, Jaeyun Lee, Hojun Lee | Kwanho Kim | Initial version. |
| v0.2 | 2025/09/19 | Soyoung Min, Jaeyun Lee, Hojun Lee | Kwanho Kim | 256, 512, 1024 datawidth verification finished. Early response feature added. |

*Table 11. Record of Changes*

# Appendix B. Referenced Documents

<a id="table-12"></a>
| Document Name     | Document Location and/or URL      | Issuance Date  |
|-------------------|-----------------------------------|----------------|
| <Document Name> | < Document Location and/or URL> | <MM/DD/YYYY> |

*Table 12. Referenced Documents*
