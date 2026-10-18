#!/usr/bin/env python3
"""Startet Host + Clients als echte Godot-Prozesse (localhost) und wertet die Ergebnisse aus.

Beispiele:
  python3 tests/run_net_test.py --players 3
  python3 tests/run_net_test.py --players 5 --down-at 25
  python3 tests/run_net_test.py --players 3 --rejoin
Godot-Pfad: Umgebungsvariable GODOT oder --godot.
"""
import argparse, os, re, subprocess, sys, time, tempfile

WEAPONS = ["sword", "bow", "staff", "axe", "dagger", "hammer"]
NAMES = ["Anna", "Bea", "Cem", "Dora", "Emil"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--players", type=int, default=3)
    ap.add_argument("--port", type=int, default=24777)
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--down-at", type=int, default=-1)
    ap.add_argument("--rejoin", action="store_true", help="erster Client trennt sich im Run und steigt wieder ein")
    ap.add_argument("--scale", default="2.0")
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()
    project = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    tmp = tempfile.mkdtemp(prefix="nettest_")

    def start(args, log):
        f = open(os.path.join(tmp, log), "w")
        cmd = [a.godot, "--headless", "--path", project, "res://tests/net_peer.tscn", "--"] + args
        return subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT), f

    procs = {}
    host_args = ["role=host", f"total={a.players}", f"port={a.port}", f"scale={a.scale}", "name=Host"]
    if a.down_at >= 0:
        host_args.append(f"down_at={a.down_at}")
    procs["host"] = start(host_args, "host.log")
    time.sleep(3)
    for i in range(a.players - 1):
        args = ["role=client", f"name={NAMES[i]}", f"weapon={WEAPONS[(i + 1) % len(WEAPONS)]}", f"port={a.port}", f"scale={a.scale}", f"token=tok{i}"]
        if a.rejoin and i == 0:
            args.append("drop_at=30")
        procs[NAMES[i]] = start(args, NAMES[i] + ".log")
        time.sleep(1)
    rejoined = False
    t0 = time.time()
    while time.time() - t0 < a.timeout:
        if a.rejoin and not rejoined and procs[NAMES[0]][0].poll() == 77:
            time.sleep(3)
            args = ["role=client", f"name={NAMES[0]}", f"weapon={WEAPONS[1]}", f"port={a.port}", f"scale={a.scale}", "token=tok0"]
            procs[NAMES[0] + "_2"] = start(args, NAMES[0] + "_2.log")
            rejoined = True
            print("Client", NAMES[0], "neu gestartet (Wiederbeitritt)")
        if all(p.poll() is not None for p, _ in procs.values()):
            break
        time.sleep(1)
    for p, _ in procs.values():
        if p.poll() is None:
            p.kill()
    failed = False
    for name, (p, f) in procs.items():
        f.close()
        txt = open(os.path.join(tmp, name + ".log"), errors="ignore").read()
        print(f"\n===== {name} (Exit {p.returncode}) =====")
        for line in txt.splitlines():
            if line.startswith(("NETPEER", "NETREPORT", "NETRESULT")) or "SCRIPT ERROR" in line:
                print(line)
        expected_ok = (p.returncode == 0) or (name == NAMES[0] and a.rejoin and p.returncode == 77)
        if not expected_ok or "SCRIPT ERROR" in txt:
            failed = True
    # Sync-Vergleich: Gegnerzahl Host vs. Client je Spielsekunde
    def samples(name):
        d = {}
        for m in re.finditer(r"NETSAMPLE (\d+) (\d+)", open(os.path.join(tmp, name + ".log"), errors="ignore").read()):
            d[int(m.group(1))] = int(m.group(2))
        return d
    h = samples("host")
    cname = NAMES[1] if a.players > 2 else NAMES[0]
    c = samples(cname)
    common = [t for t in h if t in c]
    if common:
        diffs = [abs(h[t] - c[t]) for t in common]
        print(f"\nSync Gegneranzahl Host/Client ({cname}): {len(common)} Messpunkte, mittlere Abweichung {sum(diffs)/len(diffs):.2f}, max {max(diffs)}")
    print("\nLogs:", tmp)
    print("GESAMT:", "FEHLGESCHLAGEN" if failed else "BESTANDEN")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
