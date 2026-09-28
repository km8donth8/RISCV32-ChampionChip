#!/usr/bin/env python3
"""
vcd2png.py - minimal VCD waveform renderer (matplotlib) for report figures.

    from vcd2png import load, plot
    sigs = load("x.vcd", ["tb.clk", "tb.dut.bus[7:0]"])
    plot(sigs, [(label, name, "bit"|"bus"|"clk", fmt), ...], t0_ns, t1_ns, "out.png", title)
"""
import re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load(path, wanted):
    """Return {full_name: (width, [(t_ps, value_str), ...])} for wanted names."""
    wanted = set(wanted)
    idmap, widths, scope = {}, {}, []
    data = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("$scope"):
                scope.append(line.split()[2])
            elif line.startswith("$upscope"):
                scope.pop()
            elif line.startswith("$var"):
                p = line.split()
                width, vid, name = int(p[2]), p[3], p[4]
                full = ".".join(scope + [name])
                if full in wanted:
                    idmap.setdefault(vid, []).append(full)
                    widths[full] = width
                    data[full] = []
            elif line.startswith("$enddefinitions"):
                break
        t = 0
        for line in f:
            if not line or line[0] == "$":
                continue
            c = line[0]
            if c == "#":
                t = int(line[1:])
            elif c in "01xzXZ":
                vid = line[1:].strip()
                for n in idmap.get(vid, ()):
                    data[n].append((t, c.lower()))
            elif c in "bB":
                val, vid = line[1:].split()
                for n in idmap.get(vid, ()):
                    data[n].append((t, val.lower()))
    missing = wanted - set(data)
    if missing:
        raise SystemExit(f"signals not found in VCD: {sorted(missing)}")
    return {n: (widths[n], v) for n, v in data.items()}


def _val_at(changes, t):
    v = "x"
    for tc, vc in changes:
        if tc > t:
            break
        v = vc
    return v


def _window(changes, t0, t1):
    out = [(t0, _val_at(changes, t0))]
    out += [(t, v) for t, v in changes if t0 < t < t1]
    out.append((t1, out[-1][1]))
    return out


def _fmt(v, width, fmt):
    if "x" in v or "z" in v:
        return "x"
    n = int(v, 2)
    if fmt == "dec":
        return str(n)
    return f"{n:0{(width + 3) // 4}X}"


def plot(sigs, rows, t0_ns, t1_ns, out, title="", unit="us", figw=15, label_min=0.028, rel=False):
    t0, t1 = int(t0_ns * 1000), int(t1_ns * 1000)
    scale = {"us": 1e-6, "ns": 1e-3}[unit]
    n = len(rows)
    fig, ax = plt.subplots(figsize=(figw, 0.52 * n + 1.3))
    off = t0 * scale if rel else 0.0
    ax.set_xlim(t0 * scale - off, t1 * scale - off)
    ax.set_ylim(-0.6, n - 0.2)
    ax.set_yticks(range(n))
    ax.set_yticklabels([r[0] for r in reversed(rows)], fontsize=9, family="monospace")
    ax.set_xlabel(f"time ({'µs' if unit == 'us' else 'ns'})" + (f" from t = {t0/1e6:.3f} µs" if rel else ""))
    ax.grid(axis="x", color="#dddddd", lw=0.6)
    span = (t1 - t0) * scale
    for i, (label, name, kind, fmt) in enumerate(rows):
        y = n - 1 - i
        width, ch = sigs[name]
        w = _window(ch, t0, t1)
        if kind == "clk" and len(w) > 400:
            ax.fill_between([t0 * scale - off, t1 * scale - off], y - 0.3, y + 0.3, color="#9ecae1", step="pre")
            ax.text((t0 + t1) / 2 * scale - off, y, "clock (50 MHz)", ha="center", va="center", fontsize=8)
            continue
        if kind in ("bit", "clk"):
            xs, ys = [], []
            for (ta, va), (tb, _) in zip(w, w[1:]):
                lv = {"1": 0.3, "0": -0.3}.get(va, 0.0)
                xs += [ta * scale - off, tb * scale - off]
                ys += [y + lv, y + lv]
            ax.plot(xs, ys, color="#1f5f99", lw=1.2, drawstyle="default")
        else:
            for (ta, va), (tb, _) in zip(w, w[1:]):
                xa, xb = ta * scale - off, tb * scale - off
                d = min((xb - xa) * 0.15, span * 0.004)
                col = "#d62728" if "x" in va else "#2a7a2a"
                ax.plot([xa, xa + d, xb - d, xb, xb - d, xa + d, xa],
                        [y, y + 0.3, y + 0.3, y, y - 0.3, y - 0.3, y], color=col, lw=1.0)
                if (xb - xa) > span * label_min:
                    ax.text((xa + xb) / 2, y, _fmt(va, width, fmt), ha="center", va="center",
                            fontsize=7.5, family="monospace")
    ax.set_title(title, fontsize=11, loc="left")
    fig.tight_layout()
    fig.savefig(out, dpi=140)
    plt.close(fig)
    print("wrote", out)
