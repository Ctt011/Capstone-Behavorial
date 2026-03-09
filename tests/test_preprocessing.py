"""
Tests for preprocess_wise.py — Single source of truth for WISE data preprocessing.

Validates:
  - Data loading and shape
  - Feature columns present
  - No unexpected NaN in critical columns
  - Subject count and activity type labels
  - Window size and overlap configuration
"""

import sys
import os
import pytest
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "pipeline"))

# Skip all tests in this module if the 22subjects directory doesn't exist
# (CI environments or machines without the dataset)
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "22_subjects")
pytestmark = pytest.mark.skipif(
    not os.path.isdir(DATA_DIR),
    reason="WISE dataset (22subjects/) not available"
)


# ── Constants Tests ──────────────────────────────────────────────────────────

class TestConstants:
    """Verify preprocessing constants match the project's specification."""

    def test_window_size(self):
        from preprocess_wise import WINDOW_SIZE_SEC
        assert WINDOW_SIZE_SEC == 30

    def test_window_overlap(self):
        from preprocess_wise import WINDOW_OVERLAP
        assert WINDOW_OVERLAP == 0.5

    def test_apple_watch_features_defined(self):
        from preprocess_wise import APPLE_WATCH_FEATURES
        assert 'HR_mean' in APPLE_WATCH_FEATURES
        assert 'ACC_mean' in APPLE_WATCH_FEATURES


# ── df_activity Tests (Stage 1 data) ─────────────────────────────────────────

class TestDfActivity:
    """Validate the df_activity DataFrame used for Stage 1 classification."""

    def test_df_activity_not_empty(self):
        from preprocess_wise import df_activity
        assert len(df_activity) > 0

    def test_has_required_feature_columns(self):
        from preprocess_wise import df_activity
        for col in ['HR_mean', 'HR_std', 'ACC_mean', 'ACC_std']:
            assert col in df_activity.columns, f"Missing column: {col}"

    def test_has_subject_column(self):
        from preprocess_wise import df_activity
        assert 'subject' in df_activity.columns

    def test_has_activity_type_column(self):
        from preprocess_wise import df_activity
        assert 'activity_type' in df_activity.columns

    def test_activity_types_are_valid(self):
        from preprocess_wise import df_activity
        valid = {'COGNITIVE', 'AEROBIC', 'ANAEROBIC', 'STRESS', 'REST'}
        actual = set(df_activity['activity_type'].unique())
        assert actual.issubset(valid), f"Unexpected activity types: {actual - valid}"

    def test_at_least_20_subjects(self):
        from preprocess_wise import df_activity
        assert df_activity['subject'].nunique() >= 20

    def test_no_nan_in_subject_column(self):
        from preprocess_wise import df_activity
        assert df_activity['subject'].isna().sum() == 0

    def test_feature_values_are_numeric(self):
        from preprocess_wise import df_activity
        for col in ['HR_mean', 'HR_std', 'ACC_mean', 'ACC_std']:
            assert np.issubdtype(df_activity[col].dtype, np.number), \
                f"{col} is not numeric: {df_activity[col].dtype}"

    def test_window_count_reasonable(self):
        """Should have >2000 windows (paper reports 2449)."""
        from preprocess_wise import df_activity
        assert len(df_activity) > 2000


# ── df_features Tests (Stage 2/3 stress data) ────────────────────────────────

class TestDfFeatures:
    """Validate the df_features DataFrame used for stress regression."""

    def test_df_features_not_empty(self):
        from preprocess_wise import df_features
        assert len(df_features) > 0

    def test_has_label_column(self):
        from preprocess_wise import df_features
        assert 'label' in df_features.columns or 'stress_label' in df_features.columns


# ── Helper Function Tests ────────────────────────────────────────────────────

class TestHelpers:
    """Test utility functions in preprocess_wise.py."""

    def test_moving_average_returns_list(self):
        from preprocess_wise import moving_average
        # Fake 3-axis ACC data: 96 samples (3 windows of 32)
        acc = np.random.randn(96, 3)
        result = moving_average(acc)
        assert isinstance(result, list)
        assert len(result) == 3  # 96 / 32 = 3 windows

    def test_create_df_array_flattens(self):
        import pandas as pd
        from preprocess_wise import create_df_array
        df = pd.DataFrame({'a': [1, 2], 'b': [3, 4]})
        result = create_df_array(df)
        assert len(result) == 4
