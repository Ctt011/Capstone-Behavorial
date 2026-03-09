"""
run_stage2_fitbit.py

Runs Stage 2 (Sleep-Based Threshold Adjustment) on Fitbit PMData sleep data.

For each participant:
  1. Loads sleep.json (main sleep only, no naps)
  2. Feeds nightly sleep hours through SleepQualityAssessor
  3. Builds personal rolling baseline over first 7+ nights
  4. Outputs per-night quality ratings and adjusted stress thresholds

Usage:
    python run_stage2_fitbit.py
"""

import os
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stage2_sleep_rules import SleepQualityAssessor

# ── Configuration ────────────────────────────────────────────────────────────

FITBIT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Fitbit6-PMData')
PARTICIPANTS = ['p04', 'p08', 'p09', 'p11', 'p13', 'p16']


# ── Load sleep data ─────────────────────────────────────────────────────────

def load_fitbit_sleep(participant_id: str) -> list[dict]:
    """
    Load and parse sleep.json for a participant.
    Returns list of {'date': str, 'hours': float} sorted chronologically.
    Only includes main sleep entries (no naps).
    """
    sleep_path = os.path.join(FITBIT_DIR, participant_id, 'fitbit', 'sleep.json')

    with open(sleep_path) as f:
        raw = json.load(f)

    nights = []
    for entry in raw:
        if not entry.get('mainSleep', False):
            continue

        date = entry['dateOfSleep']
        hours = entry['minutesAsleep'] / 60.0
        nights.append({'date': date, 'hours': hours})

    # Sort by date
    nights.sort(key=lambda x: x['date'])
    return nights


# ── Run Stage 2 ─────────────────────────────────────────────────────────────

def run_stage2(participant_id: str) -> list[dict]:
    """
    Run Stage 2 on a participant's sleep data.
    Returns list of per-night results with quality and threshold adjustments.
    """
    nights = load_fitbit_sleep(participant_id)
    assessor = SleepQualityAssessor()
    results = []

    for night in nights:
        assessment = assessor.get_threshold_adjustment(night['hours'])
        assessor.record_sleep(night['hours'])

        results.append({
            'date': night['date'],
            'sleep_hours': night['hours'],
            'baseline_hours': assessment.sleep_baseline_hours,
            'sleep_ratio': assessment.sleep_ratio,
            'quality': assessment.quality,
            'threshold_multiplier': assessment.threshold_multiplier,
            'adjusted_threshold': assessment.adjusted_threshold,
        })

    return results


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("=" * 70)
    print("Stage 2: Sleep-Based Threshold Adjustment — Fitbit PMData")
    print("=" * 70)

    for pid in PARTICIPANTS:
        results = run_stage2(pid)

        # Summary counts
        quality_counts = {}
        for r in results:
            quality_counts[r['quality']] = quality_counts.get(r['quality'], 0) + 1

        avg_sleep = sum(r['sleep_hours'] for r in results) / len(results)

        print(f"\n{'─' * 70}")
        print(f"Participant: {pid} | {len(results)} nights | Avg sleep: {avg_sleep:.1f}h")
        print(f"Quality distribution: {quality_counts}")
        print(f"{'─' * 70}")
        print(f"  {'Date':<12} {'Sleep':>6} {'Baseline':>9} {'Ratio':>6} {'Quality':<10} {'Mult':>5} {'Threshold':>10}")

        for r in results:
            print(f"  {r['date']:<12} {r['sleep_hours']:>5.1f}h {r['baseline_hours']:>8.1f}h {r['sleep_ratio']:>6.2f} {r['quality']:<10} {r['threshold_multiplier']:>5.2f} {r['adjusted_threshold']:>10}")

    print(f"\n{'=' * 70}")
    print("DONE")
    print("=" * 70)
