"""
load_stress_data.py

Loads and preprocesses all WISE stress study data:
  - stress_level_v1: Self-reported stress scores (V1 / male subjects)
  - stress_level_v2: Self-reported stress scores (V2 / female subjects)
  - df_features: Extracted physiological features per segment

Usage:
    from load_stress_data import stress_level_v1, stress_level_v2, df_features
"""

import os
import datetime
import numpy as np
import pandas as pd

# ── File paths ────────────────────────────────────────────────────────────────
_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

dataset_path = os.path.join(_BASE_DIR, "22subjects", "STRESS")
stress_level_v1_path = os.path.join(_BASE_DIR, "WISE_data_files", "Stress_Level_v1.csv")
stress_level_v2_path = os.path.join(_BASE_DIR, "WISE_data_files", "Stress_Level_v2.csv")
subject_info_path = os.path.join(_BASE_DIR, "WISE_data_files", "subject-info.csv")


# ── Helper functions ──────────────────────────────────────────────────────────

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
    Higher values = more movement, Lower values = less movement
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


# ── Signal loading ────────────────────────────────────────────────────────────

def read_signals(main_folder):
    """
    Each subject folder contains: EDA, BVP, HR, IBI, TEMP, ACC, tags
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

        desired_files = ['EDA.csv', 'BVP.csv', 'HR.csv', 'TEMP.csv', 'tags.csv', 'ACC.csv', 'IBI.csv']

        for file_name in files:
            if file_name not in desired_files:
                continue

            file_path = os.path.join(folder_path, file_name)
            signal_name = file_name.replace('.csv', '')

            if file_name == 'tags.csv':
                try:
                    df = pd.read_csv(file_path, header=None)
                    tags_vector = create_df_array(df)
                    tags_UTC_vector = np.insert(tags_vector, 0, utc_start_dict[folder_name])
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
                time_array = np.linspace(0, len(signal_array)/fs, len(signal_array))

                time_line[signal_name] = time_array
                fs_signal[signal_name] = fs

            signals[signal_name] = signal_array

        signal_dict[folder_name] = signals
        time_dict[folder_name] = time_line
        fs_dict[folder_name] = fs_signal

    return signal_dict, time_dict, fs_dict


# ── Segmentation ──────────────────────────────────────────────────────────────

def get_stress_rest_segments(subject_id, tags):
    """
    V1: Baseline(R) -> Stroop(S) -> Rest(R) -> TMCT(S) -> Rest(R) -> Speeches(S) -> Subtract(S)
    V2: Baseline(R) -> TMCT(S) -> Rest(R) -> Speeches(S) -> Rest(R) -> Subtract(S)
    """
    segments = []

    if subject_id.startswith('S'):  # V1 protocol
        if len(tags) >= 13:
            segments.append({'start': tags[0], 'end': tags[3], 'label': 'REST', 'phase': 'Baseline'})
            segments.append({'start': tags[3], 'end': tags[4], 'label': 'STRESS', 'phase': 'Stroop'})
            segments.append({'start': tags[4], 'end': tags[5], 'label': 'REST', 'phase': 'First Rest'})
            segments.append({'start': tags[5], 'end': tags[6], 'label': 'STRESS', 'phase': 'TMCT'})
            segments.append({'start': tags[6], 'end': tags[7], 'label': 'REST', 'phase': 'Second Rest'})
            segments.append({'start': tags[7], 'end': tags[8], 'label': 'STRESS', 'phase': 'Real Opinion'})
            segments.append({'start': tags[8], 'end': tags[9], 'label': 'REST', 'phase': 'Transition Rest 1'})
            segments.append({'start': tags[9], 'end': tags[10], 'label': 'STRESS', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[10], 'end': tags[11], 'label': 'REST', 'phase': 'Transition Rest 2'})
            segments.append({'start': tags[11], 'end': tags[12], 'label': 'STRESS', 'phase': 'Subtract'})

    else:  # V2 protocol
        if len(tags) >= 10:
            segments.append({'start': tags[0], 'end': tags[2], 'label': 'REST', 'phase': 'Baseline'})
            segments.append({'start': tags[2], 'end': tags[3], 'label': 'STRESS', 'phase': 'TMCT'})
            segments.append({'start': tags[3], 'end': tags[4], 'label': 'REST', 'phase': 'First Rest'})
            segments.append({'start': tags[4], 'end': tags[5], 'label': 'STRESS', 'phase': 'Real Opinion'})
            segments.append({'start': tags[5], 'end': tags[6], 'label': 'REST', 'phase': 'Transition Rest'})
            segments.append({'start': tags[6], 'end': tags[7], 'label': 'STRESS', 'phase': 'Opposite Opinion'})
            segments.append({'start': tags[7], 'end': tags[8], 'label': 'REST', 'phase': 'Second Rest'})
            segments.append({'start': tags[8], 'end': tags[9], 'label': 'STRESS', 'phase': 'Subtract'})

    return segments


# ── HRV calculation ───────────────────────────────────────────────────────────

def calculate_hrv(ibi_data, start_time, end_time):
    """Calculate HRV: Lower HRV = More Stress"""
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


# ── Feature extraction ────────────────────────────────────────────────────────

def extract_segment_features(subject, segment, signals, fs_dict_subj):
    """Extract all biomarkers for one segment"""
    features = {
        'subject': subject,
        'label': segment['label'],
        'task': segment['phase'],
        'duration': segment['end'] - segment['start']
    }

    start_t, end_t = segment['start'], segment['end']

    # HRV
    if 'IBI' in signals and len(signals['IBI']) > 0:
        hrv = calculate_hrv(signals['IBI'], start_t, end_t)
        features.update(hrv)
    else:
        features.update({'SDNN': np.nan, 'RMSSD': np.nan})

    # EDA
    if 'EDA' in signals:
        fs = fs_dict_subj['EDA']
        idx_start, idx_end = int(start_t * fs), int(end_t * fs)
        eda = signals['EDA'][idx_start:idx_end].flatten()
        features['EDA_mean'] = np.mean(eda)
        features['EDA_std'] = np.std(eda)
        features['EDA_max'] = np.max(eda)

    # HR
    if 'HR' in signals:
        fs = fs_dict_subj['HR']
        idx_start, idx_end = int(start_t * fs), int(end_t * fs)
        hr = signals['HR'][idx_start:idx_end].flatten()
        features['HR_mean'] = np.mean(hr)
        features['HR_std'] = np.std(hr)
        features['HR_max'] = np.max(hr)

    # Temperature
    if 'TEMP' in signals:
        fs = fs_dict_subj['TEMP']
        idx_start, idx_end = int(start_t * fs), int(end_t * fs)
        temp = signals['TEMP'][idx_start:idx_end].flatten()
        features['TEMP_mean'] = np.mean(temp)
        features['TEMP_std'] = np.std(temp)

    # Accelerometer
    if 'ACC' in signals:
        fs = fs_dict_subj['ACC']
        idx_start, idx_end = int(start_t * fs), int(end_t * fs)
        acc = signals['ACC'][idx_start:idx_end]
        acc_filtered = moving_average(acc)
        features['ACC_mean'] = np.mean(acc_filtered)
        features['ACC_std'] = np.std(acc_filtered)

    return features


# ── Run the full pipeline on import ──────────────────────────────────────────

print("Loading stress data...")

# Load stress labels
stress_level_v1 = pd.read_csv(stress_level_v1_path, index_col=0)
stress_level_v2 = pd.read_csv(stress_level_v2_path, index_col=0)
subject_info = pd.read_csv(subject_info_path, index_col=0)

# Load physiological signals
signal_data, time_data, _fs_dict = read_signals(dataset_path)
subjects = list(signal_data.keys())

# Segment signals
all_segments = {}
for subject in subjects:
    tags = signal_data[subject]['tags']
    if len(tags) > 0:
        segments = get_stress_rest_segments(subject, tags)
        all_segments[subject] = segments

# Extract features
all_features = []
for subject in subjects:
    if subject in all_segments:
        for segment in all_segments[subject]:
            feat = extract_segment_features(subject, segment, signal_data[subject], _fs_dict[subject])
            all_features.append(feat)

df_features = pd.DataFrame(all_features)

print(f"Loaded {len(df_features)} segments from {len(subjects)} subjects")
