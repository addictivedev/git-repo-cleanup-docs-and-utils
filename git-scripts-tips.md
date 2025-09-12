# 🗂️ Find Large, Unreachable Blobs in a Git Repository

This guide explains how to find blobs (file contents) in a Git repository that are:
1. **Unreachable** – not referenced by any branch or tag
2. **Large** – bigger than a specified size, e.g., 10,000 bytes

This is essential for cleaning up old, deleted files that still take up space in your `.git` folder.

## The Final Command

```bash
comm -23 \
  <(git cat-file --batch-check --batch-all-objects \
      | awk '$2=="blob"{print $1, $3}' \
      | sort -u) \
  <(git rev-list --objects --all \
      | awk '{print $1}' \
      | git cat-file --batch-check='%(objecttype) %(objectname)' \
      | awk '$1=="blob"{print $2}' \
      | sort -u) \
| awk '$2 > 10000'
```

## How It Works

Let's break it into steps:

### 1. List ALL blobs (including dangling)

```bash
git cat-file --batch-check --batch-all-objects
```

**Output format:**
```
<SHA> <TYPE> <SIZE>
```

**Example:**
```
fd13527c35c99d7bd0c855a6d8be2220f8188fda blob 10344
49b5b1602a7e0ed639004ddd03c1dd9cca1c5bfe commit 242
cddc1056a17af18d47fcf316d6e42aaa05925e86 tree 35
```

We only want blobs, so filter with awk:

```bash
git cat-file --batch-check --batch-all-objects | awk '$2=="blob"{print $1, $3}'
```

**Example result:**
```
fd13527c35c99d7bd0c855a6d8be2220f8188fda 10344
cafebabef00d1234567890abcd1234567890abcd 25000
```

- `$1` = SHA (unique identifier for the blob)
- `$3` = Size in bytes

### 2. List only reachable blobs

```bash
git rev-list --objects --all
```

**Example:**
```
f3d3cbb3dd70b64ed4274530574dadbca9a78d08 README.md
9e8dee82045dba0a6d38fdabf4749f132d2ca909 src/main.py
```

We need only the SHA:

```bash
git rev-list --objects --all | awk '{print $1}'
```

Now check the object type to keep only blobs:

```bash
git rev-list --objects --all \
  | awk '{print $1}' \
  | git cat-file --batch-check='%(objecttype) %(objectname)' \
  | awk '$1=="blob"{print $2}'
```

**Result:**
```
fd13527c35c99d7bd0c855a6d8be2220f8188fda
cafebabef00d1234567890abcd1234567890abcd
```

### 3. Subtract reachable from all blobs

We now have two sorted lists:

| File | Contents |
|------|----------|
| All blobs | SHA size |
| Reachable blobs | SHA |

We subtract them using `comm -23`:

```bash
comm -23 <(all-blobs) <(reachable-blobs)
```

This outputs only unreachable blobs, still showing SHA and size.

### 4. Filter by size (> 10,000 bytes)

Finally, keep only blobs larger than 10 KB:

```bash
awk '$2 > 10000'
```

**Example output:**
```
cafebabef00d1234567890abcd1234567890abcd 25000
deadbeef1234567890abcd1234567890abcd1234 45000
```

| Column | Meaning |
|--------|---------|
| `cafebabef00d1234567890abcd1234567890abcd` | Blob SHA |
| `25000` | Size in bytes |

## Full Data Flow

```mermaid
flowchart LR
    A["git cat-file --batch-all-objects<br/>(All Blobs)"] --> B["awk '$2==\"blob\" {print $1, $3}'"]
    B --> C["sort -u"]

    D["git rev-list --objects --all<br/>(Reachable)"] --> E["awk '{print $1}'"]
    E --> F["git cat-file --batch-check='%(objecttype) %(objectname)'"]
    F --> G["awk '$1==\"blob\" {print $2}'"]
    G --> H["sort -u"]

    C --> I["comm -23"]
    H --> I

    I --> J["awk '$2 > 10000'<br/>(Filter by size)"]
    J --> K["Final List:<br/>Large Unreachable Blobs"]
```

## Verify With Git FSCK

As a sanity check:

```bash
git fsck --unreachable --no-reflogs --full | grep 'unreachable blob'
```

**Example:**
```
unreachable blob deadbeef1234567890abcd1234567890abcd1234
unreachable blob cafebabef00d1234567890abcd1234567890abcd
```

To see their sizes:

```bash
git fsck --unreachable --no-reflogs --full | grep 'unreachable blob' | awk '{print $3}' \
| while read sha; do
    size=$(git cat-file -s "$sha")
    if [ "$size" -gt 10000 ]; then
      echo "$sha $size"
    fi
  done
```

## Cleanup (Careful!)

Once you verify unreachable blobs, you can safely delete them:

```bash
git prune
git gc --prune=now --aggressive
```

⚠️ **Warning:**
- This permanently deletes unreachable objects.
- Ensure you have a backup or remote copy before running this.

## Summary

| Step | Command | Result |
|------|---------|--------|
| All blobs | `git cat-file --batch-check --batch-all-objects \| awk '$2=="blob"{print $1, $3}'` | SHA + size for all blobs |
| Reachable blobs | `git rev-list --objects --all ...` | SHA for blobs still referenced |
| Unreachable blobs | `comm -23` | SHA + size of only unreachable blobs |
| Filter by size | `awk '$2 > 10000'` | Only blobs larger than 10 KB |

## Example Output

```
cafebabef00d1234567890abcd1234567890abcd 25000
deadbeef1234567890abcd1234567890abcd1234 45000
```

Now you have a clean list of large, unreachable blobs, ready for cleanup or analysis. ✅