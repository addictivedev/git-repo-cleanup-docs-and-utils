import os
import json
import datetime

# Log callback execution
def log_callback(message):
    timestamp = datetime.datetime.now().isoformat()
    try:
        with open(os.environ["CALLBACK_LOG"], "a") as f:
            f.write(f"[{timestamp}] FILE_INFO: {message}\n")
    except Exception:
        pass  # Ignore logging errors

# === Memoize Gitleaks secrets once ===
if "bad_lines" not in globals():
    bad_lines = set()
    with open(os.environ["GITLEAKS_FILE"]) as f:
        for e in json.load(f):
            key = (e["File"], e["StartLine"])
            bad_lines.add(key)
    log_callback(f"Loaded {len(bad_lines)} secret locations from gitleaks file")

# === Decode the filename ===
decoded_filename = filename.decode("utf-8", errors="ignore")
log_callback(f"Processing file: {decoded_filename}")

# === Check if this file has a line to remove ===
has_secret = any(f == decoded_filename for (f, _) in bad_lines)

if not has_secret:
    # No secret in this file: return as-is
    log_callback(f"No secrets found in {decoded_filename}, returning unchanged")
    return (filename, mode, blob_id)

log_callback(f"Found secrets in {decoded_filename}, processing...")

# === Load the file content from the blob ===
contents = value.get_contents_by_identifier(blob_id)
lines = contents.decode("utf-8", errors="ignore").splitlines()
original_line_count = len(lines)

# === Clean specific lines from this file ===
lines_modified = 0
for (f, lnum) in list(bad_lines):
    if f == decoded_filename and 0 < lnum <= len(lines):
        lines[lnum - 1] = ""  # remove the line
        lines_modified += 1
        log_callback(f"Removed secret from line {lnum} in {decoded_filename}")

# === Re-encode and write new blob ===
new_contents = "\n".join(lines).encode("utf-8") + b"\n"
new_blob_id = value.insert_file_with_contents(new_contents)

log_callback(f"Modified {lines_modified} lines in {decoded_filename} (original: {original_line_count} lines)")

# === Return modified blob; filename and mode unchanged ===
return (filename, mode, new_blob_id)