# AOU CSR Documentation

All files in this directory are generated from the SystemRDL source
(`csr/aou-core.rdl`).  Do not edit them by hand -- regenerate instead.

## Generated outputs

| File | Description |
| :--- | :--- |
| [aou-core-csrs.md](aou-core-csrs.md) | Markdown register reference (address map, fields, access, reset values). |
| [aou_core_csr.h](aou_core_csr.h) | C header with `#define` macros for register offsets and field masks. |
| [html/](html/) | Interactive HTML register browser (open `html/content/index.html` locally or host on GitLab Pages). |

Additional generated collateral lives outside this directory:

| File | Description |
| :--- | :--- |
| `INTEG/ipxact/gen/aou_core_regmap.xml` | IP-XACT (IEEE 1685-2014) register memoryMap for SoC integration tools. |
| `VERIF/aou_core_csr_uvm_pkg.sv` | UVM register model package for verification. |

## Regeneration

A single script regenerates all of the above from the RDL source:

```bash
source venv/bin/activate
bash scripts/gen_collateral.sh
```

See the top-level [README.md](../../README.md) for virtual-environment setup instructions.
