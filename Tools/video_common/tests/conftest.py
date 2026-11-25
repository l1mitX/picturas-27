import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(TOOLS_DIR))
