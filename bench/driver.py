#!/usr/bin/env python3
"""Drive the running `minion` tmux session with an approval POLICY and caps.

Usage: drive_minion.py <session> <outfile> <idle_s> <max_s> <policy> <cap> <<<"prompt"
  policy = act1  -> approve reads/list/grep, DENY edit/write/run (keep comprehension)
           act2  -> approve everything (the edit + pytest teaching beat)
  cap    = hard limit on prompts answered before we stop (runaway guard)
"""
import subprocess, sys, time, hashlib

SESSION, OUT, IDLE, MAXS, POLICY, CAP = (
    sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]),
    sys.argv[5], int(sys.argv[6]))
PROMPT = sys.stdin.read().rstrip("\n")

DENY_WORDS = ("edit", "write", "run:", "run ", "delete", "remove", "rm ",
              "mkdir", "touch", "append", "move", " mv ", "chmod")

def tmux(*a): return subprocess.run(["tmux", *a], capture_output=True, text=True).stdout
def vis():    return tmux("capture-pane", "-t", SESSION, "-p")
def full():   return tmux("capture-pane", "-t", SESSION, "-p", "-S", "-")

def approval_line(pane):
    # Only a LIVE prompt: the most-recent [Y/n/esc] line with nothing typed after
    # it. Once answered, minion echoes "[Y/n/esc] Y", so rest != "" -> skip.
    for ln in reversed(pane.splitlines()):
        i = ln.rfind("[Y/n/esc]")
        if i != -1:
            rest = ln[i + len("[Y/n/esc]"):].strip()
            return ln.lower() if rest == "" else None
    return None

tmux("send-keys", "-t", SESSION, "-l", PROMPT)
time.sleep(0.5)
tmux("send-keys", "-t", SESSION, "Enter")

start = time.time()
last_hash, last_change = None, time.time()
answered, last_ans_t = 0, 0.0
while True:
    now = time.time()
    if now - start > MAXS:
        print(f"[driver] MAX timeout {MAXS}s", file=sys.stderr); break
    if answered >= CAP:
        print(f"[driver] approval CAP {CAP} hit -> stopping (sending Esc)", file=sys.stderr)
        tmux("send-keys", "-t", SESSION, "Escape"); time.sleep(2); break
    pane = vis()
    aline = approval_line(pane)
    if aline and (now - last_ans_t) > 2.0:
        deny = (POLICY == "act1") and any(w in aline for w in DENY_WORDS)
        key = "n" if deny else "y"
        tmux("send-keys", "-t", SESSION, "-l", key)
        answered += 1; last_ans_t = now; last_change = now
        print(f"[driver] {'DENY' if deny else 'allow'} #{answered}: {aline.strip()[:90]}", file=sys.stderr)
        time.sleep(1.0); continue
    h = hashlib.md5(pane.encode()).hexdigest()
    if h != last_hash:
        last_hash = h; last_change = now
    if (now - last_change) >= IDLE and "0 chars" in pane and "tok/s" in pane and "[Y/n/esc]" not in pane:
        print(f"[driver] idle -> done. answered={answered}", file=sys.stderr); break
    time.sleep(2.0)

with open(OUT, "w") as f:
    f.write(full())
print(f"[driver] wrote {OUT}; answered={answered}; elapsed={time.time()-start:.0f}s", file=sys.stderr)
