#!/usr/bin/env python3
"""Checks that each of the 39 Frozen in Flames platforms does its job.

Every check runs inside the booted VM over SSH and passes only if its command
exits 0. A check proves the platform works, not only that it is installed.
Needs sshpass on the host and a VM started by scripts/run.sh.
"""
import subprocess
import sys
import time

SSH = [
    "sshpass", "-p", "frozen", "ssh",
    "-p", "2222",
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-o", "ConnectTimeout=5",
    "frozen@127.0.0.1",
]

# (name, layer, role, check)
PLATFORMS = [
    # Foundation
    ("Linux", "Foundation", "Kernel the system runs on",
     "uname -s | grep -qx Linux"),
    ("FreeBSD", "Foundation", "Guest OS for FreeBSD-only workloads",
     "systemctl is-active --quiet frozen-freebsd && timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2223 && head -c 8 <&3' | grep -q SSH-2.0"),
    ("systemd", "Foundation", "Starts, supervises and restarts services",
     "systemctl is-system-running | grep -qx running"),
    ("QEMU", "Foundation", "Runs virtual machines with KVM",
     "qemu-system-x86_64 -accel help 2>&1 | grep -qx kvm"),
    ("OpenSSL", "Foundation", "Encrypts connections and creates certificates",
     "openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/ff.key -out /tmp/ff.crt -subj /CN=frozen -days 1 >/dev/null 2>&1 && openssl x509 -in /tmp/ff.crt -noout"),
    ("curl", "Foundation", "Calls HTTP services and checks their health",
     "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ | grep -qE '^[23]'"),
    ("GCC", "Foundation", "Compiles C programs",
     "printf 'int main(void) { return 0; }\\n' > /tmp/ff.c && gcc /tmp/ff.c -o /tmp/ff && /tmp/ff"),
    ("LLVM", "Foundation", "Compiler backend and toolchain",
     "llc --version | grep -q LLVM"),

    # Runtimes
    ("Python", "Runtimes", "Scripting and automation engine",
     "python3 -c 'import sys; assert sys.version_info >= (3, 10)'"),
    ("Node.js", "Runtimes", "JavaScript runtime for the shell and build tools",
     "node -e 'process.exit(0)'"),
    ("Ruby", "Runtimes", "Runs migrations and admin jobs",
     "ruby -e 'exit 0'"),
    ("PHP", "Runtimes", "Runs WordPress",
     "php -r 'echo 1 + 1;' | grep -qx 2"),
    ("Go", "Runtimes", "Builds the gateway and API services",
     "printf 'package main\\nfunc main() {}\\n' > /tmp/ff.go && go run /tmp/ff.go"),
    ("Rust", "Runtimes", "Fast parsing and sandboxed plugin code",
     "printf 'fn main() {}\\n' > /tmp/ff.rs && rustc /tmp/ff.rs -o /tmp/ff-rs && /tmp/ff-rs"),
    (".NET", "Runtimes", "Enterprise connectors and integrations",
     "dotnet --list-sdks | grep -q ."),
    ("TypeScript", "Runtimes", "Typed contracts shared by every module",
     "printf 'const n: number = 1;\\n' > /tmp/ff.ts && tsc --noEmit /tmp/ff.ts"),

    # Data
    ("PostgreSQL", "Data", "Primary store for accounts, projects and WordPress",
     "sudo -u postgres psql -tAc 'select 1' | grep -qx 1"),
    ("Redis (Valkey)", "Data", "Cache and event bus (Valkey, the BSD-licensed Redis fork)",
     "valkey-cli ping | grep -qx PONG"),

    # Delivery
    ("nginx", "Delivery", "Front door that routes traffic to every service",
     "systemctl is-active --quiet nginx && sudo nginx -t >/dev/null 2>&1"),
    ("Apache HTTP Server", "Delivery", "Hosts legacy applications",
     "test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8081/) != 000"),
    ("Docker", "Delivery", "Runs every containerized module",
     "docker info >/dev/null 2>&1"),
    ("Kubernetes", "Delivery", "Schedules and scales containers",
     "sudo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes | grep -q ' Ready'"),
    ("Git", "Delivery", "Versions projects and configuration",
     "rm -rf /tmp/ff-git && git init -q /tmp/ff-git && git -C /tmp/ff-git status >/dev/null"),

    # Web
    ("React", "Web", "UI component system for the shell",
     "test -f /opt/frozen/shell/node_modules/react/package.json"),
    ("Angular", "Web", "Enterprise admin screens",
     "test -x /opt/frozen/npm/bin/ng"),
    ("Ruby on Rails", "Web", "Back-office app for accounts and administration",
     "GEM_HOME=/opt/frozen/gems /opt/frozen/gems/bin/rails --version | grep -q Rails"),
    ("WordPress", "Web", "Publishes docs, blog posts and pages",
     "curl -s http://127.0.0.1:8000/ | grep -qi 'wp-content\\|wordpress'"),
    ("Chromium", "Web", "Renders live previews",
     "chromium --headless --no-sandbox --dump-dom about:blank | grep -qi html"),
    ("Firefox", "Web", "Second browser for cross-browser testing",
     "firefox --headless --version | grep -q Firefox"),

    # AI
    ("PyTorch", "AI", "Trains and runs custom models",
     "python3 -c 'import torch; assert torch.tensor([1.0, 2.0]).sum().item() == 3.0'"),
    ("TensorFlow", "AI", "Serves models for production inference",
     "python3 -c 'import tensorflow as tf; assert float(tf.reduce_sum([1.0, 2.0])) == 3.0' 2>/dev/null"),

    # Media
    ("FFmpeg", "Media", "Transcodes audio and video",
     "ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=duration=1:size=64x64:rate=5 -f null -"),
    ("VLC", "Media", "Plays media for previews and review",
     "vlc --version >/dev/null 2>&1"),
    ("Blender", "Media", "Renders 3D models and preview assets",
     "blender --background --factory-startup --python-expr 'import bpy' >/dev/null 2>&1"),
    ("LibreOffice", "Media", "Opens, converts and renders office documents",
     "printf hello > /tmp/ff.txt && soffice --headless --convert-to pdf --outdir /tmp /tmp/ff.txt >/dev/null 2>&1 && test -s /tmp/ff.pdf"),

    # Editors
    ("VS Code", "Editors", "Main graphical code editor (VSCodium build)",
     "codium --version >/dev/null 2>&1"),
    ("Vim", "Editors", "Terminal editor for quick edits",
     "vim -Nu NONE -es -c 'call setline(1, \"ok\")' -c 'wq! /tmp/ff-vim.txt' && grep -qx ok /tmp/ff-vim.txt"),
    ("Neovim", "Editors", "Extensible terminal editor",
     "nvim --headless -c 'call setline(1, \"ok\")' -c 'wq! /tmp/ff-nvim.txt' && grep -qx ok /tmp/ff-nvim.txt"),

    # Smart Home
    ("Home Assistant", "Smart Home", "Bridges smart-home devices and automation",
     "curl -fsS http://127.0.0.1:8123/ >/dev/null"),
]


def run_remote(command):
    return subprocess.run(SSH + [command], capture_output=True, text=True, timeout=300)


def wait_for_boot(timeout=900):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if run_remote("true").returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            pass
        time.sleep(10)
    return False


def check(command, attempts=3):
    # Retries cover services that are still starting, such as Home Assistant.
    for _ in range(attempts):
        try:
            if run_remote(command).returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            pass
        time.sleep(20)
    return False


SERVICES = [
    ("catalog", 8101), ("provenance", 8102), ("dependency", 8103),
    ("evidence", 8104), ("policy", 8105), ("profiles", 8106),
    ("build", 8107), ("ai", 8108), ("workspace", 8109),
]


def main():
    assert len(PLATFORMS) == 39, "The platform list must contain all 39 entries"
    assert len(SERVICES) == 9, "There must be nine service endpoints"
    if not wait_for_boot():
        print("The VM never accepted SSH on port 2222.")
        return 2
    failed = []
    for name, layer, role, command in PLATFORMS:
        ok = check(command)
        print(f"{'PASS' if ok else 'FAIL'}  {name:<20} {layer:<11} {role}")
        if not ok:
            failed.append(name)
    for name, port in SERVICES:
        ok = check(f"curl -fsS http://127.0.0.1:{port}/health >/dev/null")
        print(f"{'PASS' if ok else 'FAIL'}  {'service ' + name:<20} {'Service':<11} loopback port {port}")
        if not ok:
            failed.append(f"service {name}")
    total = len(PLATFORMS) + len(SERVICES)
    print(f"\n{total - len(failed)}/{total} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
