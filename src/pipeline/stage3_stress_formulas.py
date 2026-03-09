"""
stage3_stress_formulas.py

Stage 3 of the Architecture: Stress Detection via DC/AC Metrics
NO ML required — these are validated statistical formulas.

Implements:
  1. DC (Deceleration Capacity) — #1 stress feature (Velmovitsky 2022)
  2. AC (Acceleration Capacity) — #2 stress feature
  3. SDNN from RR intervals
  4. Personal baseline comparison
  5. Stress scoring (0-100 scale for Body Battery integration)

Formula reference (from Velmovitsky 2022, Bauer 2006 PRSA method):
  - Identify anchor points where heart decelerates (DC) or accelerates (AC)
  - DC = mean of (RR_i + RR_{i+1} - RR_{i-1} - RR_{i-2}) / 4
    at all deceleration anchors (RR_i > RR_{i-1})
  - AC = same formula at acceleration anchors (RR_i < RR_{i-1})
  - Filter out ectopic beats (>20% change from previous interval)

Usage:
    from stage3_stress_formulas import StressCalculator

    calc = StressCalculator()

    # From RR intervals (milliseconds)
    rr_intervals = [800, 810, 795, 820, 780, ...]
    result = calc.compute_stress(rr_intervals)
    print(result)
    # {'dc': 5.2, 'ac': -4.8, 'sdnn': 42.1, 'rmssd': 38.5,
    #  'stress_score': 35, 'stress_level': 'moderate', 'is_stressed': False}

    # From heart rate samples (BPM) — converts to RR internally
    hr_samples = [75, 74, 76, 73, 77, ...]
    result = calc.compute_stress_from_hr(hr_samples)

    # With personal baseline
    calc.update_baseline(rr_intervals)  # call during calm periods
    result = calc.compute_stress(new_rr_intervals)  # compares to baseline

TO DO:
    - Validate these formulas against WISE COGNITIVE segments
    - Port to Swift or call from Python backend
    - The stress_score feeds directly into Dyhay's Body Battery drain formula

Requires: numpy (pip install numpy)
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class StressResult:
    """Result from a single stress computation window."""
    dc: Optional[float] = None           # Deceleration Capacity (ms) — higher = better recovery
    ac: Optional[float] = None           # Acceleration Capacity (ms) — more negative = more reactive
    sdnn: Optional[float] = None         # Standard deviation of NN intervals (ms)
    rmssd: Optional[float] = None        # Root mean square of successive differences (ms)
    mean_rr: Optional[float] = None      # Mean RR interval (ms)
    mean_hr: Optional[float] = None      # Mean heart rate (BPM)
    n_intervals: int = 0                 # Number of valid RR intervals used
    n_dc_anchors: int = 0               # Number of deceleration anchor points
    n_ac_anchors: int = 0               # Number of acceleration anchor points

    # Baseline comparison (only if baseline is set)
    dc_pct_change: Optional[float] = None   # % change from baseline DC
    sdnn_pct_change: Optional[float] = None # % change from baseline SDNN

    # Final stress outputs
    stress_score: int = 50                   # 0-100 (0=calm, 100=max stress)
    stress_level: str = "unknown"            # low / moderate / high / very_high
    is_stressed: bool = False                # True if score > threshold


@dataclass
class PersonalBaseline:
    """Rolling personal baseline built from calm/rest periods."""
    dc_values: list = field(default_factory=list)
    sdnn_values: list = field(default_factory=list)
    rmssd_values: list = field(default_factory=list)
    mean_hr_values: list = field(default_factory=list)
    max_samples: int = 50  # Keep last N baseline readings

    @property
    def dc_mean(self) -> Optional[float]:
        return float(np.mean(self.dc_values)) if self.dc_values else None

    @property
    def sdnn_mean(self) -> Optional[float]:
        return float(np.mean(self.sdnn_values)) if self.sdnn_values else None

    @property
    def rmssd_mean(self) -> Optional[float]:
        return float(np.mean(self.rmssd_values)) if self.rmssd_values else None

    @property
    def hr_mean(self) -> Optional[float]:
        return float(np.mean(self.mean_hr_values)) if self.mean_hr_values else None

    def add_reading(self, dc: float, sdnn: float, rmssd: float, mean_hr: float):
        """Add a calm-period reading to the baseline."""
        self.dc_values.append(dc)
        self.sdnn_values.append(sdnn)
        self.rmssd_values.append(rmssd)
        self.mean_hr_values.append(mean_hr)
        # Trim to max_samples
        if len(self.dc_values) > self.max_samples:
            self.dc_values = self.dc_values[-self.max_samples:]
            self.sdnn_values = self.sdnn_values[-self.max_samples:]
            self.rmssd_values = self.rmssd_values[-self.max_samples:]
            self.mean_hr_values = self.mean_hr_values[-self.max_samples:]

    @property
    def is_established(self) -> bool:
        """Need at least 5 readings for a reliable baseline."""
        return len(self.dc_values) >= 5


class StressCalculator:
    """
    Computes stress metrics from RR intervals using validated formulas.

    This is Stage 3 of the Hybrid Architecture:
      Stage 1 (ML) → classifies PHYSICAL vs COGNITIVE
      Stage 2 (Rules) → adjusts threshold based on sleep
      Stage 3 (THIS) → computes DC/AC stress metrics from RR intervals

    Only runs when Stage 1 says COGNITIVE (user is still).
    """

    def __init__(self, ectopic_threshold: float = 0.20):
        """
        Args:
            ectopic_threshold: Max allowed % change between consecutive RR intervals.
                               Default 0.20 (20%) per Bauer 2006 / PMC2886688.
                               Intervals exceeding this are filtered as noise/ectopic beats.
        """
        self.ectopic_threshold = ectopic_threshold
        self.baseline = PersonalBaseline()

        # Default stress threshold (adjusted by Stage 2 sleep rules)
        self.stress_threshold = 60  # score > 60 = stressed

    # ── Core Formula: DC/AC from PRSA ────────────────────────────────────────

    def compute_dc_ac(self, rr_intervals: np.ndarray) -> tuple:
        """
        Compute Deceleration Capacity (DC) and Acceleration Capacity (AC)
        using Phase-Rectified Signal Averaging (PRSA).

        Reference: Bauer et al. 2006, validated by Velmovitsky 2022 on Apple Watch.

        Algorithm:
          1. Filter ectopic beats (>20% change)
          2. Find deceleration anchors (RR_i > RR_{i-1}) → compute DC
          3. Find acceleration anchors (RR_i < RR_{i-1}) → compute AC
          4. DC = mean of (RR_i + RR_{i+1} - RR_{i-1} - RR_{i-2}) / 4
             at all deceleration anchors

        Args:
            rr_intervals: Array of RR intervals in milliseconds.

        Returns:
            (dc, ac, n_dc_anchors, n_ac_anchors)
            dc: Deceleration Capacity in ms (higher = better vagal tone)
            ac: Acceleration Capacity in ms (more negative = more sympathetic)
        """
        rr = np.array(rr_intervals, dtype=float)

        if len(rr) < 5:
            return None, None, 0, 0

        # Step 1: Filter ectopic beats / noise
        # Mark intervals where change from previous exceeds threshold
        valid = np.ones(len(rr), dtype=bool)
        for i in range(1, len(rr)):
            pct_change = abs(rr[i] - rr[i - 1]) / rr[i - 1]
            if pct_change > self.ectopic_threshold:
                valid[i] = False
                valid[i - 1] = False  # Also exclude the neighbor

        # Need at least 5 valid intervals for PRSA
        valid_rr = rr[valid]
        if len(valid_rr) < 5:
            return None, None, 0, 0

        # Step 2-3: Find anchor points and compute PRSA
        dc_values = []
        ac_values = []

        # Need indices i where i-2, i-1, i, i+1 are all within bounds
        for i in range(2, len(valid_rr) - 1):
            rr_prev = valid_rr[i - 1]
            rr_curr = valid_rr[i]

            # PRSA value at this anchor
            prsa_val = (valid_rr[i] + valid_rr[i + 1]
                        - valid_rr[i - 1] - valid_rr[i - 2]) / 4.0

            if rr_curr > rr_prev:
                # Deceleration anchor (heart slowing down)
                dc_values.append(prsa_val)
            elif rr_curr < rr_prev:
                # Acceleration anchor (heart speeding up)
                ac_values.append(prsa_val)

        dc = float(np.mean(dc_values)) if dc_values else None
        ac = float(np.mean(ac_values)) if ac_values else None

        return dc, ac, len(dc_values), len(ac_values)

    # ── HRV Metrics ──────────────────────────────────────────────────────────

    @staticmethod
    def compute_sdnn(rr_intervals: np.ndarray) -> Optional[float]:
        """SDNN: Standard deviation of NN intervals (ms). Robust to Apple Watch gaps."""
        rr = np.array(rr_intervals, dtype=float)
        if len(rr) < 2:
            return None
        return float(np.std(rr, ddof=1))

    @staticmethod
    def compute_rmssd(rr_intervals: np.ndarray) -> Optional[float]:
        """RMSSD: Root mean square of successive differences (ms)."""
        rr = np.array(rr_intervals, dtype=float)
        if len(rr) < 2:
            return None
        diffs = np.diff(rr)
        return float(np.sqrt(np.mean(diffs ** 2)))

    # ── Conversions ──────────────────────────────────────────────────────────

    @staticmethod
    def hr_to_rr(hr_samples: list) -> np.ndarray:
        """Convert heart rate (BPM) to RR intervals (ms). RR = 60000 / HR."""
        hr = np.array(hr_samples, dtype=float)
        hr = hr[hr > 0]  # Filter invalid
        return 60000.0 / hr

    # ── Stress Scoring ───────────────────────────────────────────────────────

    def _compute_stress_score(self, result: StressResult) -> StressResult:
        """
        Convert raw metrics into a 0-100 stress score.

        Scoring logic:
          - If baseline exists: compare DC and SDNN to personal baseline
          - If no baseline: use population-based thresholds

        The score feeds into Dhyay's Body Battery (per 5-min interval):
          base_drain = 0.5
          drain = base_drain + (2.5 * (stress_score/100) * stress_type_multiplier)
          where stress_type_multiplier: cognitive=1.2, physical=1.0, mixed=1.5, none=0.1
        """
        score = 50  # Start neutral

        if self.baseline.is_established and result.dc is not None:
            # === PERSONALIZED scoring (preferred) ===
            baseline_dc = self.baseline.dc_mean
            baseline_sdnn = self.baseline.sdnn_mean

            # DC drop from baseline = stress (DC measures recovery capacity)
            if baseline_dc and baseline_dc > 0:
                dc_pct = ((result.dc - baseline_dc) / baseline_dc) * 100
                result.dc_pct_change = dc_pct
                # DC dropped 30%+ → high stress; DC same/increased → low stress
                score += int(-dc_pct * 0.8)  # negative pct change → positive score

            # SDNN drop from baseline = stress
            if baseline_sdnn and baseline_sdnn > 0 and result.sdnn is not None:
                sdnn_pct = ((result.sdnn - baseline_sdnn) / baseline_sdnn) * 100
                result.sdnn_pct_change = sdnn_pct
                score += int(-sdnn_pct * 0.5)

        elif result.dc is not None:
            # === POPULATION-BASED scoring (fallback for first 7-14 days) ===
            # Based on Velmovitsky 2022 and general HRV literature:
            # Healthy resting DC ~ 5-15 ms, SDNN ~ 30-100 ms
            if result.dc < 2.0:
                score += 25   # Very low DC → high stress
            elif result.dc < 5.0:
                score += 10   # Below average DC
            elif result.dc > 10.0:
                score -= 15   # Strong vagal tone → calm

            if result.sdnn is not None:
                if result.sdnn < 20:
                    score += 20   # Very low HRV → stress
                elif result.sdnn < 35:
                    score += 10
                elif result.sdnn > 60:
                    score -= 10   # High HRV → calm

            if result.mean_hr is not None:
                # Resting HR above personal baseline → stress indicator
                if result.mean_hr > 90:
                    score += 10
                elif result.mean_hr < 65:
                    score -= 10

        # Clamp to 0-100
        result.stress_score = max(0, min(100, score))

        # Classify
        if result.stress_score < 30:
            result.stress_level = "low"
        elif result.stress_score < 50:
            result.stress_level = "moderate"
        elif result.stress_score < 70:
            result.stress_level = "high"
        else:
            result.stress_level = "very_high"

        result.is_stressed = result.stress_score > self.stress_threshold

        return result

    # ── Main API ─────────────────────────────────────────────────────────────

    def compute_stress(self, rr_intervals: list) -> StressResult:
        """
        Compute all stress metrics from RR intervals.

        Args:
            rr_intervals: List of RR intervals in milliseconds.
                          From Apple Watch: 60000 / HR_bpm for each sample.
                          From HealthKit beat-to-beat: direct ms values.

        Returns:
            StressResult with DC, AC, SDNN, RMSSD, stress_score, etc.
        """
        rr = np.array(rr_intervals, dtype=float)

        result = StressResult()
        result.n_intervals = len(rr)

        if len(rr) < 5:
            result.stress_level = "insufficient_data"
            return result

        # Compute all metrics
        result.dc, result.ac, result.n_dc_anchors, result.n_ac_anchors = \
            self.compute_dc_ac(rr)
        result.sdnn = self.compute_sdnn(rr)
        result.rmssd = self.compute_rmssd(rr)
        result.mean_rr = float(np.mean(rr))
        result.mean_hr = 60000.0 / result.mean_rr if result.mean_rr > 0 else None

        # Score it
        return self._compute_stress_score(result)

    def compute_stress_from_hr(self, hr_samples: list) -> StressResult:
        """
        Compute stress from heart rate samples (BPM).
        Converts HR → RR intervals, then runs compute_stress().

        Args:
            hr_samples: List of heart rate values in BPM.
                        From Apple Watch HealthKit heartRate samples.
        """
        rr = self.hr_to_rr(hr_samples)
        return self.compute_stress(rr.tolist())

    def update_baseline(self, rr_intervals: list):
        """
        Add a calm-period reading to the personal baseline.
        Call this when Stage 1 says COGNITIVE and user reports no stress,
        or during the initial 7-14 day calibration period.
        """
        rr = np.array(rr_intervals, dtype=float)
        if len(rr) < 5:
            return

        dc, ac, _, _ = self.compute_dc_ac(rr)
        sdnn = self.compute_sdnn(rr)
        rmssd = self.compute_rmssd(rr)
        mean_hr = 60000.0 / float(np.mean(rr))

        if dc is not None and sdnn is not None and rmssd is not None:
            self.baseline.add_reading(dc, sdnn, rmssd, mean_hr)

    def adjust_threshold_for_sleep(self, sleep_hours: float,
                                    sleep_baseline_hours: float = 7.0):
        """
        Stage 2 integration: Adjust stress threshold based on last night's sleep.

        If sleep was poor → lower the threshold (easier to trigger stress alert).
        If sleep was good → raise the threshold (harder to trigger).

        Args:
            sleep_hours: Hours slept last night (from HealthKit fetchLastNightSleep)
            sleep_baseline_hours: Personal average sleep (default 7.0)
        """
        base_threshold = 60  # Default

        if sleep_baseline_hours <= 0:
            self.stress_threshold = base_threshold
            return

        sleep_ratio = sleep_hours / sleep_baseline_hours

        if sleep_ratio < 0.75:
            # Very poor sleep (<5.25h for 7h baseline) → much more sensitive
            self.stress_threshold = int(base_threshold * 0.80)  # 48
        elif sleep_ratio < 0.90:
            # Poor sleep → more sensitive
            self.stress_threshold = int(base_threshold * 0.85)  # 51
        elif sleep_ratio <= 1.10:
            # Normal sleep
            self.stress_threshold = base_threshold
        elif sleep_ratio <= 1.20:
            # Good sleep → slightly less sensitive
            self.stress_threshold = int(base_threshold * 1.05)  # 63
        else:
            # Excellent sleep → less sensitive
            self.stress_threshold = int(base_threshold * 1.08)  # 65

    # ── Recovery Slope (Post-Activity) ───────────────────────────────────────

    def compute_recovery_slope(self, rr_intervals_over_time: list,
                                window_size: int = 10) -> Optional[float]:
        """
        Compute the "Recovery Slope" — how fast DC increases after activity stops.

        This is the unique post-exertion metric from the architecture doc:
        Fast DC rise = high vagal tone (good resilience)
        Slow DC rise = chronic stress / fatigue

        Args:
            rr_intervals_over_time: RR intervals recorded in the 2-5 minutes
                                     AFTER Stage 1 detects movement → stillness.
            window_size: Number of RR intervals per sub-window.

        Returns:
            Recovery slope (ms/window). Positive = recovering. None if insufficient data.
        """
        rr = np.array(rr_intervals_over_time, dtype=float)

        if len(rr) < window_size * 3:
            return None

        # Compute DC in sliding windows
        dc_over_time = []
        for start in range(0, len(rr) - window_size + 1, window_size // 2):
            window = rr[start:start + window_size]
            if len(window) >= 5:
                dc, _, _, _ = self.compute_dc_ac(window)
                if dc is not None:
                    dc_over_time.append(dc)

        if len(dc_over_time) < 3:
            return None

        # Linear regression slope of DC values
        x = np.arange(len(dc_over_time))
        slope, _ = np.polyfit(x, dc_over_time, 1)

        return float(slope)


# ── Convenience: Run on WISE data for validation ─────────────────────────────

def validate_on_wise():
    """
    Quick validation: Run DC/AC on WISE COGNITIVE segments.
    Compares REST vs STRESS DC/AC values.

    Run: python stage3_stress_formulas.py
    """
    try:
        from preprocess_wise import df_features
    except ImportError:
        print("Cannot import preprocess_wise — run from team repo directory.")
        print("Usage: cd Capstone-Behavorial && python stage3_stress_formulas.py")
        return

    print("=" * 60)
    print("Stage 3 Validation: DC/AC on WISE COGNITIVE Segments")
    print("=" * 60)

    # WISE doesn't have raw RR intervals directly, but we can simulate
    # from HR samples using RR = 60000 / HR
    # In real deployment, Apple Watch provides actual RR via HealthKit

    calc = StressCalculator()

    # Group by subject and label, compute DC for each segment
    from collections import defaultdict
    results = defaultdict(list)

    # df_features IS already the COGNITIVE (STRESS protocol) data.
    # It has 'label' (REST/STRESS) and 'subject' columns, not 'activity_type'.
    cognitive = df_features.copy()

    for (subject, label), group in cognitive.groupby(['subject', 'label']):
        hr_values = group['HR_mean'].dropna().values
        if len(hr_values) < 5:
            continue

        # Simulate RR intervals from mean HR values (approximation)
        # In real deployment, use actual beat-to-beat intervals
        rr = 60000.0 / hr_values
        result = calc.compute_stress(rr.tolist())

        if result.dc is not None:
            results[label].append({
                'subject': subject,
                'dc': result.dc,
                'ac': result.ac,
                'sdnn': result.sdnn,
                'stress_score': result.stress_score,
            })

    for label in ['REST', 'STRESS']:
        if label not in results:
            continue
        dcs = [r['dc'] for r in results[label]]
        scores = [r['stress_score'] for r in results[label]]
        print(f"\n{label} (n={len(dcs)}):")
        print(f"  DC:           {np.mean(dcs):.2f} +/- {np.std(dcs):.2f} ms")
        print(f"  Stress Score: {np.mean(scores):.1f} +/- {np.std(scores):.1f}")

    if 'REST' in results and 'STRESS' in results:
        rest_dc = [r['dc'] for r in results['REST']]
        stress_dc = [r['dc'] for r in results['STRESS']]
        from scipy import stats
        t_stat, p_val = stats.ttest_ind(rest_dc, stress_dc)
        print(f"\nREST vs STRESS DC: t={t_stat:.3f}, p={p_val:.4f}")
        if p_val < 0.05:
            print("  ✓ DC significantly distinguishes REST from STRESS")
        else:
            print("  ✗ DC not significant (expected with HR-approximated RR)")


if __name__ == '__main__':
    # Demo with synthetic RR intervals
    print("=" * 60)
    print("Stage 3: DC/AC Stress Formulas — Demo")
    print("=" * 60)

    calc = StressCalculator()

    # Simulated calm RR intervals (~75 BPM, regular rhythm)
    np.random.seed(42)
    calm_rr = 800 + np.random.normal(0, 20, 60)  # ~800ms = 75 BPM

    # Simulated stressed RR intervals (~90 BPM, less variable)
    stress_rr = 667 + np.random.normal(0, 10, 60)  # ~667ms = 90 BPM

    print("\n--- Calm State (simulated ~75 BPM) ---")
    result = calc.compute_stress(calm_rr.tolist())
    print(f"  DC:     {result.dc:.2f} ms")
    print(f"  AC:     {result.ac:.2f} ms")
    print(f"  SDNN:   {result.sdnn:.2f} ms")
    print(f"  RMSSD:  {result.rmssd:.2f} ms")
    print(f"  Score:  {result.stress_score}/100 ({result.stress_level})")

    # Build baseline from calm data
    calc.update_baseline(calm_rr.tolist())
    calc.update_baseline(calm_rr.tolist())
    calc.update_baseline(calm_rr.tolist())
    calc.update_baseline(calm_rr.tolist())
    calc.update_baseline(calm_rr.tolist())
    print(f"\n  Baseline established: DC={calc.baseline.dc_mean:.2f}, SDNN={calc.baseline.sdnn_mean:.2f}")

    print("\n--- Stressed State (simulated ~90 BPM) ---")
    result = calc.compute_stress(stress_rr.tolist())
    print(f"  DC:     {result.dc:.2f} ms")
    print(f"  AC:     {result.ac:.2f} ms")
    print(f"  SDNN:   {result.sdnn:.2f} ms")
    print(f"  RMSSD:  {result.rmssd:.2f} ms")
    print(f"  Score:  {result.stress_score}/100 ({result.stress_level})")
    print(f"  DC change from baseline: {result.dc_pct_change:.1f}%")

    print("\n--- Sleep Adjustment Demo ---")
    calc.adjust_threshold_for_sleep(sleep_hours=5.0, sleep_baseline_hours=7.0)
    print(f"  Poor sleep (5h/7h): threshold lowered to {calc.stress_threshold}")
    result = calc.compute_stress(stress_rr.tolist())
    print(f"  Same data, new threshold: stressed={result.is_stressed} (score={result.stress_score})")

    # Run WISE validation if available
    print()
    validate_on_wise()
