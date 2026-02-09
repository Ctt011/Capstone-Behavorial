# main.py
"""
Entry point for running our capstone analysis on DSMLP.

This script executes the main analysis notebook:
    WISE_Stress_EDA.ipynb
and saves an executed copy as:
    WISE_Stress_EDA_executed.ipynb
"""

import nbformat
from nbconvert.preprocessors import ExecutePreprocessor
from pathlib import Path


def run_notebook(input_path: str, output_path: str, timeout: int = 1200) -> None:
    """Execute a Jupyter notebook and save the executed version."""
    input_path = Path(input_path)
    output_path = Path(output_path)

    with input_path.open("r", encoding="utf-8") as f:
        nb = nbformat.read(f, as_version=4)

    ep = ExecutePreprocessor(timeout=timeout, kernel_name="python3")
    ep.preprocess(nb, {"metadata": {"path": str(input_path.parent)}})

    with output_path.open("w", encoding="utf-8") as f:
        nbformat.write(nb, f)

    print(f"Executed notebook saved to: {output_path}")


if __name__ == "__main__":
    run_notebook("notebooks/WISE_Stress_EDA_Model.ipynb", "notebooks/WISE_Stress_EDA_Model_executed.ipynb")
