import os
import json
import datetime

# Memoize total commits and setup globals
if "total_commits" not in globals():
    try:
        with open(os.environ["STATS_FILE"]) as f:
            globals()["total_commits"] = json.load(f).get("total_commits", 0)
    except Exception:
        globals()["total_commits"] = 0

if "seen_hashes" not in globals():
    globals()["seen_hashes"] = set()

# Initialize processed counter for percentage calculation
if "processed_count" not in globals():
    globals()["processed_count"] = 0

commit_hash = commit.original_id.hex()

# Log callback execution
def log_callback(message):
    timestamp = datetime.datetime.now().isoformat()
    try:
        with open(os.environ["CALLBACK_LOG"], "a") as f:
            f.write(f"[{timestamp}] COMMIT: {message}\n")
    except Exception:
        pass  # Ignore logging errors

log_callback(f"Processing commit {commit_hash}")

# Avoid duplicate writes
if commit_hash not in globals()["seen_hashes"]:
    globals()["seen_hashes"].add(commit_hash)
    globals()["processed_count"] += 1
    
    # Calculate percentage
    percentage = (globals()["processed_count"] / globals()["total_commits"]) * 100 if globals()["total_commits"] > 0 else 0
    
    with open(os.environ["PROGRESS_FILE"], "a") as f:
        f.write(f"{commit_hash} {globals()['total_commits']} seen {globals()['processed_count']} processed {percentage:.1f}%\n")
    
    log_callback(f"Added commit {commit_hash} to progress file ({globals()['processed_count']}/{globals()['total_commits']} = {percentage:.1f}%)")
else:
    log_callback(f"Commit {commit_hash} already processed, skipping")