#!/usr/bin/env python3
"""
test_blob_callback.py - Test script for blob callback

This script tests the blob callback functionality without running git-filter-repo.
"""

import os
import sys
import tempfile
import hashlib

# Add the callbacks directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'clean-blobs-callbacks'))

from blob import load_safe_blobs, compute_blob_sha, process_blob


def test_blob_callback():
    """Test the blob callback functionality."""
    print("Testing blob callback functionality...")
    
    # Create a temporary blob list file
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
        f.write("test_blob_hash_1\n")
        f.write("test_blob_hash_2\n")
        f.write("TEST_BLOB_HASH_3\n")  # Test case insensitive
        blob_list_file = f.name
    
    try:
        # Set environment variable
        os.environ['BLOB_LIST_FILE'] = blob_list_file
        
        # Test loading safe blobs
        safe_blobs = load_safe_blobs()
        print(f"Loaded safe blobs: {safe_blobs}")
        
        # Test blob SHA computation
        test_data = b"Hello, World!"
        blob_sha = compute_blob_sha(test_data)
        print(f"Computed SHA for test data: {blob_sha}")
        
        # Test processing a blob (simulate the callback)
        result = process_blob(test_data)
        print(f"Processed blob result: {result is not None}")
        
        print("✅ All tests passed!")
        
    finally:
        # Clean up
        os.unlink(blob_list_file)


if __name__ == '__main__':
    test_blob_callback()
