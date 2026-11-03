#!/usr/bin/env python3
"""
WorkoutTracker Comprehensive Performance & Stability Profiler
Simulates tab navigation, measures CPU/RAM/delays, captures hang logs & crash dumps.
"""

import subprocess
import time
import json
import os
import sys

UDID = "B9FCA6FD-3147-4765-9D74-53FFD5E33FD8"
BUNDLE_ID = "com.borisdev.WorkoutTracker"

def run_cmd(cmd, check=True):
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        print(f"Command failed: {cmd}\nStderr: {res.stderr}")
    return res

def get_app_pid():
    res = run_cmd(f"pgrep -f '{BUNDLE_ID}'", check=False)
    pids = res.stdout.strip().split()
    if pids:
        return pids[0]
    return None

def get_process_metrics(pid):
    if not pid:
        return {"cpu": 0.0, "rss_mb": 0.0, "threads": 0}
    res = run_cmd(f"ps -o %cpu,rss -p {pid}", check=False)
    lines = res.stdout.strip().split("\n")
    if len(lines) > 1:
        parts = lines[1].split()
        if len(parts) >= 2:
            try:
                cpu = float(parts[0])
                rss_mb = float(parts[1]) / 1024.0
                return {"cpu": cpu, "rss_mb": round(rss_mb, 2)}
            except Exception:
                pass
    return {"cpu": 0.0, "rss_mb": 0.0}

def switch_tab(tab_index):
    url = f"workouttracker://tab?index={tab_index}"
    start = time.perf_counter()
    run_cmd(f'xcrun simctl openurl {UDID} "{url}"')
    duration_ms = (time.perf_counter() - start) * 1000.0
    return duration_ms

def check_crashes_since(start_timestamp):
    diag_dir = os.path.expanduser("~/Library/Logs/DiagnosticReports")
    if not os.path.exists(diag_dir):
        return []
    crashes = []
    for f in os.listdir(diag_dir):
        if "WorkoutTracker" in f and f.endswith(".ips"):
            path = os.path.join(diag_dir, f)
            mtime = os.path.getmtime(path)
            if mtime >= start_timestamp - 5:
                crashes.append(f)
    return crashes

def capture_recent_logs(seconds=60):
    cmd = f'xcrun simctl spawn {UDID} log show --predicate \'processImagePath contains "WorkoutTracker" AND (messageType == error OR messageType == fault OR eventMessage contains[c] "error" OR eventMessage contains[c] "fault" OR eventMessage contains[c] "hang" OR eventMessage contains[c] "lag")\' --last {seconds}s'
    res = run_cmd(cmd, check=False)
    return res.stdout

def run_stress_test(cycles=3):
    print("=== [1] Ensuring WorkoutTracker is running ===")
    run_cmd(f"xcrun simctl launch {UDID} {BUNDLE_ID}", check=False)
    time.sleep(2)
    pid = get_app_pid()
    print(f"App PID: {pid}")

    test_start_time = time.time()
    tab_names = ["Overview", "History", "Workout", "AI Hub", "Progress"]
    timings = {name: [] for name in tab_names}
    memory_progression = []

    print("\n=== [2] Starting Tab Transition Stress Test ===")
    for cycle in range(1, cycles + 1):
        print(f"--- Cycle {cycle}/{cycles} ---")
        for idx, name in enumerate(tab_names):
            duration = switch_tab(idx)
            time.sleep(0.4) # realistic user pause
            metrics = get_process_metrics(pid)
            timings[name].append(round(duration, 2))
            memory_progression.append((f"C{cycle}_{name}", metrics["rss_mb"], metrics["cpu"]))
            print(f"  Tab [{idx}] {name:<10}: dispatch {duration:.1f}ms | RSS: {metrics['rss_mb']}MB | CPU: {metrics['cpu']}%")

    print("\n=== [3] Checking for System Crashes & Hangs ===")
    crashes = check_crashes_since(test_start_time)
    if crashes:
        print(f"CRASH DUMPS FOUND ({len(crashes)}): {crashes}")
    else:
        print("No new crash dumps generated in DiagnosticReports.")

    print("\n=== [4] Capturing Error & Fault System Logs ===")
    logs = capture_recent_logs(seconds=45)
    log_lines = [l for l in logs.split("\n") if l.strip() and not "Filtered" in l]
    print(f"Total error/fault log entries: {len(log_lines)}")
    if log_lines:
        print("Sample of error/fault logs:")
        for l in log_lines[:15]:
            print("  ", l[:140])

    print("\n=== [5] Stress Summary ===")
    for name in tab_names:
        times = timings[name]
        avg = sum(times) / len(times) if times else 0
        print(f"  {name:<10}: avg dispatch {avg:.1f}ms (min {min(times):.1f}ms, max {max(times):.1f}ms)")
    if memory_progression:
        start_mem = memory_progression[0][1]
        end_mem = memory_progression[-1][1]
        print(f"  RAM delta: {start_mem}MB -> {end_mem}MB (diff: {round(end_mem - start_mem, 2)}MB)")

if __name__ == "__main__":
    run_stress_test(cycles=3)
