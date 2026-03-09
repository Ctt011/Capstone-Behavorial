"""
Tests for Stage 2: Sleep-Based Threshold Adjustment (stage2_sleep_rules.py)

Validates:
  - Sleep quality classification boundaries
  - Threshold multiplier correctness
  - Baseline learning (rolling average after 7+ nights)
  - Edge cases (zero sleep, negative values)
"""

import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "pipeline"))
from stage2_sleep_rules import (
    SleepQualityAssessor,
    SleepAssessment,
    BASE_STRESS_THRESHOLD,
    morning_adjustment,
)


# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def assessor():
    """Fresh assessor with default 7.0h baseline."""
    return SleepQualityAssessor(default_baseline_hours=7.0)


@pytest.fixture
def trained_assessor():
    """Assessor with 7 nights of data (baseline established)."""
    a = SleepQualityAssessor()
    for h in [7.2, 6.8, 7.5, 7.0, 6.5, 7.3, 7.1]:
        a.record_sleep(h)
    return a


# ── Sleep Quality Classification Tests ───────────────────────────────────────

class TestSleepQualityClassification:
    """Verify that sleep hours map to the correct quality labels."""

    def test_very_poor_sleep(self, assessor):
        result = assessor.get_threshold_adjustment(4.0)
        assert result.quality == "very_poor"
        assert result.threshold_multiplier == 0.80

    def test_poor_sleep(self, assessor):
        result = assessor.get_threshold_adjustment(5.5)
        assert result.quality == "poor"
        assert result.threshold_multiplier == 0.85

    def test_normal_sleep(self, assessor):
        result = assessor.get_threshold_adjustment(7.0)
        assert result.quality == "normal"
        assert result.threshold_multiplier == 1.00

    def test_good_sleep(self, assessor):
        result = assessor.get_threshold_adjustment(8.0)
        assert result.quality == "good"
        assert result.threshold_multiplier == 1.05

    def test_excellent_sleep(self, assessor):
        result = assessor.get_threshold_adjustment(9.0)
        assert result.quality == "excellent"
        assert result.threshold_multiplier == 1.08


# ── Threshold Adjustment Tests ───────────────────────────────────────────────

class TestThresholdAdjustment:
    """Verify adjusted threshold values are correct."""

    def test_base_threshold_is_60(self):
        assert BASE_STRESS_THRESHOLD == 60

    def test_very_poor_lowers_threshold(self, assessor):
        result = assessor.get_threshold_adjustment(4.0)
        assert result.adjusted_threshold == int(60 * 0.80)  # 48

    def test_normal_keeps_baseline(self, assessor):
        result = assessor.get_threshold_adjustment(7.0)
        assert result.adjusted_threshold == 60

    def test_excellent_raises_threshold(self, assessor):
        result = assessor.get_threshold_adjustment(9.0)
        assert result.adjusted_threshold == int(60 * 1.08)  # 64

    def test_threshold_is_integer(self, assessor):
        result = assessor.get_threshold_adjustment(5.5)
        assert isinstance(result.adjusted_threshold, int)


# ── Baseline Learning Tests ──────────────────────────────────────────────────

class TestBaselineLearning:
    """Verify the rolling personal baseline works correctly."""

    def test_default_baseline_before_7_nights(self, assessor):
        assessor.record_sleep(8.0)
        assessor.record_sleep(7.5)
        assert assessor.sleep_baseline == 7.0  # still default

    def test_personal_baseline_after_7_nights(self, trained_assessor):
        expected = sum([7.2, 6.8, 7.5, 7.0, 6.5, 7.3, 7.1]) / 7
        assert abs(trained_assessor.sleep_baseline - expected) < 0.01

    def test_baseline_caps_at_30_nights(self):
        a = SleepQualityAssessor()
        for i in range(40):
            a.record_sleep(7.0 + (i * 0.01))
        assert len(a._sleep_history) == 30

    def test_zero_sleep_not_recorded(self, assessor):
        assessor.record_sleep(0)
        assert len(assessor._sleep_history) == 0

    def test_negative_sleep_not_recorded(self, assessor):
        assessor.record_sleep(-1.0)
        assert len(assessor._sleep_history) == 0


# ── Edge Cases ───────────────────────────────────────────────────────────────

class TestEdgeCases:
    """Test boundary conditions and edge cases."""

    def test_zero_baseline_returns_unknown(self):
        a = SleepQualityAssessor(default_baseline_hours=0.0)
        result = a.get_threshold_adjustment(7.0)
        assert result.quality == "unknown"
        assert result.threshold_multiplier == 1.0

    def test_assessment_returns_dataclass(self, assessor):
        result = assessor.get_threshold_adjustment(7.0)
        assert isinstance(result, SleepAssessment)

    def test_message_is_nonempty_string(self, assessor):
        result = assessor.get_threshold_adjustment(7.0)
        assert isinstance(result.message, str)
        assert len(result.message) > 0

    def test_sleep_ratio_correct(self, assessor):
        result = assessor.get_threshold_adjustment(3.5)
        assert abs(result.sleep_ratio - 0.5) < 0.01  # 3.5 / 7.0 = 0.5


# ── Integration Helper Tests ─────────────────────────────────────────────────

class TestMorningAdjustment:
    """Test the morning_adjustment() convenience function."""

    def test_returns_dict(self):
        result = morning_adjustment(7.0)
        assert isinstance(result, dict)

    def test_dict_has_required_keys(self):
        result = morning_adjustment(7.0)
        for key in ['sleep_hours', 'quality', 'adjusted_threshold',
                     'threshold_multiplier', 'message']:
            assert key in result

    def test_with_custom_assessor(self, trained_assessor):
        result = morning_adjustment(5.0, assessor=trained_assessor)
        assert result['quality'] in ('very_poor', 'poor')
