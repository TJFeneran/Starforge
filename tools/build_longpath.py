import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rifle_asset_builder import build
build('longpath')
