"""Auto-configure paths when running notebooks from the notebooks/ subdirectory."""
import os, sys
_repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(_repo_root)
sys.path.insert(0, _repo_root)
