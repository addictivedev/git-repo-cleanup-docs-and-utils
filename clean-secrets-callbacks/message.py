import os
import datetime

# Log callback execution
def log_callback(message):
    timestamp = datetime.datetime.now().isoformat()
    try:
        with open(os.environ["CALLBACK_LOG"], "a") as f:
            f.write(f"[{timestamp}] MESSAGE: {message}\n")
    except Exception:
        pass  # Ignore logging errors

log_callback("Processing commit message")

if b"SECRET" in message:
    log_callback("Found 'SECRET' in commit message, redacting...")
    redacted_message = message.replace(b"SECRET", b"[REDACTED]")
    log_callback("Commit message redacted successfully")
    return redacted_message

log_callback("No 'SECRET' found in commit message, returning unchanged")
return message