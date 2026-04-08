# AOU-RTL: AXI-over-UCIe Bridge IP

Open-source RTL implementation of the AXI-over-UCIe (AoU) protocol [[1]](#references), bridging AXI4 traffic [[3]](#references) over the Universal Chiplet Interconnect Express (UCIe) 3.0 Flit-Die Interface (FDI) [[2]](#references). This bridge enables native AXI transactions to traverse UCIe die-to-die interconnects, facilitating high-performance communication between heterogeneous chiplets in multi-die systems—such as CPUs, GPUs, AI accelerators, and custom IP blocks—without requiring protocol conversion through PCIe or CXL.

The top-level module `AOU_CORE_TOP` provides AXI4 master and slave interfaces, an APB3 configuration port [[4]](#references), and 32B/64B FDI interfaces for integration into UCIe-based chiplet designs.

## Directory Structure

```
RTL/                    Design source (SystemVerilog / Verilog)
  LIB/                  Behavioral library cells (see Integration section)
  AXI4MUX_3X1/          AXI 3:1 mux / splitter / aggregator
csr/                    SystemRDL register definitions
DOC/                    Documentation
  integration_guide/    AOU_CORE_TOP integration guide
  csr/                  Generated register docs (Markdown, HTML, C header)
INTEG/                  Integration collateral
  constraints/          SDC timing constraints and UPF power intent
  ipxact/               IP-XACT register map
VERIF/                  Verification testbench and infrastructure
scripts/                Collateral generation and validation scripts
```

## Getting Started

The fastest way to explore this IP:

1. **Clone and setup environment:**
   ```bash
   git clone https://github.com/tenstorrent/aou-rtl.git
   cd aou-rtl
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Generate documentation and integration collateral:**
   ```bash
   bash scripts/gen_collateral.sh
   ```

3. **Review the interactive register browser:**
   Open `DOC/csr/html/index.html` in your browser to explore the register map.

4. **Run verification (requires VCS and VIP libraries):**
   ```bash
   cd VERIF && ./run_vcs.sh
   ```

See sections below for detailed documentation, integration guidance, and tool requirements.

## Documentation

- **[Integration Guide](DOC/integration_guide/AOU_CORE_TOP_integration_guide.md)** -- comprehensive guide covering module interfaces, register map, activation flow, debugging, verification, timing constraints, power intent, and library cell replacement.
- **[CSR Documentation](DOC/csr/README.md)** -- register map outputs (Markdown, C header, interactive HTML browser, IP-XACT, UVM model).
- **Interactive HTML Register Browser** -- generated in `DOC/csr/html/` (see Tool Requirements below to generate).

## Tool Requirements

A Python virtual environment is needed for register-map and documentation tooling (PeakRDL):

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

After setup, regenerate all IP integration collateral (register docs, IP-XACT, C header, HTML, UVM model):

```bash
bash scripts/gen_collateral.sh
```

## Running Verification

Before running simulation, follow the instructions in the [`VERIF/`](VERIF/) directory to download the required VIP libraries.

The testbench uses VCS:

```bash
cd VERIF && ./run_vcs.sh
```

This runs a dual-DUT FDI loopback simulation with AXI scoreboard-based data integrity checking. Transaction logging is enabled with `+define+AXI_LOG`.

## Integration

For integrators bringing AOU_CORE_TOP into a chip design:

- **[Integration Guide, Section 9](DOC/integration_guide/AOU_CORE_TOP_integration_guide.md#9-ip-integration-collateral)** covers all integration collateral: generated outputs, timing constraints (SDC), power intent (UPF), and library cell replacement guidance.
- **Timing constraints**: `INTEG/constraints/aou_core_top.sdc` (1 GHz core, 100 MHz APB).
- **Power intent**: `INTEG/constraints/aou_core_top.upf` (single always-on domain).
- **Library cells** in `RTL/LIB/` are behavioral reference models that must be replaced with process-appropriate implementations before synthesis. See integration guide section 9.7 for details.

## License

This project originated from a collaboration between BOS Semiconductors and Tenstorrent USA, Inc.:

- **Code**: Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full license text.
- **Documentation and images**: All documentation, images, and generated HTML content in the DOC/ directory are licensed under Creative Commons Attribution 4.0 International (CC-BY). See [LICENSE-DOCS](LICENSE-DOCS).
- **License clarification**: See [LICENSE_understanding.txt](LICENSE_understanding.txt) for common questions about commercial use, modifications, and patent grants.
- **Copyright holders**: See [COPYRIGHT](COPYRIGHT) for detailed copyright information.
- **Third-party attributions**: See [NOTICE](NOTICE) for required notices and attributions.

## Contributing

We welcome contributions from the community! Here's how you can help:

- **Report bugs**: Submit issues via [GitHub Issues](https://github.com/tenstorrent/aou-rtl/issues)
- **Submit changes**: Create pull requests for bug fixes and new features
- **Review process**: Pull requests are reviewed on a weekly basis

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on how to contribute, including coding standards, testing requirements, and commit message format.

All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

For security vulnerabilities, please see our [Security Policy](SECURITY.md) for responsible disclosure procedures.

## References

1. **AXI over UCIe (AoU) Protocol Specification, v0.7**  
   *Access through Open Chiplet Atlas. This specification defines the native mapping of AMBA AXI transactions over UCIe die-to-die interconnects.*  
   Contact: [Open Chiplet Atlas](https://openchipletatlas.org)

2. **Universal Chiplet Interconnect Express (UCIe) Specification, Revision 3.0**  
   *Available through the UCIe Consortium.*  
   Download: [UCIe Consortium Specifications](https://www.uciexpress.org/specifications)

3. **Arm AMBA AXI and ACE Protocol Specification (AXI4)**  
   *Official Arm specification for the Advanced eXtensible Interface protocol.*  
   Download: [Arm Developer Documentation](https://developer.arm.com/documentation/ihi0022)

4. **Arm AMBA APB Protocol Specification**  
   *Official Arm specification for the Advanced Peripheral Bus protocol.*  
   Download: [Arm Developer Documentation](https://developer.arm.com/documentation/ihi0024)

---

## Third-Party Trademarks

Arm, AMBA, AXI, APB, and ACE are registered trademarks or trademarks of Arm Limited (or its subsidiaries) in the US and/or elsewhere.

Universal Chiplet Interconnect Express (UCIe) is a trademark of the UCIe Consortium.

All other trademarks are the property of their respective owners.
