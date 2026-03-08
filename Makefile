.PHONY: test test-quick test-all install lint clean

# Run all tests (skips preprocessing tests if dataset not present)
test:
	pytest tests/ -v --tb=short

# Run only Stage 2 + Stage 3 tests (no dataset needed)
test-quick:
	pytest tests/test_stage2_sleep_rules.py tests/test_stage3_stress_formulas.py -v --tb=short

# Run all tests including preprocessing (requires 22subjects/ data)
test-all:
	pytest tests/ -v --tb=long

# Install dependencies
install:
	pip install -r requirements.txt

# Reproduce Stage 1 LOSO evaluation
evaluate:
	python run_evaluation.py --save results/loso_evaluation.txt

# Export trained models
export-model:
	python export_stage1_model.py

# Clean generated files
clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	find . -name "*.pyc" -delete
