"""
preprocess_wise.py

Single preprocessing file for WISE dataset preprocessing.
Loads, segments, windows, imputes, and exports data for both notebooks:
  - Biomarker_Comparison.ipynb (Stage 1: Activity Classifier)
  - StressLevel_model.ipynb   (Stage 2: Stress Regression)

Exports:
  - stress_level_v1:  Self-reported stress scores (V1 / male 'S' subjects)
  - stress_level_v2:  Self-reported stress scores (V2 / female 'f' subjects)
  - df_features:      Windowed features from STRESS protocol only (REST + STRESS)
  - df_activity:      Windowed features from ALL 3 protocols (COGNITIVE, AEROBIC, ANAEROBIC)
  - APPLE_WATCH_FEATURES: List of feature columns available on Apple Watch

Usage:
    from load_stress_data import df_features, df_activity, stress_level_v1, stress_level_v2
    from load_stress_data import APPLE_WATCH_FEATURES, ALL_FEATURES
"""

import os
import datetime
import numpy as np
import pandas as pd

# ── Constants ────────────────────────────────────────────────────────────────

WINDOW_SIZE_SEC = 30    # 30-second sliding windows (Essie's suggestion)
WINDOW_OVERLAP = 0.5    # 50% overlap

# Apple Watch only has HR, HRV, ACC (no EDA, no skin temperature)
APPLE_WATCH_FEATURES = ['HR_mean', 'HR_std', 'HR_max', 'SDNN', 'RMSSD', 'ACC_mean', 'ACC_std']

# Full Empatica E4 feature set
ALL_FEATURES = ['SDNN', 'RMSSD', 'EDA_mean', 'EDA_std', 'HR_mean', 'HR_std', 'HR_max',
                'TEMP_mean', 'TEMP_std', 'ACC_mean', 'ACC_std']

# ── File paths ───────────────────────────────────────────────────────────────

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

STRESS_PATH = os.path.join(_BASE_DIR, "22subjects", "STRESS")
AEROBIC_PATH = os.path.join(_BASE_DIR, "22subjects", "AEROBIC")
ANAEROBIC_PATH = os.path.join(_BASE_DIR, "22subjects", "ANAEROBIC")

_stress_level_v1_path = os.path.join(_BASE_DIR, "WISE_data_files", "Stress_Level_v1.csv")
_stress_level_v2_path = os.path.join(_BASE_DIR, "WISE_data_files", "Stress_Level_v2.csv")
_subject_info_path = os.path.join(_BASE_DIR, "WISE_data_files", "subject-info.csv")


# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

def create_df_array(dataframe):
    """Converts a pandas DataFrame to a flattened numpy array."""
    return dataframe.values.flatten()


def time_abs_(UTC_array):
    """Converts UTC timestamps to seconds from the start of recording."""
    new_array = []
    start_time = datetime.datetime.strptime(UTC_array[0], '%Y-%m-%d %H:%M:%S')
    for utc in UTC_array:
        current_time = datetime.datetime.strptime(utc, '%Y-%m-%d %H:%M:%S')
        seconds_elapsed = (current_time - start_time).total_seconds()
        new_array.append(int(seconds_elapsed))
    return new_array


def moving_average(acc_data):
    """
    Applies a moving average filter to accelerometer data to measure movement.
    Higher values = more movement, Lower values = less movement.
    """
    avg = 0
    prevX, prevY, prevZ = 0, 0, 0
    results = []
    for i in range(0, len(acc_data), 32):
        sum_ = 0
        buffX = acc_data[i:i+32, 0]
        buffY = acc_data[i:i+32, 1]
        buffZ = acc_data[i:i+32, 2]
        for j in range(len(buffX)):
            sum_ += max(
                abs(buffX[j] - prevX),
                abs(buffY[j] - prevY),
                abs(buffZ[j] - prevZ)
            )
            prevX, prevY, prevZ = buffX[j], buffY[j], buffZ[j]
        avg = avg * 0.9 + (sum_ / 32) * 0.1
        results.append(avg)
    return results


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL LOADING
# ══════════════════════════════════════════════════════════════════════════════

def read_signals(main_folder):
    """
    Read all signals from a protocol folder (STRESS, AEROBIC, or ANAEROBIC).
    Each subject folder contains: EDA, BVP, HR, IBI, TEMP, ACC, tags.
    """
    signal_dict = {}
    time_dict = {}
    fs_dict = {}

    subfolders = next(os.walk(main_folder))[1]

    utc_start_dict = {}
    for folder_name in subfolders:
        csv_path = f'{main_folder}/{folder_name}/EDA.csv'
        df = pd.read_csv(csv_path)
        utc_start_dict[folder_name] = df.columns.tolist()

    for folder_name in subfolders:
        folder_path = os.path.join(main_folder, folder_name)
        files = os.listdir(folder_path)

        signals = {}
        time_line = {}
        fs_signal = {}

        desired_files = ['EDA.csv', 'BVP.csv', 'HR.csv', 'TEMP.csv',
                         'tags.csv', 'ACC.csv', 'IBI.csv']

        for file_name in files:
            if file_name not in desired_files:
                continue

            file_path = os.path.join(folder_path, file_name)
            signal_name = file_name.replace('.csv', '')

            if file_name == 'tags.csv':
                try:
                    df = pd.read_csv(file_path, header=None)
                    tags_vector = create_df_array(df)
                    tags_UTC_vector = np.insert(tags_vector, 0,
                                                utc_start_dict[folder_name])
                    signal_array = time_abs_(tags_UTC_vector)
                except pd.errors.EmptyDataError:
                    signal_array = []

            elif file_name == 'IBI.csv':
                df = pd.read_csv(file_path)
                signal_array = df.values
                fs_signal['IBI'] = 'variable'

            else:
                df = pd.read_csv(file_path)
                fs = int(df.iloc[0, 0])
                signal_array = df.iloc[1:].values
                time_array = np.linspace(0, len(signal_array)/fs,
                                         len(signal_array))
                time_line[signal_name] = time_array
                fs_signal[signal_name] = fs

            signals[signal_name] = signal_array

        signal_dict[folder_name] = signals
        time_dict[folder_name] = time_line
        fs_dict[folder_name] = fs_signal

    return signal_dict, time_dict, fs_dict


# ══════════════════════════════════════════════════════════════════════════════
# SEGMENTATION FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

def get_stress_rest_segments(subject_id, tags):
    """Get both REST and STRESS (cognitive task) segments from STRESS protocol.

    V1 (S subjects): Baseline(R) -> Stroop(S) -> Rest(R) -> TMCT(S) -> Rest(R)
                     -> Speeches(S) -> Subtract(S)
    V2 (f subjects): Baseline(R) -> TMCT(S) -> Rest(R) -> Speeches(S) -> Rest(R)
                     -> Subtract(S)
    """
    segments = []

    if subject_id.startswith('S'):  # V1 protocol
        if len(tags) >= 13:
            segments.append({'start': tags[0], 'end': tags[3],
                            'label': 'REST', 'phase': 'Baseline'})
            segments.append({'start': tags[3], 'end': tags[4],
                            'label': 'STRESS', 'phase': 'Stroop'})
            segments.append({'start': tags[4], 'end': tags[5],
                            'label': 'REST', 'phase': 'First Rest'})
            segments.append({'start': tags[5], 'end': tags[6],
                            'label': 'STRESS', 'phase': 'TMCT'})
            segments.append({'start': tags[6], 'end': tags[7],
                            'label': 'REST', 'phase': 'Second Rest'})
            segments.append({'start': tags[7], 'end': tags[8],
                            'label': 'STRESS', 'phase': 'Real Opinion'})
            segments.append({'start': tags[8], 'end': tags[9],
                            'label': 'REST', 'phase': 'Transition Rest 1'})
            segments.append({'start': tags[9], 'end': tags[10],
                            'label': 'STRESS', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[10], 'end': tags[11],
                            'label': 'REST', 'phase': 'Transition Rest 2'})
            segments.append({'start': tags[11], 'end': tags[12],
                            'label': 'STRESS', 'phase': 'Subtract'})
    else:  # V2 protocol
        if len(tags) >= 10:
            segments.append({'start': tags[0], 'end': tags[2],
                            'label': 'REST', 'phase': 'Baseline'})
            segments.append({'start': tags[2], 'end': tags[3],
                            'label': 'STRESS', 'phase': 'TMCT'})
            segments.append({'start': tags[3], 'end': tags[4],
                            'label': 'REST', 'phase': 'First Rest'})
            segments.append({'start': tags[4], 'end': tags[5],
                            'label': 'STRESS', 'phase': 'Real Opinion'})
            segments.append({'start': tags[5], 'end': tags[6],
                            'label': 'REST', 'phase': 'Transition Rest'})
            segments.append({'start': tags[6], 'end': tags[7],
                            'label': 'STRESS', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[7], 'end': tags[8],
                            'label': 'REST', 'phase': 'Second Rest'})
            segments.append({'start': tags[8], 'end': tags[9],
                            'label': 'STRESS', 'phase': 'Subtract'})
    return segments


def get_cognitive_segments(subject_id, tags):
    """Get only COGNITIVE (stress task) segments — no REST.
    Used by Biomarker_Comparison for activity classification.

    V1 (S subjects): 14 tags, requires >= 13
    V2 (f subjects): 10 tags, requires >= 10
    """
    segments = []

    if subject_id.startswith('S'):  # V1 protocol (males, with Stroop)
        if len(tags) >= 13:
            segments.append({'start': tags[3], 'end': tags[4],
                            'label': 'COGNITIVE', 'phase': 'Stroop'})
            segments.append({'start': tags[5], 'end': tags[6],
                            'label': 'COGNITIVE', 'phase': 'TMCT'})
            segments.append({'start': tags[7], 'end': tags[8],
                            'label': 'COGNITIVE', 'phase': 'Real Opinion'})
            segments.append({'start': tags[9], 'end': tags[10],
                            'label': 'COGNITIVE', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[11], 'end': tags[12],
                            'label': 'COGNITIVE', 'phase': 'Subtract'})
    else:  # V2 protocol (females, no Stroop)
        if len(tags) >= 10:
            segments.append({'start': tags[2], 'end': tags[3],
                            'label': 'COGNITIVE', 'phase': 'TMCT'})
            segments.append({'start': tags[4], 'end': tags[5],
                            'label': 'COGNITIVE', 'phase': 'Real Opinion'})
            segments.append({'start': tags[6], 'end': tags[7],
                            'label': 'COGNITIVE', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[8], 'end': tags[9],
                            'label': 'COGNITIVE', 'phase': 'Subtract'})
    return segments


def get_aerobic_segments(subject_id, tags):
    """Get EXERCISE segments from aerobic protocol.

    V1 (S subjects): 13 tags, 10 cycling phases at 60-110 rpm
    V2 (f subjects): 9 tags, 5 cycling phases including long 85 rpm phase

    V2 phase labels use duration-based identification:
    - Short phases (~90-200s): 70, 75, 80, 90/95 rpm
    - Long phase (~675s): 85 rpm
    """
    segments = []

    if subject_id.startswith('S'):  # V1 protocol
        if len(tags) >= 12:
            rpm_phases = ['60 rpm', '70 rpm', '75 rpm', '80 rpm', '85 rpm',
                          '90 rpm', '95 rpm', '100 rpm', '105 rpm', '110 rpm']
            for i, phase_name in enumerate(rpm_phases):
                if i + 2 < len(tags):
                    segments.append({'start': tags[i + 1], 'end': tags[i + 2],
                                    'label': 'AEROBIC', 'phase': phase_name})
    else:  # V2 protocol - variable structure, use duration-based labeling
        if len(tags) >= 8:
            phase_labels = []
            for i in range(len(tags)-1):
                duration = tags[i+1] - tags[i]
                if 60 <= duration <= 250:
                    phase_labels.append(('short', i))
                elif 500 <= duration <= 800:
                    phase_labels.append(('long_85rpm', i))

            short_rpms = ['70 rpm', '75 rpm', '80 rpm', '90/95 rpm']
            short_idx = 0

            for phase_type, tag_idx in phase_labels:
                if phase_type == 'long_85rpm':
                    segments.append({'start': tags[tag_idx], 'end': tags[tag_idx+1],
                                    'label': 'AEROBIC',
                                    'phase': '85 rpm (sustained)'})
                elif phase_type == 'short' and short_idx < len(short_rpms):
                    segments.append({'start': tags[tag_idx], 'end': tags[tag_idx+1],
                                    'label': 'AEROBIC',
                                    'phase': short_rpms[short_idx]})
                    short_idx += 1
    return segments


def get_anaerobic_segments(subject_id, tags):
    """Get EXERCISE (sprint) segments from anaerobic protocol.

    Sprint durations are 28-40s.
    V1 (S subjects): 8 tags, 3 sprints
    V2 (f subjects): 12 tags, 4 sprints
    """
    segments = []

    if subject_id.startswith('S'):  # V1 protocol
        if len(tags) >= 7:
            segments.append({'start': tags[1], 'end': tags[2],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 1'})
            segments.append({'start': tags[3], 'end': tags[4],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 2'})
            segments.append({'start': tags[5], 'end': tags[6],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 3'})
    else:  # V2 protocol
        if len(tags) >= 11:
            segments.append({'start': tags[2], 'end': tags[3],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 1'})
            segments.append({'start': tags[4], 'end': tags[5],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 2'})
            segments.append({'start': tags[6], 'end': tags[7],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 3'})
            segments.append({'start': tags[8], 'end': tags[9],
                            'label': 'ANAEROBIC', 'phase': 'Sprint 4'})
    return segments


# ══════════════════════════════════════════════════════════════════════════════
# HRV CALCULATION
# ══════════════════════════════════════════════════════════════════════════════

def calculate_hrv(ibi_data, start_time, end_time):
    """Calculate HRV metrics from IBI data. Lower HRV = More Stress.
    IBI is derived from BVP (Blood Volume Pulse), NOT HR.
    """
    if len(ibi_data) == 0:
        return {'SDNN': np.nan, 'RMSSD': np.nan}
    timestamps = ibi_data[:, 0]
    ibi_values = ibi_data[:, 1]
    mask = (timestamps >= start_time) & (timestamps <= end_time)
    segment_ibi = ibi_values[mask]

    if len(segment_ibi) < 2:
        return {'SDNN': np.nan, 'RMSSD': np.nan}

    sdnn = np.std(segment_ibi)
    rmssd = np.sqrt(np.mean(np.diff(segment_ibi)**2))
    return {'SDNN': sdnn, 'RMSSD': rmssd}


# ══════════════════════════════════════════════════════════════════════════════
# FEATURE EXTRACTION (SLIDING WINDOWS — Essie's suggestion)
# ══════════════════════════════════════════════════════════════════════════════

def extract_windowed_features(subject, segment, signals, fs_dict,
                               window_sec=WINDOW_SIZE_SEC,
                               overlap=WINDOW_OVERLAP):
    """Extract features from sliding windows within a segment.

    Args:
        subject:    Subject ID (e.g., 'S01', 'f01')
        segment:    Dict with keys: start, end, label, phase
        signals:    Dict of signal arrays for this subject
        fs_dict:    Dict of sampling frequencies for each signal
        window_sec: Window size in seconds (default: 30)
        overlap:    Fraction of overlap (default: 0.5 = 50%)

    Returns:
        List of feature dicts, one per sliding window.
    """
    windows_features = []

    start_t, end_t = segment['start'], segment['end']
    step_sec = window_sec * (1 - overlap)

    window_start = start_t
    window_idx = 0

    while window_start + window_sec <= end_t:
        window_end = window_start + window_sec

        features = {
            'subject': subject,
            'label': segment['label'],
            'phase': segment['phase'],
            'window_idx': window_idx,
            'window_start': window_start,
            'window_end': window_end,
            'duration': window_sec
        }

        # HRV from IBI
        if 'IBI' in signals and len(signals['IBI']) > 0:
            hrv = calculate_hrv(signals['IBI'], window_start, window_end)
            features.update(hrv)
        else:
            features.update({'SDNN': np.nan, 'RMSSD': np.nan})

        # EDA
        if 'EDA' in signals:
            fs = fs_dict.get('EDA', 4)
            idx_start = int(window_start * fs)
            idx_end = int(window_end * fs)
            eda = signals['EDA'][idx_start:idx_end].flatten()
            if len(eda) > 0:
                features['EDA_mean'] = np.mean(eda)
                features['EDA_std'] = np.std(eda)

        # HR
        if 'HR' in signals:
            fs = fs_dict.get('HR', 1)
            idx_start = int(window_start * fs)
            idx_end = int(window_end * fs)
            hr = signals['HR'][idx_start:idx_end].flatten()
            if len(hr) > 0:
                features['HR_mean'] = np.mean(hr)
                features['HR_std'] = np.std(hr)
                features['HR_max'] = np.max(hr)

        # Temperature
        if 'TEMP' in signals:
            fs = fs_dict.get('TEMP', 4)
            idx_start = int(window_start * fs)
            idx_end = int(window_end * fs)
            temp = signals['TEMP'][idx_start:idx_end].flatten()
            if len(temp) > 0:
                features['TEMP_mean'] = np.mean(temp)
                features['TEMP_std'] = np.std(temp)

        # Accelerometer
        if 'ACC' in signals:
            fs = fs_dict.get('ACC', 32)
            idx_start = int(window_start * fs)
            idx_end = int(window_end * fs)
            acc = signals['ACC'][idx_start:idx_end]
            if len(acc) > 0:
                acc_filtered = moving_average(acc)
                features['ACC_mean'] = (np.mean(acc_filtered)
                                        if len(acc_filtered) > 0 else np.nan)
                features['ACC_std'] = (np.std(acc_filtered)
                                       if len(acc_filtered) > 0 else np.nan)

        windows_features.append(features)
        window_start += step_sec
        window_idx += 1

    return windows_features


# ══════════════════════════════════════════════════════════════════════════════
# PER-SUBJECT HRV IMPUTATION (Lev's suggestion)
# ══════════════════════════════════════════════════════════════════════════════

def per_subject_impute(df):
    """Fill missing SDNN/RMSSD with each subject's own mean.
    Falls back to global mean if a subject has ALL NaN.
    Preserves individual HRV variance (vs global mean which compresses it).
    """
    for col in ['SDNN', 'RMSSD']:
        if col in df.columns:
            df[col] = df.groupby('subject')[col].transform(
                lambda x: x.fillna(x.mean())
            )
            # Fallback for subjects with all NaN
            global_mean = df[col].mean()
            df[col] = df[col].fillna(global_mean)
    return df


# ══════════════════════════════════════════════════════════════════════════════
# BUILD DATASETS ON IMPORT
# ══════════════════════════════════════════════════════════════════════════════

print("Loading stress data...")

# Load stress labels
stress_level_v1 = pd.read_csv(_stress_level_v1_path, index_col=0)
stress_level_v2 = pd.read_csv(_stress_level_v2_path, index_col=0)
subject_info = pd.read_csv(_subject_info_path, index_col=0)

# ── Load signals from all 3 protocols ────────────────────────────────────────

print("  Loading STRESS protocol...")
_stress_signals, _stress_time, _stress_fs = read_signals(STRESS_PATH)

print("  Loading AEROBIC protocol...")
_aerobic_signals, _aerobic_time, _aerobic_fs = read_signals(AEROBIC_PATH)

print("  Loading ANAEROBIC protocol...")
_anaerobic_signals, _anaerobic_time, _anaerobic_fs = read_signals(ANAEROBIC_PATH)

# ── Build df_features: STRESS protocol (REST + STRESS), sliding windows ──────

_stress_features = []
for subject in _stress_signals.keys():
    tags = _stress_signals[subject]['tags']
    if len(tags) > 0:
        segments = get_stress_rest_segments(subject, tags)
        for segment in segments:
            window_features = extract_windowed_features(
                subject, segment, _stress_signals[subject],
                _stress_fs[subject]
            )
            _stress_features.extend(window_features)

df_features = pd.DataFrame(_stress_features)
# Add 'task' column as alias for 'phase' (backward compat with StressLevel_model)
df_features['task'] = df_features['phase']
df_features = per_subject_impute(df_features)

# ── Build df_activity: ALL 3 protocols (COGNITIVE, AEROBIC, ANAEROBIC) ───────

_activity_features = []

# COGNITIVE (stress tasks only, no REST)
for subject in _stress_signals.keys():
    tags = _stress_signals[subject]['tags']
    if len(tags) > 0:
        segments = get_cognitive_segments(subject, tags)
        for segment in segments:
            window_features = extract_windowed_features(
                subject, segment, _stress_signals[subject],
                _stress_fs[subject]
            )
            for feat in window_features:
                feat['activity_type'] = 'COGNITIVE'
            _activity_features.extend(window_features)

# AEROBIC
for subject in _aerobic_signals.keys():
    tags = _aerobic_signals[subject]['tags']
    if len(tags) > 0:
        segments = get_aerobic_segments(subject, tags)
        for segment in segments:
            window_features = extract_windowed_features(
                subject, segment, _aerobic_signals[subject],
                _aerobic_fs[subject]
            )
            for feat in window_features:
                feat['activity_type'] = 'AEROBIC'
            _activity_features.extend(window_features)

# ANAEROBIC
for subject in _anaerobic_signals.keys():
    tags = _anaerobic_signals[subject]['tags']
    if len(tags) > 0:
        segments = get_anaerobic_segments(subject, tags)
        for segment in segments:
            window_features = extract_windowed_features(
                subject, segment, _anaerobic_signals[subject],
                _anaerobic_fs[subject]
            )
            for feat in window_features:
                feat['activity_type'] = 'ANAEROBIC'
            _activity_features.extend(window_features)

df_activity = pd.DataFrame(_activity_features)
df_activity = per_subject_impute(df_activity)

# ── Summary ──────────────────────────────────────────────────────────────────

_n_stress = len(df_features)
_n_subjects_stress = df_features['subject'].nunique()
_n_activity = len(df_activity)
_n_subjects_activity = df_activity['subject'].nunique()
_missing_before = "imputed"  # already done above

print(f"\ndf_features (STRESS protocol):  {_n_stress} windows from "
      f"{_n_subjects_stress} subjects")
print(f"  Labels: {dict(df_features['label'].value_counts())}")
print(f"df_activity (ALL 3 protocols):  {_n_activity} windows from "
      f"{_n_subjects_activity} subjects")
print(f"  Activity types: {dict(df_activity['activity_type'].value_counts())}")
print(f"\nPreprocessing applied:")
print(f"  - Sliding windows: {WINDOW_SIZE_SEC}s, {WINDOW_OVERLAP*100:.0f}% overlap")
print(f"  - Per-subject HRV imputation (Lev's fix)")
print(f"  - Features: {ALL_FEATURES}")
print(f"  - Apple Watch features: {APPLE_WATCH_FEATURES}")
print(f"\nReady.")
