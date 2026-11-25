import sys
from pathlib import Path

# The measurement scripts live one folder up (docs/fase2/medicoes/).
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
