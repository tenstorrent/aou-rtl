#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# (c) 2026 Tenstorrent USA Inc
"""Merge PeakRDL-generated register memoryMap into an IP-XACT component template.

Phase 2 helper: takes the hand-authored component_template.xml (which defines
busInterfaces, ports, parameters) and injects the <memoryMaps> element from the
PeakRDL-generated register-map XML.

Usage:
    python3 scripts/merge_ipxact.py \
        --template INTEG/ipxact/component_template.xml \
        --regmap   INTEG/ipxact/gen/aou_core_regmap.xml \
        --output   INTEG/ipxact/aou_core_top.xml
"""

import argparse
import xml.etree.ElementTree as ET

IPXACT_NS = "http://www.accellera.org/XMLSchema/IPXACT/1685-2014"
NS = {"ipxact": IPXACT_NS}


def merge(template_path: str, regmap_path: str, output_path: str) -> None:
    ET.register_namespace("", IPXACT_NS)

    tmpl_tree = ET.parse(template_path)
    tmpl_root = tmpl_tree.getroot()

    reg_tree = ET.parse(regmap_path)
    reg_root = reg_tree.getroot()

    memory_maps = reg_root.find("ipxact:memoryMaps", NS)
    if memory_maps is None:
        comp = reg_root.find("ipxact:component", NS) or reg_root
        memory_maps = comp.find("ipxact:memoryMaps", NS)
    if memory_maps is None:
        raise RuntimeError(f"No <memoryMaps> found in {regmap_path}")

    existing = tmpl_root.find("ipxact:memoryMaps", NS)
    if existing is not None:
        tmpl_root.remove(existing)

    model_idx = None
    for i, child in enumerate(tmpl_root):
        tag = child.tag.split("}")[-1] if "}" in child.tag else child.tag
        if tag == "model":
            model_idx = i
            break

    if model_idx is not None:
        tmpl_root.insert(model_idx, memory_maps)
    else:
        tmpl_root.append(memory_maps)

    ET.indent(tmpl_tree, space="  ")
    tmpl_tree.write(output_path, xml_declaration=True, encoding="UTF-8")
    print(f"Merged memoryMaps into {output_path}")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--template", required=True,
                    help="Component template XML (hand-authored)")
    p.add_argument("--regmap", required=True,
                    help="PeakRDL-generated register XML")
    p.add_argument("--output", required=True,
                    help="Output merged component XML")
    args = p.parse_args()
    merge(args.template, args.regmap, args.output)
