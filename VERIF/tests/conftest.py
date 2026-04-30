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

"""Pytest entry point for the cocotb testbench.

Provides ``test_aou_loopback_runner`` which invokes cocotb's modern
``runner`` API. This lets developers run ``pytest`` from the
VERIF/ directory and parameterise the simulator across runs:

    pytest -v                       # all simulators that are available
    pytest -v -k verilator          # only Verilator
    SIM=vcs pytest -v               # force Synopsys VCS

Pre-requisites:
    1. ``bash setup_cocotb_env.sh`` has been run.
    2. The chosen simulator binary is on PATH.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import pytest

try:
    # cocotb >=2.0 lives at cocotb.runner; cocotb 1.9 lives at cocotb_tools.runner.
    from cocotb_tools.runner import get_runner  # type: ignore[attr-defined]
except ImportError:  # pragma: no cover - fallback for older installs
    from cocotb.runner import get_runner  # type: ignore[no-redef]


VERIF_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = VERIF_DIR.parents[0]


def _read_filelist(flist_path: Path) -> list[Path]:
    """Parse the ``.f`` file list -- comments stripped, paths resolved."""
    sources: list[Path] = []
    for raw in flist_path.read_text().splitlines():
        line = raw.split("//", 1)[0].strip()
        if not line or line.startswith("+"):
            continue
        sources.append((flist_path.parent / line).resolve())
    return sources


def _candidate_sims() -> list[str]:
    """Return the list of simulators we should attempt to exercise."""
    forced = os.environ.get("SIM")
    if forced:
        return [forced]

    candidates = []
    if shutil.which("verilator") is not None:
        candidates.append("verilator")
    if shutil.which("vcs") is not None:
        candidates.append("vcs")
    return candidates or ["verilator"]


@pytest.mark.parametrize("sim", _candidate_sims())
def test_aou_loopback_runner(sim: str) -> None:
    """Build + run the cocotb testbench for the requested simulator."""
    if shutil.which(sim) is None:
        pytest.skip(f"{sim} not found on PATH")

    sources = _read_filelist(VERIF_DIR / "aou_cocotb.f")
    build_dir = VERIF_DIR / "sim_build" / sim

    # JOBS controls parallelism for Verilator's C++ compile phase.
    # Default 8; override with `JOBS=N pytest ...`. JOBS=0 means all cores.
    #
    # --build-jobs only matters if verilator itself runs the C++ build
    # (verilator --build). The cocotb runner does not use --build; it
    # invokes the generated Vtop.mk via its own make. To get parallel g++
    # we therefore inject -jN into MAKEFLAGS, which every make child
    # process inherits. JOBS=0 -> bare "-j" (unlimited).
    jobs = os.environ.get("JOBS", "8")
    make_j_flag = "-j" if jobs == "0" else f"-j{jobs}"
    existing_makeflags = os.environ.get("MAKEFLAGS", "")
    if make_j_flag not in existing_makeflags.split():
        os.environ["MAKEFLAGS"] = (existing_makeflags + " " + make_j_flag).strip()

    build_args: list[str] = []
    if sim == "verilator":
        build_args += [
            "--build-jobs", jobs,
            "--timing", "-sv", "--timescale", "1ns/1ps",
            "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "-Wno-UNUSEDSIGNAL",
            "-Wno-UNUSEDPARAM", "-Wno-DECLFILENAME", "-Wno-PINCONNECTEMPTY",
            "-Wno-TIMESCALEMOD", "-Wno-fatal",
        ]
    elif sim == "vcs":
        build_args += [
            "-sverilog", "-full64", "-timescale=1ns/1ps",
            "-debug_access+all", "+warn=noTFIPC", "-suppress=IFSF", "-kdb",
        ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="aou_cocotb_top",
        build_dir=str(build_dir),
        build_args=build_args,
        always=True,
    )
    runner.test(
        hdl_toplevel="aou_cocotb_top",
        # Both modules share a single elab/build; cocotb runs each
        # @cocotb.test from each module in turn within one simulator
        # invocation. Keep this list in sync with the Makefile MODULE
        # default so `make` and `pytest` exercise the same coverage.
        test_module=["test_aou_loopback", "test_csr_reset"],
        build_dir=str(build_dir),
        test_dir=str(VERIF_DIR / "tests"),
    )
