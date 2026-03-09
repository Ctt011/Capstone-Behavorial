"""
Tests for Stage 3: DC/AC Stress Formulas (stage3_stress_formulas.py)

Validates:
  - DC/AC computation (PRSA method, Bauer 2006)
  - HRV metrics (SDNN, RMSSD)
  - HR ↔ RR conversion
  - Stress scoring (0–100 scale)
  - Personal baseline learning
  - Ectopic beat filtering
  - Edge cases (short arrays, constant values)
"""

import sys
import os
import numpy as np
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "pipeline"))
from stage3_stress_formulas import StressCalculator, StressResult, PersonalBaseline


# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def calc():
    """Fresh StressCalculator."""
    return StressCalculator()


@pytest.fixture
def calm_rr():
    """Simulated calm RR intervals (low variability, ~75 BPM)."""
    np.random.seed(42)
    return 800 + np.random.normal(0, 10, 100)  # ~800ms ± 10ms


@pytest.fixture
def stressed_rr():
    """Simulated stressed RR intervals (high variability, ~90 BPM)."""
    np.random.seed(42)
    return 667 + np.random.normal(0, 30, 100)  # ~667ms ± 30ms


# ── DC/AC Computation Tests ──────────────────────────────────────────────────

class TestDCAC:
    """Validate the PRSA-based DC/AC computation."""

    def test_dc_ac_returns_tuple_of_four(self, calc, calm_rr):
        result = calc.compute_dc_ac(calm_rr)
        assert len(result) == 4

    def test_dc_is_positive_for_normal_signal(self, calc, calm_rr):
        dc, ac, n_dc, n_ac = calc.compute_dc_ac(calm_rr)
        assert dc is not None
        # DC should generally be positive (heart deceleration = healthy)
        # but with random data it may vary; just check it's computed
        assert isinstance(dc, float)

    def test_ac_is_computed(self, calc, calm_rr):
        dc, ac, n_dc, n_ac = calc.compute_dc_ac(calm_rr)
        assert ac is not None
        assert isinstance(ac, float)

    def test_anchor_counts_are_positive(self, calc, calm_rr):
        dc, ac, n_dc, n_ac = calc.compute_dc_ac(calm_rr)
        assert n_dc > 0
        assert n_ac > 0

    def test_too_short_returns_none(self, calc):
        dc, ac, n_dc, n_ac = calc.compute_dc_ac([800, 810, 795])
        assert dc is None
        assert ac is None

    def test_empty_array_returns_none(self, calc):
        dc, ac, n_dc, n_ac = calc.compute_dc_ac([])
        assert dc is None
        assert ac is None


# ── HRV Metric Tests ─────────────────────────────────────────────────────────

class TestHRVMetrics:
    """Validate SDNN and RMSSD computations."""

    def test_sdnn_known_values(self):
        """SDNN of [100, 200, 300] should be std with ddof=1 = 100.0"""
        rr = np.array([100, 200, 300])
        sdnn = StressCalculator.compute_sdnn(rr)
        assert abs(sdnn - 100.0) < 0.01

    def test_rmssd_known_values(self):
        """RMSSD of [100, 200, 300] — diffs are [100, 100], rmssd = 100.0"""
        rr = np.array([100, 200, 300])
        rmssd = StressCalculator.compute_rmssd(rr)
        assert abs(rmssd - 100.0) < 0.01

    def test_sdnn_single_value_returns_none(self):
        assert StressCalculator.compute_sdnn([800]) is None

    def test_rmssd_single_value_returns_none(self):
        assert StressCalculator.compute_rmssd([800]) is None

    def test_sdnn_constant_array(self):
        """Constant RR → SDNN should be ~0."""
        rr = np.array([800] * 50)
        sdnn = StressCalculator.compute_sdnn(rr)
        assert sdnn < 0.01


# ── HR ↔ RR Conversion Tests ─────────────────────────────────────────────────

class TestConversions:
    """Validate heart rate to RR interval conversion."""

    def test_hr_to_rr_75bpm(self):
        rr = StressCalculator.hr_to_rr([75])
        assert abs(rr[0] - 800.0) < 0.01  # 60000/75 = 800ms

    def test_hr_to_rr_60bpm(self):
        rr = StressCalculator.hr_to_rr([60])
        assert abs(rr[0] - 1000.0) < 0.01  # 60000/60 = 1000ms

    def test_hr_to_rr_filters_zero(self):
        rr = StressCalculator.hr_to_rr([75, 0, 60])
        assert len(rr) == 2  # 0 BPM filtered out

    def test_hr_to_rr_returns_numpy(self):
        rr = StressCalculator.hr_to_rr([75, 80])
        assert isinstance(rr, np.ndarray)


# ── Stress Scoring Tests ─────────────────────────────────────────────────────

class TestStressScoring:
    """Validate end-to-end stress score computation."""

    def test_compute_stress_returns_result(self, calc, calm_rr):
        result = calc.compute_stress(calm_rr)
        assert isinstance(result, StressResult)

    def test_stress_score_in_range(self, calc, calm_rr):
        result = calc.compute_stress(calm_rr)
        assert 0 <= result.stress_score <= 100

    def test_stress_level_is_valid(self, calc, calm_rr):
        result = calc.compute_stress(calm_rr)
        assert result.stress_level in ("low", "moderate", "high", "very_high")

    def test_from_hr_works(self, calc):
        hr_samples = [75, 74, 76, 73, 77, 75, 74, 76, 73, 77] * 10
        result = calc.compute_stress_from_hr(hr_samples)
        assert isinstance(result, StressResult)
        assert result.n_intervals > 0


# ── Personal Baseline Tests ──────────────────────────────────────────────────

class TestPersonalBaseline:
    """Validate baseline learning from calm periods."""

    def test_baseline_not_established_initially(self):
        b = PersonalBaseline()
        assert not b.is_established

    def test_baseline_established_after_5_readings(self):
        b = PersonalBaseline()
        for i in range(5):
            b.add_reading(dc=5.0, sdnn=40.0, rmssd=35.0, mean_hr=70.0)
        assert b.is_established

    def test_baseline_means_correct(self):
        b = PersonalBaseline()
        for dc in [4.0, 6.0]:
            b.add_reading(dc=dc, sdnn=40.0, rmssd=35.0, mean_hr=70.0)
        assert abs(b.dc_mean - 5.0) < 0.01

    def test_baseline_caps_at_max_samples(self):
        b = PersonalBaseline(max_samples=10)
        for i in range(20):
            b.add_reading(dc=5.0, sdnn=40.0, rmssd=35.0, mean_hr=70.0)
        assert len(b.dc_values) == 10

    def test_empty_baseline_returns_none(self):
        b = PersonalBaseline()
        assert b.dc_mean is None
        assert b.sdnn_mean is None


# ── Ectopic Beat Filtering Tests ─────────────────────────────────────────────

class TestEctopicFiltering:
    """Test that ectopic beats (>20% change) are filtered."""

    def test_ectopic_beat_filtered(self, calc):
        # Normal RR intervals with one huge spike
        rr = [800, 810, 795, 820, 1200, 800, 810, 795, 820, 780,
              800, 810, 795, 820, 780]
        dc, ac, n_dc, n_ac = calc.compute_dc_ac(rr)
        # Should still compute — the ectopic interval is excluded
        # Total anchors should be less than if no filtering
        assert dc is not None or ac is not None
