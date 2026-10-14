#!/usr/bin/env python3
"""Exercise Nix-generated SSH helpers with synthetic keys and an isolated agent."""

import os
import pty
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
PASSPHRASE = "synthetic-test-passphrase"
LEAK = "SYNTHETIC-OP-OUTPUT-MUST-NOT-LEAK"


def generated_helpers():
    return {
        name: subprocess.check_output(
            ["nix", "eval", "--option", "eval-cache", "false", "--no-write-lock-file", "--raw",
             '.#darwinConfigurations.helium.config.home-manager.users.readabi1ity.'
             f'home.file.".local/bin/{name}".text'],
            cwd=REPO, text=True,
        )
        for name in ("ssh-add-github", "github-key-askpass")
    }


class Sandbox:
    def __init__(self, root, helpers):
        self.home = Path(root)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        (self.home / ".ssh").mkdir(mode=0o700)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("SSH_", "OP_"))}
        self.env.update(HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin",
                        DISPLAY=":0", SSH_AUTH_SOCK=str(self.home / ".ssh/github-agent.sock"))
        for name, text in helpers.items():
            path = self.bin / name
            path.write_text(text)
            path.chmod(0o755)
        self.op = self.bin / "op"
        self.op.write_text(
            f"#!{sys.executable}\n"
            "import os, subprocess, sys, time\n"
            "from pathlib import Path\n"
            "Path(os.environ['HOME'], 'op-called').touch()\n"
            "if os.environ.get('TEST_OP_FAIL'):\n"
            f"    print({LEAK!r}, flush=True)\n"
            f"    print({LEAK!r}, file=sys.stderr, flush=True)\n"
            "    sys.exit(42)\n"
            "if os.environ.get('TEST_OP_KILL_TIMEOUT'):\n"
            "    os.kill(os.getppid(), 9)\n"
            "    sys.exit(1)\n"
            "if os.environ.get('TEST_OP_RETAIN_FD'):\n"
            "    child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'],\n"
            "        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,\n"
            "        stderr=subprocess.DEVNULL, close_fds=False)\n"
            "    Path(os.environ['HOME'], 'op-pids').write_text(f'{os.getpid()} {child.pid}')\n"
            f"    print({PASSPHRASE!r}, flush=True)\n"
            "    sys.exit(0)\n"
            "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])\n"
            "Path(os.environ['HOME'], 'op-pids').write_text(f'{os.getpid()} {child.pid}')\n"
            "try:\n"
            "    time.sleep(float(os.environ.get('TEST_OP_DELAY', '0')))\n"
            f"    print({PASSPHRASE!r})\n"
            "finally:\n"
            "    child.terminate()\n"
            "    child.wait()\n"
        )
        self.op.chmod(0o755)
        self.key = self.home / ".ssh/id_ed25519_github"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", PASSPHRASE,
                        "-f", str(self.key)], env=self.env, check=True)
        self.fingerprint = subprocess.check_output(
            ["ssh-keygen", "-lf", str(self.key) + ".pub"], env=self.env, text=True,
        ).split()[1]
        self.agent = subprocess.Popen(
            ["ssh-agent", "-D", "-a", self.env["SSH_AUTH_SOCK"]], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        for _ in range(100):
            if Path(self.env["SSH_AUTH_SOCK"]).exists():
                break
            assert self.agent.poll() is None, "isolated agent exited"
            time.sleep(0.05)
        else:
            self.close()
            raise AssertionError("isolated agent did not start")

    def close(self):
        self.agent.terminate()
        self.agent.wait(timeout=5)
        pids = self.home / "op-pids"
        if pids.exists():
            for pid in map(int, pids.read_text().split()):
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def run(self, *args, **env):
        return subprocess.run(
            [str(self.bin / "ssh-add-github"), *args], env=self.env | env,
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=40,
            start_new_session=True,
        )

    def listed(self):
        return subprocess.run(["ssh-add", "-l"], env=self.env,
                              capture_output=True, text=True)

    def terminal(self, *args, cancel=False, **env):
        start = time.monotonic()
        pid, fd = pty.fork()
        if pid == 0:
            os.execve(str(self.bin / "ssh-add-github"),
                      ["ssh-add-github", *args], self.env | env)
        output = bytearray()
        answered = interrupted = exited = False
        try:
            while time.monotonic() - start < 40:
                if cancel and not interrupted and (self.home / "op-pids").exists():
                    os.write(fd, b"\x03")
                    interrupted = True
                if select.select([fd], [], [], 0.05)[0]:
                    try:
                        data = os.read(fd, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    output.extend(data)
                if b"Enter passphrase" in output and not answered and not cancel:
                    os.write(fd, (PASSPHRASE + "\n").encode())
                    answered = True
                done, status = os.waitpid(pid, os.WNOHANG)
                if done:
                    exited = True
                    # The PTY may still contain the final diagnostic.
                    while select.select([fd], [], [], 0.1)[0]:
                        try:
                            data = os.read(fd, 65536)
                        except OSError:
                            break
                        if not data:
                            break
                        output.extend(data)
                    break
            else:
                raise AssertionError("PTY command exceeded 40 seconds")
            if not exited:
                _, status = os.waitpid(pid, 0)
                exited = True
            return os.waitstatus_to_exitcode(status), output.decode(), time.monotonic() - start
        finally:
            os.close(fd)
            if not exited:
                try:
                    os.killpg(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)


def test_lifetime(s):
    result = s.run("-t", "2s")
    assert result.returncode == 0, result.stderr
    assert s.fingerprint in s.listed().stdout, "synthetic key not loaded"
    time.sleep(5)
    assert s.listed().returncode == 1, "key did not expire"


def test_arguments(s):
    s.key.unlink()
    result = s.run("--help")
    assert result.returncode == 0 and "Usage:" in result.stdout, result.stderr
    for args in [("-t",), ("-t", "0"), ("--unknown",), ("-t", "-1"),
                 ("-t", ""), ("-t", "1h30m"), ("positional",),
                 ("-t", "1s\nSYNTHETIC-INVALID-DURATION")]:
        result = s.run(*args)
        assert result.returncode == 2, (args, result.returncode, result.stderr)
        assert "Usage:" in result.stderr
        assert "SYNTHETIC-INVALID-DURATION" not in result.stderr
    assert not (s.home / "op-called").exists(), "invalid arguments invoked op"


def test_delayed_unlock(s):
    result = s.run(TEST_OP_DELAY="12")
    assert result.returncode == 0, result.stderr
    assert s.fingerprint in s.listed().stdout, "delayed unlock did not load key"


def test_inherited_askpass_fd(s):
    process = subprocess.Popen(
        [str(s.bin / "ssh-add-github")], env=s.env | {"TEST_OP_RETAIN_FD": "1"},
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, start_new_session=True,
    )
    try:
        _, stderr = process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        _, stderr = process.communicate(timeout=5)
        assert "stage=op end status=0" in stderr, "op did not complete"
        raise AssertionError("op succeeded but ssh-add is waiting for inherited pipe EOF")
    assert process.returncode == 0, stderr
    assert s.fingerprint in s.listed().stdout, "key was not registered"
    assert "stage=gui end status=0" in stderr, stderr


def test_failure_fallback(s):
    status, output, _ = s.terminal(TEST_OP_FAIL="1")
    assert status == 0, output
    assert s.fingerprint in s.listed().stdout, "manual fallback did not load key"
    assert "stage=op end status=42" in output, output
    assert "reason=failed" in output and "reason=gui-failed" in output, output
    assert "stage=add end status=0" in output, output
    assert LEAK not in output and PASSPHRASE not in output, "op output leaked"


def test_killed_timeout(s):
    status, output, _ = s.terminal(TEST_OP_KILL_TIMEOUT="1")
    assert status == 0 and s.fingerprint in s.listed().stdout, output
    assert "stage=op end status=137" in output, output
    assert "reason=timeout" in output, output
    assert "op://" not in output, "shell job diagnostic exposed the secret reference"


def test_cancel(s):
    status, output, elapsed = s.terminal(cancel=True, TEST_OP_DELAY="30")
    assert status == 130, (status, output)
    assert "stage=manual" not in output and "Enter passphrase" not in output, output
    assert elapsed < 10, "Ctrl-C waited for the authentication timeout"
    pids = (s.home / "op-pids").read_text().split()
    for _ in range(60):
        states = subprocess.run(["ps", "-p", ",".join(pids), "-o", "stat="],
                                capture_output=True, text=True).stdout.split()
        if all(state.startswith("Z") for state in states):
            break
        time.sleep(0.05)
    else:
        raise AssertionError("op or its child survived Ctrl-C")


def test_timeout(s):
    for quiet in [(), ("-q",), ("--quiet",)]:
        subprocess.run(["ssh-add", "-D"], env=s.env, check=True, capture_output=True)
        status, output, elapsed = s.terminal(
            *quiet, TEST_OP_DELAY="30", SSH_ADD_GITHUB_DEBUG="0" if not quiet else "1",
        )
        assert status == 0, output
        assert 19 <= elapsed <= 30, (elapsed, output)
        assert s.fingerprint in s.listed().stdout, "timeout fallback did not load key"
        assert "warning=op-timeout status=124 manual-fallback" in output, output
        assert "Enter passphrase" in output, output
        assert PASSPHRASE not in output, "passphrase appeared in terminal output"
        if quiet:
            assert "stage=" not in output, output
        else:
            assert "stage=op end status=124" in output and "reason=timeout" in output, output
            assert "stage=manual start reason=gui-failed" in output, output
            assert "stage=add end status=0" in output, output


def test_manual(s):
    for reason in ("explicit", "ssh-session", "op-missing"):
        subprocess.run(["ssh-add", "-D"], env=s.env, check=True, capture_output=True)
        if reason == "op-missing":
            s.op.unlink()
        status, output, _ = s.terminal(
            *(["--manual"] if reason == "explicit" else []),
            SSH_CONNECTION="synthetic" if reason == "ssh-session" else "",
            SSH_ASKPASS="/nonexistent-inherited-askpass", SSH_ASKPASS_REQUIRE="force",
        )
        assert status == 0 and s.fingerprint in s.listed().stdout, output
        assert f"stage=manual start reason={reason}" in output, output
        assert "stage=op" not in output and not (s.home / "op-called").exists(), output


def main():
    helpers = generated_helpers()
    selected = sys.argv[1:] or [
        "arguments", "lifetime", "delayed_unlock", "failure_fallback", "killed_timeout",
        "cancel", "timeout", "manual", "inherited_askpass_fd",
    ]
    for name in selected:
        with tempfile.TemporaryDirectory(prefix="ssh-github-", dir="/tmp") as root:
            sandbox = Sandbox(root, helpers)
            try:
                globals()[f"test_{name}"](sandbox)
                print(f"ok   {name}", flush=True)
            finally:
                sandbox.close()


if __name__ == "__main__":
    main()
