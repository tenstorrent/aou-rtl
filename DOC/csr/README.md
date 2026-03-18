# AOU RTL Documentation

## Register map

- **[aou-core-csrs.md](aou-core-csrs.md)** – AOU Core control and status registers (CSRs), generated from `csr/aou-core.rdl`. Includes address map, register offsets, and field definitions (bits, access, reset).

To regenerate after editing the RDL:

```bash
source venv/bin/activate
peakrdl markdown csr/aou-core.rdl -t aou_core -o DOC/csr/aou-core-csrs.md
```
