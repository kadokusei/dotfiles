#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""Regression tests for agent-skills-sync definition installation.

Home Manager deploys ~/.config/agent-skills/* as read-only symlinks into the
Nix store. shutil.copy2 preserves that 444 mode, so a plain copy leaves
~/.apm/apm.yml unwritable and the next switch fails with Permission denied.
"""

import importlib.machinery
import importlib.util
import shutil
import stat
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True  # keep SourceFileLoader from creating config/__pycache__
SCRIPT = Path(__file__).resolve().parents[1] / "config" / "agent-skills-sync"
loader = importlib.machinery.SourceFileLoader("agent_skills_sync", str(SCRIPT))
spec = importlib.util.spec_from_loader("agent_skills_sync", loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)


def test_copy2_cannot_overwrite_readonly_destination():
    """Documents why install_definition must not use shutil.copy2 directly."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        source = tmp / "source.yml"
        source.write_text("new: 1\n")
        target = tmp / "apm.yml"
        target.write_text("old: 1\n")
        target.chmod(0o444)
        try:
            shutil.copy2(source, target)
        except PermissionError:
            return
        raise AssertionError("copy2 unexpectedly overwrote a read-only file")


def test_install_definition_replaces_readonly_destination():
    """Syncing over a previous run's read-only output must succeed atomically."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        source = tmp / "config" / "apm.yml"
        source.parent.mkdir()
        source.write_text("new: 1\n")
        source.chmod(0o444)  # Nix store source is read-only
        target = tmp / "active" / "apm.yml"
        target.parent.mkdir()
        target.write_text("old: 1\n")
        target.chmod(0o444)  # previous run left it read-only

        mod.install_definition(source, target)

        assert target.read_text() == "new: 1\n", "destination content must be updated"
        assert stat.S_IMODE(target.stat().st_mode) == 0o644, "destination must be writable"
        assert not list(target.parent.glob(f".{target.name}.*")), "no temp file may remain"


def test_install_definition_fresh_destination():
    """First sync into a missing file must also work."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        source = tmp / "apm.yml"
        source.write_text("new: 1\n")
        source.chmod(0o444)
        target = tmp / "active" / "apm.yml"
        target.parent.mkdir()

        mod.install_definition(source, target)

        assert target.read_text() == "new: 1\n"
        assert stat.S_IMODE(target.stat().st_mode) == 0o644


def test_install_definition_survives_stale_readonly_temp():
    """A read-only temp file left by a crashed run must not block the next one."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        source = tmp / "apm.yml"
        source.write_text("new: 1\n")
        source.chmod(0o444)
        target = tmp / "active" / "apm.yml"
        target.parent.mkdir()
        target.write_text("old: 1\n")
        stale = target.parent / ".apm.yml.crashed"
        stale.write_text("garbage\n")
        stale.chmod(0o444)  # interrupted before chmod in a previous run

        mod.install_definition(source, target)

        assert target.read_text() == "new: 1\n"
        assert stat.S_IMODE(target.stat().st_mode) == 0o644


def main():
    failures = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print(f"ok   {name}")
            except AssertionError as exc:
                failures += 1
                print(f"FAIL {name}: {exc}")
            except Exception as exc:  # noqa: BLE001 - report and continue
                failures += 1
                print(f"ERROR {name}: {type(exc).__name__}: {exc}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
