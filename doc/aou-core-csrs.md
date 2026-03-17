<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: aou_core
  - csr/aou-core.rdl
-->

## aou_core address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x80

<p>Register map for AOU_CORE_SFR (APB slave). Addresses match RTL localparams. Fields with sw=r and no reset are driven by module inputs (I_*), connected in AOU_CORE.sv; stored fields (flops) have the stated reset.</p>

|Offset|         Identifier        |              Name             |
|------|---------------------------|-------------------------------|
| 0x00 |         ip_version        |           IP Version          |
| 0x04 |          aou_con0         |         AOU Control 0         |
| 0x08 |          aou_init         |            AOU Init           |
| 0x0C |     aou_interrupt_mask    |       AOU Interrupt Mask      |
| 0x10 |        lp_linkreset       |          LP Linkreset         |
| 0x14 |          dest_rp          |         Destination RP        |
| 0x18 |        prior_rp_axi       |        Priority RP AXI        |
| 0x1C |        prior_timer        |         Priority Timer        |
| 0x20 |      axi_split_tr_rp0     |   AXI Split Transaction RP0   |
| 0x24 |       error_info_rp0      |         Error Info RP0        |
| 0x28 |  write_early_response_rp0 |    Write Early Response RP0   |
| 0x2C |    axi_error_info0_rp0    |      AXI Error Info0 RP0      |
| 0x30 |    axi_error_info1_rp0    |      AXI Error Info1 RP0      |
| 0x34 |axi_slv_id_mismatch_err_rp0|AXI Slave ID Mismatch Error RP0|
| 0x38 |      axi_split_tr_rp1     |   AXI Split Transaction RP1   |
| 0x3C |       error_info_rp1      |         Error Info RP1        |
| 0x40 |  write_early_response_rp1 |    Write Early Response RP1   |
| 0x44 |    axi_error_info0_rp1    |      AXI Error Info0 RP1      |
| 0x48 |    axi_error_info1_rp1    |      AXI Error Info1 RP1      |
| 0x4C |axi_slv_id_mismatch_err_rp1|AXI Slave ID Mismatch Error RP1|
| 0x50 |      axi_split_tr_rp2     |   AXI Split Transaction RP2   |
| 0x54 |       error_info_rp2      |         Error Info RP2        |
| 0x58 |  write_early_response_rp2 |    Write Early Response RP2   |
| 0x5C |    axi_error_info0_rp2    |      AXI Error Info0 RP2      |
| 0x60 |    axi_error_info1_rp2    |      AXI Error Info1 RP2      |
| 0x64 |axi_slv_id_mismatch_err_rp2|AXI Slave ID Mismatch Error RP2|
| 0x68 |      axi_split_tr_rp3     |   AXI Split Transaction RP3   |
| 0x6C |       error_info_rp3      |         Error Info RP3        |
| 0x70 |  write_early_response_rp3 |    Write Early Response RP3   |
| 0x74 |    axi_error_info0_rp3    |      AXI Error Info0 RP3      |
| 0x78 |    axi_error_info1_rp3    |      AXI Error Info1 RP3      |
| 0x7C |axi_slv_id_mismatch_err_rp3|AXI Slave ID Mismatch Error RP3|

### ip_version register

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x4

<p>IP version; read-only. Tied off in AOU_CORE.sv (u_aou_core_sfr): I_IP_VERSION_MAJOR_VERSION=16'd1, I_IP_VERSION_MINOR_VERSION=16'b0.</p>

| Bits|  Identifier |Access|Reset|Name|
|-----|-------------|------|-----|----|
| 15:0|minor_version|   r  | 0x0 |  — |
|31:16|major_version|   r  | 0x1 |  — |

### aou_con0 register

- Absolute Address: 0x4
- Base Offset: 0x4
- Size: 0x4

<p>Core control: error access, AXI aggregator, LP mode, reset, credit, split. Note: bits [1:0] read as 0 in RTL (deactivate_force is not read back).</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |    deactivate_force    |  rw  | 0x0 |  — |
|  1  |       reserved_1       |  rw  | 0x0 |  — |
|  2  |     axi_split_tr_en    |  rw  | 0x0 |  — |
|  3  |      credit_manage     |  rw  | 0x0 |  — |
|  4  |      aou_sw_reset      |  rw  | 0x0 |  — |
| 10:5|      reserved_10_5     |  rw  | 0x0 |  — |
|  11 |       tx_lp_mode       |  rw  | 0x0 |  — |
|19:12|  tx_lp_mode_threshold  |  rw  | 0x4 |  — |
|  20 |  rp0_axi_aggregator_en |  rw  | 0x0 |  — |
|  21 |  rp1_axi_aggregator_en |  rw  | 0x0 |  — |
|  22 |  rp2_axi_aggregator_en |  rw  | 0x0 |  — |
|  23 |  rp3_axi_aggregator_en |  rw  | 0x0 |  — |
|  24 |rp0_error_info_access_en|  rw  | 0x0 |  — |
|  25 |rp1_error_info_access_en|  rw  | 0x0 |  — |
|  26 |rp2_error_info_access_en|  rw  | 0x0 |  — |
|  27 |rp3_error_info_access_en|  rw  | 0x0 |  — |
|31:28|     reserved_31_28     |  rw  | 0x0 |  — |

### aou_init register

- Absolute Address: 0x8
- Base Offset: 0x8
- Size: 0x4

<p>Activate/deactivate control; status from HW. int_deactivate_property, mst_tr_complete, slv_tr_complete, activate_state_disabled, activate_state_enabled are read-only inputs (I_*), driven in AOU_CORE.sv from internal/output signals. Write 1 to clear int_activate_start/int_deactivate_start.</p>

| Bits|        Identifier       |Access|Reset|Name|
|-----|-------------------------|------|-----|----|
|  0  |      activate_start     |  rw  | 0x0 |  — |
|  1  |     deactivate_start    |  rw  | 0x0 |  — |
|  2  |  activate_state_enabled |   r  |  —  |  — |
|  3  | activate_state_disabled |   r  |  —  |  — |
| 6:4 |deactivate_time_out_value|  rw  | 0x0 |  — |
|  7  |   int_deactivate_start  |  rw  | 0x0 |  — |
|  8  |    int_activate_start   |  rw  | 0x0 |  — |
|  9  |     slv_tr_complete     |   r  |  —  |  — |
|  10 |     mst_tr_complete     |   r  |  —  |  — |
|  11 | int_deactivate_property |   r  |  —  |  — |
|31:12|      reserved_31_12     |  rw  | 0x0 |  — |

### aou_interrupt_mask register

- Absolute Address: 0xC
- Base Offset: 0xC
- Size: 0x4

<p>Interrupt mask bits for linkreset and early response errors.</p>

|Bits|               Identifier               |Access|Reset|Name|
|----|----------------------------------------|------|-----|----|
| 1:0|              reserved_1_0              |  rw  | 0x0 |  — |
|  2 |        int_si0_id_mismatch_mask        |  rw  | 0x0 |  — |
|  3 |        int_mi0_id_mismatch_mask        |  rw  | 0x0 |  — |
|  4 |           int_early_resp_mask          |  rw  | 0x0 |  — |
|  5 |int_req_linkreset_msgcredit_timeout_mask|  rw  | 0x0 |  — |
|  6 |  int_req_linkreset_invalid_actmsg_mask |  rw  | 0x0 |  — |
|  7 |    int_req_linkreset_deact_ack_mask    |  rw  | 0x0 |  — |
|  8 |     int_req_linkreset_act_ack_mask     |  rw  | 0x0 |  — |
|31:9|              reserved_31_9             |  rw  | 0x0 |  — |

### lp_linkreset register

- Absolute Address: 0x10
- Base Offset: 0x10
- Size: 0x4

<p>ACK/MSG credit timeouts; error status (w1c).</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |      msgcredit_err     |  rw  | 0x0 |  — |
|  1  |   invalid_actmsg_err   |  rw  | 0x0 |  — |
| 5:2 |   invalid_actmsg_info  |   r  | 0x0 |  — |
|  6  |      deact_ack_err     |  rw  | 0x0 |  — |
|  7  |       act_ack_err      |  rw  | 0x0 |  — |
| 10:8|msgcredit_time_out_value|  rw  | 0x4 |  — |
|13:11|   ack_time_out_value   |  rw  | 0x4 |  — |
|31:14|     reserved_31_14     |  rw  | 0x0 |  — |

### dest_rp register

- Absolute Address: 0x14
- Base Offset: 0x14
- Size: 0x4

<p>Destination for RP0-RP3.</p>

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 1:0 |   rp0_dest   |  rw  | 0x0 |  — |
| 3:2 | reserved_3_2 |  rw  | 0x0 |  — |
| 5:4 |   rp1_dest   |  rw  | 0x1 |  — |
| 7:6 | reserved_7_6 |  rw  | 0x0 |  — |
| 9:8 |   rp2_dest   |  rw  | 0x2 |  — |
|11:10|reserved_11_10|  rw  | 0x0 |  — |
|13:12|   rp3_dest   |  rw  | 0x3 |  — |
|31:14|reserved_31_14|  rw  | 0x0 |  — |

### prior_rp_axi register

- Absolute Address: 0x18
- Base Offset: 0x18
- Size: 0x4

<p>QoS and priority for RP AXI; arb mode.</p>

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 1:0 |   arb_mode   |  rw  | 0x0 |  — |
| 3:2 | reserved_3_2 |  rw  | 0x0 |  — |
| 5:4 |   rp0_prior  |  rw  | 0x0 |  — |
| 7:6 | reserved_7_6 |  rw  | 0x0 |  — |
| 9:8 |   rp1_prior  |  rw  | 0x1 |  — |
|11:10|reserved_11_10|  rw  | 0x0 |  — |
|13:12|   rp2_prior  |  rw  | 0x2 |  — |
|15:14|reserved_15_14|  rw  | 0x0 |  — |
|17:16|   rp3_prior  |  rw  | 0x3 |  — |
|19:18|reserved_19_18|  rw  | 0x0 |  — |
|23:20| axi_qos_to_hp|  rw  | 0x5 |  — |
|27:24| axi_qos_to_np|  rw  | 0xA |  — |
|31:28|reserved_31_28|  rw  | 0x0 |  — |

### prior_timer register

- Absolute Address: 0x1C
- Base Offset: 0x1C
- Size: 0x4

<p>Timer resolution and threshold.</p>

| Bits|   Identifier   |Access|Reset|Name|
|-----|----------------|------|-----|----|
| 15:0| timer_threshold|  rw  | 0xF |  — |
|31:16|timer_resolution|  rw  | 0xF |  — |

### axi_split_tr_rp0 register

- Absolute Address: 0x20
- Base Offset: 0x20
- Size: 0x4

<p>Max AW/AR burst length for RP0.</p>

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 7:0 |max_arburstlen|  rw  | 0xF |  — |
| 15:8|max_awburstlen|  rw  | 0xF |  — |
|31:16|reserved_31_16|  rw  | 0x0 |  — |

### error_info_rp0 register

- Absolute Address: 0x24
- Base Offset: 0x24
- Size: 0x4

<p>Split BID/RID mismatch info and error flags (w1c).</p>

| Bits|       Identifier      |Access|Reset|Name|
|-----|-----------------------|------|-----|----|
|  0  | split_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | split_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|split_rid_mismatch_info|   r  |  —  |  — |
|21:12|split_bid_mismatch_info|   r  |  —  |  — |
|31:22|     reserved_31_22    |  rw  | 0x0 |  — |

### write_early_response_rp0 register

- Absolute Address: 0x28
- Base Offset: 0x28
- Size: 0x4

<p>Write response done/error status; early BRESP enable. write_resp_done is read-only input (I_*), driven in AOU_CORE.sv by w_early_bresp_done[0]. err_type_info/err_id_info are captured in flops when error sets.</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |     early_bresp_en     |  rw  | 0x0 |  — |
| 10:1| write_resp_err_id_info |   r  |  —  |  — |
|12:11|write_resp_err_type_info|   r  |  —  |  — |
|  13 |     write_resp_err     |  rw  | 0x0 |  — |
|  14 |     write_resp_done    |   r  |  —  |  — |
|31:15|     reserved_31_15     |  rw  | 0x0 |  — |

### axi_error_info0_rp0 register

- Absolute Address: 0x2C
- Base Offset: 0x2C
- Size: 0x4

<p>Debug upper address for RP0.</p>

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_upper_addr|  rw  | 0x0 |  — |

### axi_error_info1_rp0 register

- Absolute Address: 0x30
- Base Offset: 0x30
- Size: 0x4

<p>Debug lower address for RP0.</p>

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_lower_addr|  rw  | 0x0 |  — |

### axi_slv_id_mismatch_err_rp0 register

- Absolute Address: 0x34
- Base Offset: 0x34
- Size: 0x4

<p>Slave BID/RID mismatch info and error flags (w1c).</p>

| Bits|        Identifier       |Access|Reset|Name|
|-----|-------------------------|------|-----|----|
|  0  | axi_slv_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | axi_slv_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|axi_slv_rid_mismatch_info|   r  |  —  |  — |
|21:12|axi_slv_bid_mismatch_info|   r  |  —  |  — |
|31:22|      reserved_31_22     |  rw  | 0x0 |  — |

### axi_split_tr_rp1 register

- Absolute Address: 0x38
- Base Offset: 0x38
- Size: 0x4

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 7:0 |max_arburstlen|  rw  | 0xF |  — |
| 15:8|max_awburstlen|  rw  | 0xF |  — |
|31:16|reserved_31_16|  rw  | 0x0 |  — |

### error_info_rp1 register

- Absolute Address: 0x3C
- Base Offset: 0x3C
- Size: 0x4

| Bits|       Identifier      |Access|Reset|Name|
|-----|-----------------------|------|-----|----|
|  0  | split_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | split_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|split_rid_mismatch_info|   r  |  —  |  — |
|21:12|split_bid_mismatch_info|   r  |  —  |  — |
|31:22|     reserved_31_22    |  rw  | 0x0 |  — |

### write_early_response_rp1 register

- Absolute Address: 0x40
- Base Offset: 0x40
- Size: 0x4

<p>write_resp_done is read-only input (I_*), driven in AOU_CORE.sv by w_early_bresp_done[1].</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |     early_bresp_en     |  rw  | 0x0 |  — |
| 10:1| write_resp_err_id_info |   r  |  —  |  — |
|12:11|write_resp_err_type_info|   r  |  —  |  — |
|  13 |     write_resp_err     |  rw  | 0x0 |  — |
|  14 |     write_resp_done    |   r  |  —  |  — |
|31:15|     reserved_31_15     |  rw  | 0x0 |  — |

### axi_error_info0_rp1 register

- Absolute Address: 0x44
- Base Offset: 0x44
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_upper_addr|  rw  | 0x0 |  — |

### axi_error_info1_rp1 register

- Absolute Address: 0x48
- Base Offset: 0x48
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_lower_addr|  rw  | 0x0 |  — |

### axi_slv_id_mismatch_err_rp1 register

- Absolute Address: 0x4C
- Base Offset: 0x4C
- Size: 0x4

| Bits|        Identifier       |Access|Reset|Name|
|-----|-------------------------|------|-----|----|
|  0  | axi_slv_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | axi_slv_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|axi_slv_rid_mismatch_info|   r  |  —  |  — |
|21:12|axi_slv_bid_mismatch_info|   r  |  —  |  — |
|31:22|      reserved_31_22     |  rw  | 0x0 |  — |

### axi_split_tr_rp2 register

- Absolute Address: 0x50
- Base Offset: 0x50
- Size: 0x4

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 7:0 |max_arburstlen|  rw  | 0xF |  — |
| 15:8|max_awburstlen|  rw  | 0xF |  — |
|31:16|reserved_31_16|  rw  | 0x0 |  — |

### error_info_rp2 register

- Absolute Address: 0x54
- Base Offset: 0x54
- Size: 0x4

| Bits|       Identifier      |Access|Reset|Name|
|-----|-----------------------|------|-----|----|
|  0  | split_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | split_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|split_rid_mismatch_info|   r  |  —  |  — |
|21:12|split_bid_mismatch_info|   r  |  —  |  — |
|31:22|     reserved_31_22    |  rw  | 0x0 |  — |

### write_early_response_rp2 register

- Absolute Address: 0x58
- Base Offset: 0x58
- Size: 0x4

<p>write_resp_done is read-only input (I_*), driven in AOU_CORE.sv by w_early_bresp_done[2].</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |     early_bresp_en     |  rw  | 0x0 |  — |
| 10:1| write_resp_err_id_info |   r  |  —  |  — |
|12:11|write_resp_err_type_info|   r  |  —  |  — |
|  13 |     write_resp_err     |  rw  | 0x0 |  — |
|  14 |     write_resp_done    |   r  |  —  |  — |
|31:15|     reserved_31_15     |  rw  | 0x0 |  — |

### axi_error_info0_rp2 register

- Absolute Address: 0x5C
- Base Offset: 0x5C
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_upper_addr|  rw  | 0x0 |  — |

### axi_error_info1_rp2 register

- Absolute Address: 0x60
- Base Offset: 0x60
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_lower_addr|  rw  | 0x0 |  — |

### axi_slv_id_mismatch_err_rp2 register

- Absolute Address: 0x64
- Base Offset: 0x64
- Size: 0x4

| Bits|        Identifier       |Access|Reset|Name|
|-----|-------------------------|------|-----|----|
|  0  | axi_slv_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | axi_slv_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|axi_slv_rid_mismatch_info|   r  |  —  |  — |
|21:12|axi_slv_bid_mismatch_info|   r  |  —  |  — |
|31:22|      reserved_31_22     |  rw  | 0x0 |  — |

### axi_split_tr_rp3 register

- Absolute Address: 0x68
- Base Offset: 0x68
- Size: 0x4

| Bits|  Identifier  |Access|Reset|Name|
|-----|--------------|------|-----|----|
| 7:0 |max_arburstlen|  rw  | 0xF |  — |
| 15:8|max_awburstlen|  rw  | 0xF |  — |
|31:16|reserved_31_16|  rw  | 0x0 |  — |

### error_info_rp3 register

- Absolute Address: 0x6C
- Base Offset: 0x6C
- Size: 0x4

| Bits|       Identifier      |Access|Reset|Name|
|-----|-----------------------|------|-----|----|
|  0  | split_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | split_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|split_rid_mismatch_info|   r  |  —  |  — |
|21:12|split_bid_mismatch_info|   r  |  —  |  — |
|31:22|     reserved_31_22    |  rw  | 0x0 |  — |

### write_early_response_rp3 register

- Absolute Address: 0x70
- Base Offset: 0x70
- Size: 0x4

<p>write_resp_done is read-only input (I_*), driven in AOU_CORE.sv by w_early_bresp_done[3].</p>

| Bits|       Identifier       |Access|Reset|Name|
|-----|------------------------|------|-----|----|
|  0  |     early_bresp_en     |  rw  | 0x0 |  — |
| 10:1| write_resp_err_id_info |   r  |  —  |  — |
|12:11|write_resp_err_type_info|   r  |  —  |  — |
|  13 |     write_resp_err     |  rw  | 0x0 |  — |
|  14 |     write_resp_done    |   r  |  —  |  — |
|31:15|     reserved_31_15     |  rw  | 0x0 |  — |

### axi_error_info0_rp3 register

- Absolute Address: 0x74
- Base Offset: 0x74
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_upper_addr|  rw  | 0x0 |  — |

### axi_error_info1_rp3 register

- Absolute Address: 0x78
- Base Offset: 0x78
- Size: 0x4

|Bits|   Identifier   |Access|Reset|Name|
|----|----------------|------|-----|----|
|31:0|debug_lower_addr|  rw  | 0x0 |  — |

### axi_slv_id_mismatch_err_rp3 register

- Absolute Address: 0x7C
- Base Offset: 0x7C
- Size: 0x4

| Bits|        Identifier       |Access|Reset|Name|
|-----|-------------------------|------|-----|----|
|  0  | axi_slv_rid_mismatch_err|  rw  | 0x0 |  — |
|  1  | axi_slv_bid_mismatch_err|  rw  | 0x0 |  — |
| 11:2|axi_slv_rid_mismatch_info|   r  |  —  |  — |
|21:12|axi_slv_bid_mismatch_info|   r  |  —  |  — |
|31:22|      reserved_31_22     |  rw  | 0x0 |  — |
