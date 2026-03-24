#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# (c) 2026 Tenstorrent USA Inc
"""Validate IP-XACT XML files against the Accellera IEEE 1685-2014 XSD schema.

The schema files are auto-downloaded from the Accellera website on first run
and cached locally in INTEG/ipxact/schema/ (gitignored).

Usage:
    python3 scripts/validate_ipxact.py INTEG/ipxact/gen/aou_core_regmap.xml
    python3 scripts/validate_ipxact.py file1.xml file2.xml ...
"""

import argparse
import os
import re
import sys
import urllib.request
from pathlib import Path

from lxml import etree

SCHEMA_BASE_URL = "http://www.accellera.org/XMLSchema/IPXACT/1685-2014"
INDEX_XSD = "index.xsd"

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CACHE_DIR = REPO_ROOT / "INTEG" / "ipxact" / "schema" / "1685-2014"


def _fetch(url: str, dest: Path) -> None:
    """Download a URL to a local file, creating parent dirs as needed."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  Fetching {url}")
    urllib.request.urlretrieve(url, dest)


def _ensure_schema_cached(cache_dir: Path) -> Path:
    """Download the Accellera 1685-2014 XSD files if not already cached.

    Returns the path to the local index.xsd.
    """
    index_path = cache_dir / INDEX_XSD
    if index_path.exists():
        return index_path

    print(f"Downloading IEEE 1685-2014 schema to {cache_dir} ...")
    _fetch(f"{SCHEMA_BASE_URL}/{INDEX_XSD}", index_path)

    index_text = index_path.read_text()
    includes = re.findall(r'schemaLocation="([^"]+\.xsd)"', index_text)

    for inc in includes:
        inc_path = cache_dir / inc
        if not inc_path.exists():
            _fetch(f"{SCHEMA_BASE_URL}/{inc}", inc_path)

    all_xsd = list(cache_dir.glob("*.xsd"))
    found_more = True
    while found_more:
        found_more = False
        for xsd_file in all_xsd:
            text = xsd_file.read_text()
            refs = re.findall(r'schemaLocation="([^"]+\.xsd)"', text)
            for ref in refs:
                ref_path = cache_dir / ref
                if not ref_path.exists():
                    _fetch(f"{SCHEMA_BASE_URL}/{ref}", ref_path)
                    all_xsd.append(ref_path)
                    found_more = True

    print(f"  Cached {len(list(cache_dir.glob('*.xsd')))} XSD files.\n")
    return index_path


def validate_file(xml_path: str, schema: etree.XMLSchema) -> bool:
    """Validate a single XML file. Returns True if valid."""
    try:
        doc = etree.parse(xml_path)
    except etree.XMLSyntaxError as e:
        print(f"FAIL  {xml_path}  (XML parse error)")
        print(f"      {e}")
        return False

    if schema.validate(doc):
        print(f"PASS  {xml_path}")
        return True
    else:
        print(f"FAIL  {xml_path}")
        for err in schema.error_log:
            print(f"      Line {err.line}: {err.message}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("xml_files", nargs="+",
                        help="IP-XACT XML files to validate")
    parser.add_argument("--schema-cache", default=str(DEFAULT_CACHE_DIR),
                        help="Directory to cache downloaded XSD files "
                             f"(default: {DEFAULT_CACHE_DIR})")
    args = parser.parse_args()

    cache_dir = Path(args.schema_cache)
    index_path = _ensure_schema_cached(cache_dir)

    schema_doc = etree.parse(str(index_path))
    schema = etree.XMLSchema(schema_doc)

    all_pass = True
    for xml_file in args.xml_files:
        if not os.path.isfile(xml_file):
            print(f"SKIP  {xml_file}  (file not found)")
            all_pass = False
            continue
        if not validate_file(xml_file, schema):
            all_pass = False

    if all_pass:
        print("\nAll files passed IP-XACT schema validation.")
    else:
        print("\nSome files FAILED validation.", file=sys.stderr)

    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
