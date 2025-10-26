#!/usr/bin/env python3
from huggingface_hub import snapshot_download

model_id = "cpatonn/GLM-4.5-Air-AWQ-4bit"
local_dir = "/home/ivan/models/GLM-4.5-Air-AWQ"

print(f"Downloading {model_id} to {local_dir}...")
snapshot_download(repo_id=model_id, local_dir=local_dir, local_dir_use_symlinks=False, resume_download=True)
print("✓ Download complete!")
