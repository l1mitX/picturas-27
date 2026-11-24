import sys
from pathlib import Path

# Make the service modules (policy.py, autoscaler.py) importable as top-level modules,
# both on the host and inside the container (/app).
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
