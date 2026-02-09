"""
parse_apple_health.py

Parses Apple Health export.xml into clean DataFrames for the pipeline.

Extracts:
  1. Heart Rate (HR) — ~106K records from Apple Watch
  2. HRV / SDNN — ~1.6K records (2-3 per day)
  3. Step Count — ~122K records (variable intervals)
  4. Sleep Analysis — ~3.5K records
  5. Resting Heart Rate — ~500 records (daily)

Output:
  - DataFrames saved as CSV for easy reuse
  - Ready to feed into Stage 1 (activity) and Stage 3 (stress) pipelines

Usage:
    python parse_apple_health.py /path/to/export.xml

    # Or from Python:
    from parse_apple_health import parse_apple_health
    data = parse_apple_health('apple_health_export/export.xml')
    print(data['heart_rate'].head())
    print(data['hrv'].head())

For Lev:
    - Use data['heart_rate'] + data['steps'] for Stage 1 inference
    - Use data['hrv'] for daily SDNN baseline
    - Use data['sleep'] for Stage 2 sleep rules

Note: export.xml is ~474MB. Parsing takes ~30-60 seconds using iterparse
      (streaming, not loading entire file into memory).
"""

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict

import numpy as np
import pandas as pd


# Record types we care about
RECORD_TYPES = {
    'HKQuantityTypeIdentifierHeartRate': 'heart_rate',
    'HKQuantityTypeIdentifierHeartRateVariabilitySDNN': 'hrv',
    'HKQuantityTypeIdentifierStepCount': 'steps',
    'HKQuantityTypeIdentifierRestingHeartRate': 'resting_hr',
    'HKQuantityTypeIdentifierActiveEnergyBurned': 'calories',
    'HKQuantityTypeIdentifierDistanceWalkingRunning': 'distance',
    'HKQuantityTypeIdentifierOxygenSaturation': 'spo2',
    'HKQuantityTypeIdentifierRespiratoryRate': 'respiratory_rate',
}

SLEEP_TYPE = 'HKCategoryTypeIdentifierSleepAnalysis'


def parse_timestamp(ts_str: str) -> datetime:
    """Parse Apple Health timestamp like '2022-10-22 14:00:18 -0800'."""
    # Format: YYYY-MM-DD HH:MM:SS +/-HHMM
    return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S %z')


def parse_apple_health(xml_path: str,
                        source_filter: str = None,
                        watch_only: bool = True) -> dict:
    """
    Parse Apple Health export.xml into DataFrames.

    Args:
        xml_path: Path to export.xml
        source_filter: Only keep records from this source name (e.g. "Brandon's Apple Watch")
        watch_only: If True (default), only keep Apple Watch records (filters out iPhone)

    Returns:
        Dict of DataFrames:
          - 'heart_rate': timestamp, value (BPM), source
          - 'hrv': timestamp, value (SDNN ms), source
          - 'steps': start_time, end_time, value (count), duration_sec, source
          - 'sleep': start_time, end_time, value (sleep stage), duration_sec
          - 'resting_hr': timestamp, value (BPM)
          - 'calories': start_time, end_time, value (kcal)
          - 'metadata': device info, date range, record counts
    """
    if not os.path.exists(xml_path):
        raise FileNotFoundError(f"Not found: {xml_path}")

    file_size_mb = os.path.getsize(xml_path) / (1024 * 1024)
    print(f"Parsing {xml_path} ({file_size_mb:.0f} MB)...")

    # Collect records by type
    records = defaultdict(list)
    sleep_records = []
    record_count = 0
    sources_seen = set()

    # Use iterparse for memory efficiency (streaming)
    context = ET.iterparse(xml_path, events=('end',))

    for event, elem in context:
        if elem.tag == 'Record':
            record_count += 1
            if record_count % 100000 == 0:
                print(f"  ...processed {record_count:,} records")

            record_type = elem.get('type', '')
            source = elem.get('sourceName', '')
            sources_seen.add(source)

            # Filter by source if requested
            if source_filter and source_filter not in source:
                elem.clear()
                continue

            # Filter for Apple Watch only
            if watch_only and 'Watch' not in source and 'watch' not in source:
                # Allow sleep records from any source
                if record_type != SLEEP_TYPE:
                    elem.clear()
                    continue

            if record_type in RECORD_TYPES:
                key = RECORD_TYPES[record_type]
                try:
                    value = float(elem.get('value', 0))
                    start = elem.get('startDate', '')
                    end = elem.get('endDate', '')

                    record = {
                        'start_time': parse_timestamp(start) if start else None,
                        'end_time': parse_timestamp(end) if end else None,
                        'value': value,
                        'source': source,
                    }
                    records[key].append(record)
                except (ValueError, TypeError):
                    pass

            elif record_type == SLEEP_TYPE:
                try:
                    start = elem.get('startDate', '')
                    end = elem.get('endDate', '')
                    value = elem.get('value', '')
                    sleep_records.append({
                        'start_time': parse_timestamp(start) if start else None,
                        'end_time': parse_timestamp(end) if end else None,
                        'value': value,
                        'source': source,
                    })
                except (ValueError, TypeError):
                    pass

            # Free memory
            elem.clear()

    print(f"  Total records scanned: {record_count:,}")
    print(f"  Sources found: {sources_seen}")

    # Convert to DataFrames
    result = {}

    # Heart Rate
    if records['heart_rate']:
        df_hr = pd.DataFrame(records['heart_rate'])
        df_hr['timestamp'] = df_hr['start_time']
        df_hr = df_hr[['timestamp', 'value', 'source']].sort_values('timestamp')
        df_hr.columns = ['timestamp', 'hr_bpm', 'source']
        result['heart_rate'] = df_hr.reset_index(drop=True)
        print(f"  Heart Rate: {len(df_hr):,} records")

    # HRV (SDNN)
    if records['hrv']:
        df_hrv = pd.DataFrame(records['hrv'])
        df_hrv['timestamp'] = df_hrv['start_time']
        df_hrv = df_hrv[['timestamp', 'value', 'source']].sort_values('timestamp')
        df_hrv.columns = ['timestamp', 'sdnn_ms', 'source']
        result['hrv'] = df_hrv.reset_index(drop=True)
        print(f"  HRV (SDNN): {len(df_hrv):,} records")

    # Steps (have start and end times — variable intervals)
    if records['steps']:
        df_steps = pd.DataFrame(records['steps'])
        df_steps['duration_sec'] = (
            df_steps['end_time'] - df_steps['start_time']
        ).dt.total_seconds()
        df_steps = df_steps[['start_time', 'end_time', 'value', 'duration_sec', 'source']]
        df_steps.columns = ['start_time', 'end_time', 'steps', 'duration_sec', 'source']
        df_steps = df_steps.sort_values('start_time').reset_index(drop=True)
        result['steps'] = df_steps
        print(f"  Steps: {len(df_steps):,} records")

    # Sleep
    if sleep_records:
        df_sleep = pd.DataFrame(sleep_records)
        df_sleep['duration_sec'] = (
            df_sleep['end_time'] - df_sleep['start_time']
        ).dt.total_seconds()
        df_sleep = df_sleep.sort_values('start_time').reset_index(drop=True)
        result['sleep'] = df_sleep
        print(f"  Sleep: {len(df_sleep):,} records")

    # Resting HR
    if records['resting_hr']:
        df_rhr = pd.DataFrame(records['resting_hr'])
        df_rhr['timestamp'] = df_rhr['start_time']
        df_rhr = df_rhr[['timestamp', 'value']].sort_values('timestamp')
        df_rhr.columns = ['timestamp', 'resting_hr_bpm']
        result['resting_hr'] = df_rhr.reset_index(drop=True)
        print(f"  Resting HR: {len(df_rhr):,} records")

    # Calories
    if records['calories']:
        df_cal = pd.DataFrame(records['calories'])
        df_cal = df_cal[['start_time', 'end_time', 'value']].sort_values('start_time')
        df_cal.columns = ['start_time', 'end_time', 'calories_kcal']
        result['calories'] = df_cal.reset_index(drop=True)
        print(f"  Calories: {len(df_cal):,} records")

    # Metadata
    result['metadata'] = {
        'xml_path': xml_path,
        'file_size_mb': file_size_mb,
        'total_records_scanned': record_count,
        'sources': list(sources_seen),
        'record_counts': {k: len(v) for k, v in result.items() if k != 'metadata'},
    }

    return result


# ── Aggregation helpers for pipeline use ─────────────────────────────────────

def aggregate_hr_to_windows(df_hr: pd.DataFrame,
                             window_minutes: int = 5) -> pd.DataFrame:
    """
    Aggregate HR samples into fixed-width time windows.

    Apple Watch samples HR every 5-20 min (background) or every 5-6s (workout).
    This creates uniform windows for Stage 1 / Stage 3 input.

    Args:
        df_hr: Heart rate DataFrame from parse_apple_health()
        window_minutes: Window width in minutes (default 5)

    Returns:
        DataFrame with columns: window_start, HR_mean, HR_std, HR_max, HR_min, n_samples
    """
    df = df_hr.copy()
    df['timestamp'] = pd.to_datetime(df['timestamp'], utc=True)
    df = df.set_index('timestamp')

    # Resample into fixed windows
    rule = f'{window_minutes}min'
    agg = df['hr_bpm'].resample(rule).agg(['mean', 'std', 'max', 'min', 'count'])
    agg.columns = ['HR_mean', 'HR_std', 'HR_max', 'HR_min', 'n_samples']

    # Drop windows with no data
    agg = agg[agg['n_samples'] > 0].reset_index()
    agg.rename(columns={'timestamp': 'window_start'}, inplace=True)

    return agg


def aggregate_steps_to_windows(df_steps: pd.DataFrame,
                                window_minutes: int = 5) -> pd.DataFrame:
    """
    Aggregate step counts into fixed-width time windows.

    Steps serve as ACC proxy for Stage 1 activity classification.
    High steps → PHYSICAL, Low steps → COGNITIVE.

    Args:
        df_steps: Steps DataFrame from parse_apple_health()
        window_minutes: Window width in minutes (default 5)

    Returns:
        DataFrame with: window_start, steps_total, steps_per_min, is_active
    """
    df = df_steps.copy()
    df['start_time'] = pd.to_datetime(df['start_time'], utc=True)
    df = df.set_index('start_time')

    rule = f'{window_minutes}min'
    agg = df['steps'].resample(rule).agg(['sum', 'mean', 'count'])
    agg.columns = ['steps_total', 'steps_mean', 'n_records']
    agg['steps_per_min'] = agg['steps_total'] / window_minutes
    agg['is_active'] = agg['steps_per_min'] > 5  # >5 steps/min = moving

    agg = agg.reset_index()
    agg.rename(columns={'start_time': 'window_start'}, inplace=True)

    return agg


def get_nightly_sleep_hours(df_sleep: pd.DataFrame) -> pd.DataFrame:
    """
    Compute nightly sleep hours from HealthKit sleep analysis records.
    Groups by night (6pm-noon window) and sums asleep durations.

    Returns:
        DataFrame with: date, sleep_hours, n_records
    """
    df = df_sleep.copy()
    df['start_time'] = pd.to_datetime(df['start_time'], utc=True)

    # Filter to "asleep" states
    asleep_values = [
        'HKCategoryValueSleepAnalysisAsleepCore',
        'HKCategoryValueSleepAnalysisAsleepDeep',
        'HKCategoryValueSleepAnalysisAsleepREM',
        'HKCategoryValueSleepAnalysisAsleep',
        'HKCategoryValueSleepAnalysisInBed',  # Older Apple Watch (no sleep staging)
        # Numeric values from older iOS versions
        '1',
    ]
    asleep = df[df['value'].isin(asleep_values)].copy()

    if asleep.empty:
        return pd.DataFrame(columns=['date', 'sleep_hours', 'n_records'])

    # Assign to "night of" date (before 12pm → previous day)
    asleep['night_date'] = asleep['start_time'].apply(
        lambda x: x.date() if x.hour >= 18 else (x - pd.Timedelta(days=1)).date()
    )

    nightly = asleep.groupby('night_date').agg(
        sleep_seconds=('duration_sec', 'sum'),
        n_records=('duration_sec', 'count'),
    ).reset_index()

    nightly['sleep_hours'] = nightly['sleep_seconds'] / 3600.0
    nightly.rename(columns={'night_date': 'date'}, inplace=True)

    return nightly[['date', 'sleep_hours', 'n_records']]


# ── Save to CSV ──────────────────────────────────────────────────────────────

def save_parsed_data(data: dict, output_dir: str):
    """Save all parsed DataFrames as CSV files."""
    os.makedirs(output_dir, exist_ok=True)

    for key, df in data.items():
        if key == 'metadata':
            continue
        if isinstance(df, pd.DataFrame):
            path = os.path.join(output_dir, f'apple_health_{key}.csv')
            df.to_csv(path, index=False)
            print(f"  Saved: {path} ({len(df):,} rows)")


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    if len(sys.argv) < 2:
        # Default to Brandon's export
        xml_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            '..', 'behavior-cap', 'apple_health_export', 'export.xml'
        )
        if not os.path.exists(xml_path):
            print("Usage: python parse_apple_health.py /path/to/export.xml")
            print(f"Default path not found: {xml_path}")
            sys.exit(1)
    else:
        xml_path = sys.argv[1]

    # Parse
    data = parse_apple_health(xml_path)

    # Aggregate into windows
    print("\n--- Aggregating into 5-minute windows ---")
    if 'heart_rate' in data:
        hr_windows = aggregate_hr_to_windows(data['heart_rate'], window_minutes=5)
        print(f"HR windows: {len(hr_windows):,} (5-min)")
        data['hr_windows'] = hr_windows

    if 'steps' in data:
        step_windows = aggregate_steps_to_windows(data['steps'], window_minutes=5)
        print(f"Step windows: {len(step_windows):,} (5-min)")
        active_pct = step_windows['is_active'].mean() * 100
        print(f"  Active windows: {active_pct:.1f}%")
        data['step_windows'] = step_windows

    if 'sleep' in data:
        nightly = get_nightly_sleep_hours(data['sleep'])
        print(f"Nightly sleep: {len(nightly)} nights")
        if not nightly.empty:
            print(f"  Avg: {nightly['sleep_hours'].mean():.1f}h")
            print(f"  Range: {nightly['sleep_hours'].min():.1f}h - {nightly['sleep_hours'].max():.1f}h")
        data['nightly_sleep'] = nightly

    # Save CSVs
    output_dir = os.path.join(os.path.dirname(xml_path), 'parsed')
    print(f"\n--- Saving CSVs to {output_dir} ---")
    save_parsed_data(data, output_dir)

    # Summary
    print("\n" + "=" * 60)
    print("PARSE COMPLETE")
    print("=" * 60)
    meta = data['metadata']
    print(f"  File: {meta['xml_path']}")
    print(f"  Size: {meta['file_size_mb']:.0f} MB")
    print(f"  Sources: {meta['sources']}")
    for key, count in meta['record_counts'].items():
        print(f"  {key}: {count:,}")
