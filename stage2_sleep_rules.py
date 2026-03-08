"""
stage2_sleep_rules.py

Stage 2 of the Hybrid Architecture: Sleep-Based Threshold Adjustment
NO ML required — rule-based heuristic backed by Apple 2024 research.

Scientific basis:
  - Apple "Beyond Sensor Data" study (2024): Behavioral data (sleep)
    improves physiological predictions more than adding extra sensors.
  - Sleep deprivation reduces autonomic buffer → more vulnerable to stress.

Logic:
  - Poor sleep → LOWER the stress detection threshold (more sensitive)
  - Good sleep → KEEP or RAISE the threshold (less sensitive)

This module provides:
  1. SleepQualityAssessor — classifies last night's sleep
  2. ThresholdAdjuster — adjusts Stage 3 stress threshold
  3. Integration with HealthKit sleep data (fetchLastNightSleep output)

Usage:
    from stage2_sleep_rules import SleepQualityAssessor

    assessor = SleepQualityAssessor()

    # After fetching sleep from HealthKit
    sleep_hours = 5.2  # from fetchLastNightSleep()
    adjustment = assessor.get_threshold_adjustment(sleep_hours)
    print(adjustment)
    # {'quality': 'poor', 'threshold_multiplier': 0.85,
    #  'adjusted_threshold': 51, 'message': 'Poor sleep detected...'}

    # Feed into Stage 3
    from stage3_stress_formulas import StressCalculator
    calc = StressCalculator()
    calc.stress_threshold = adjustment['adjusted_threshold']

TO DO:
    - Wire this into the app's morning data refresh
    - Call after fetchLastNightSleep() returns
    - Pass adjusted threshold to StressCalculator
"""

from dataclasses import dataclass
from typing import Optional


BASE_STRESS_THRESHOLD = 60  # Default: stress_score > 60 = "stressed"


@dataclass
class SleepAssessment:
    """Result of sleep quality assessment."""
    sleep_hours: float
    sleep_baseline_hours: float
    sleep_ratio: float              # actual / baseline
    quality: str                    # very_poor / poor / normal / good / excellent
    threshold_multiplier: float     # multiply base threshold by this
    adjusted_threshold: int         # final threshold for Stage 3
    message: str                    # readable explanation


class SleepQualityAssessor:
    """
    Assesses sleep quality and adjusts the Stage 3 stress threshold.

    The sleep baseline is built over time from the user's own data.
    During the first 7 days, uses a default of 7.0 hours.
    After 7+ days, uses the user's personal rolling average.
    """

    def __init__(self, default_baseline_hours: float = 7.0):
        self.default_baseline_hours = default_baseline_hours
        self._sleep_history: list[float] = []  # Rolling history of sleep hours
        self._max_history = 30  # Last 30 nights

    @property
    def sleep_baseline(self) -> float:
        """Personal average sleep hours (or default if <7 nights recorded)."""
        if len(self._sleep_history) >= 7:
            return sum(self._sleep_history) / len(self._sleep_history)
        return self.default_baseline_hours

    def record_sleep(self, hours: float):
        """Record a night's sleep. Call daily after fetchLastNightSleep()."""
        if hours > 0:
            self._sleep_history.append(hours)
            if len(self._sleep_history) > self._max_history:
                self._sleep_history = self._sleep_history[-self._max_history:]

    def get_threshold_adjustment(self, sleep_hours: float) -> SleepAssessment:
        """
        Assess last night's sleep and return adjusted stress threshold.

        Rules (from Hybrid Architecture design doc):
          sleep < 75% of baseline → very_poor → threshold × 0.80 (much more sensitive)
          sleep < 90% of baseline → poor      → threshold × 0.85
          sleep 90-110% baseline  → normal    → threshold × 1.00
          sleep > 110% baseline   → good      → threshold × 1.05
          sleep > 120% baseline   → excellent → threshold × 1.08

        These multipliers are conservative — backed by the principle that
        sleep deprivation measurably reduces HRV (Hernando 2018).
        """
        baseline = self.sleep_baseline

        if baseline <= 0:
            return SleepAssessment(
                sleep_hours=sleep_hours,
                sleep_baseline_hours=baseline,
                sleep_ratio=1.0,
                quality="unknown",
                threshold_multiplier=1.0,
                adjusted_threshold=BASE_STRESS_THRESHOLD,
                message="No sleep baseline yet."
            )

        ratio = sleep_hours / baseline

        if ratio < 0.75:
            quality = "very_poor"
            multiplier = 0.80
            msg = (f"Very poor sleep ({sleep_hours:.1f}h vs {baseline:.1f}h avg). "
                   f"Stress sensitivity increased — take it easy today.")
        elif ratio < 0.90:
            quality = "poor"
            multiplier = 0.85
            msg = (f"Below average sleep ({sleep_hours:.1f}h vs {baseline:.1f}h avg). "
                   f"You may be more susceptible to stress today.")
        elif ratio <= 1.10:
            quality = "normal"
            multiplier = 1.00
            msg = f"Normal sleep ({sleep_hours:.1f}h). Stress thresholds at baseline."
        elif ratio <= 1.20:
            quality = "good"
            multiplier = 1.05
            msg = (f"Good sleep ({sleep_hours:.1f}h). "
                   f"Slightly higher stress resilience today.")
        else:
            quality = "excellent"
            multiplier = 1.08
            msg = (f"Excellent sleep ({sleep_hours:.1f}h). "
                   f"Higher stress resilience today.")

        adjusted = int(BASE_STRESS_THRESHOLD * multiplier)

        return SleepAssessment(
            sleep_hours=sleep_hours,
            sleep_baseline_hours=baseline,
            sleep_ratio=ratio,
            quality=quality,
            threshold_multiplier=multiplier,
            adjusted_threshold=adjusted,
            message=msg
        )


# ── Integration helper for the full pipeline ─────────────────────────────────

def morning_adjustment(sleep_hours: float,
                       assessor: Optional[SleepQualityAssessor] = None) -> dict:
    """
    Quick one-call function for the morning dashboard.

    Call this when the app launches or at start of day.
    Returns a dict that can be passed to Stage 3.

    Example:
        adjustment = morning_adjustment(5.2)
        stress_calc.stress_threshold = adjustment['adjusted_threshold']
    """
    if assessor is None:
        assessor = SleepQualityAssessor()

    assessment = assessor.get_threshold_adjustment(sleep_hours)
    assessor.record_sleep(sleep_hours)

    return {
        'sleep_hours': assessment.sleep_hours,
        'quality': assessment.quality,
        'adjusted_threshold': assessment.adjusted_threshold,
        'threshold_multiplier': assessment.threshold_multiplier,
        'message': assessment.message,
    }


if __name__ == '__main__':
    print("=" * 60)
    print("Stage 2: Sleep-Based Threshold Adjustment — Demo")
    print("=" * 60)

    assessor = SleepQualityAssessor()

    # Simulate a week of sleep to build baseline
    week_sleep = [7.2, 6.8, 7.5, 7.0, 6.5, 7.3, 7.1]
    for hours in week_sleep:
        assessor.record_sleep(hours)
    print(f"Sleep baseline (7 nights): {assessor.sleep_baseline:.1f}h")

    # Test different sleep scenarios
    test_cases = [
        ("Very poor night", 4.5),
        ("Poor night", 5.5),
        ("Normal night", 7.0),
        ("Good night", 8.0),
        ("Excellent night", 9.0),
    ]

    for label, hours in test_cases:
        result = assessor.get_threshold_adjustment(hours)
        print(f"\n{label} ({hours}h):")
        print(f"  Quality:    {result.quality}")
        print(f"  Ratio:      {result.sleep_ratio:.2f}")
        print(f"  Multiplier: {result.threshold_multiplier}")
        print(f"  Threshold:  {result.adjusted_threshold} (base={BASE_STRESS_THRESHOLD})")
        print(f"  Message:    {result.message}")
