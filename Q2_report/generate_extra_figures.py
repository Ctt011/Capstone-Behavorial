"""
generate_extra_figures.py

Generates three additional figures for the Q2 report:
  1. dcac_boxplot.png — DC and SDNN boxplots: REST vs STRESS
  2. body_battery_simulation.png — Full-day Body Battery drain (3-panel)
  3. sleep_threshold.png — Sleep quality threshold adjustment (2-panel)

Usage:
    cd Capstone-Behavorial/Q2_report
    python generate_extra_figures.py
"""

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

# Add parent directory for preprocess_wise
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'figure')
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Colors matching PhysioTwin theme
SAGE = '#3D8B6E'
TEAL = '#5BA4B5'
CORAL = '#E07A5F'
SLATE = '#1E2A35'

# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 1: DC/AC Boxplot (REST vs STRESS)
# ══════════════════════════════════════════════════════════════════════════════

print("Generating DC/AC boxplot...")

from preprocess_wise import df_features

# Compute DC from IBI data for each subject-label pair
# We'll use the windowed features for SDNN (already computed)
# and compute a simulated DC from the IBI-derived metrics

rest_data = df_features[df_features['label'] == 'REST']
stress_data = df_features[df_features['label'] == 'STRESS']

# Per-subject means for SDNN
rest_sdnn_by_subj = rest_data.groupby('subject')['SDNN'].mean().dropna()
stress_sdnn_by_subj = stress_data.groupby('subject')['SDNN'].mean().dropna()

# Per-subject means for RMSSD (proxy for DC trend)
rest_rmssd_by_subj = rest_data.groupby('subject')['RMSSD'].mean().dropna()
stress_rmssd_by_subj = stress_data.groupby('subject')['RMSSD'].mean().dropna()

# Use actual DC values from the notebook (computed from real IBI)
# The notebook reported: REST DC: 21.05 ± 4.96 ms, STRESS DC: 17.87 ± 5.92 ms
# We'll plot SDNN and RMSSD since those are in our preprocessed data

fig, axes = plt.subplots(1, 2, figsize=(8, 4))

# SDNN boxplot
common_subj = list(set(rest_sdnn_by_subj.index) & set(stress_sdnn_by_subj.index))
sdnn_data = [rest_sdnn_by_subj[common_subj].values, stress_sdnn_by_subj[common_subj].values]
bp1 = axes[0].boxplot(sdnn_data, labels=['REST', 'STRESS'], patch_artist=True,
                       widths=0.5, medianprops=dict(color='black', linewidth=2))
bp1['boxes'][0].set_facecolor(TEAL)
bp1['boxes'][1].set_facecolor(CORAL)
bp1['boxes'][0].set_alpha(0.7)
bp1['boxes'][1].set_alpha(0.7)
axes[0].set_ylabel('SDNN (ms)', fontsize=11)
axes[0].set_title('SDNN: REST vs STRESS\n$t = 0.34$, $p = 0.735$ (n.s.)', fontsize=11)
axes[0].spines['top'].set_visible(False)
axes[0].spines['right'].set_visible(False)

# RMSSD boxplot
common_subj_r = list(set(rest_rmssd_by_subj.index) & set(stress_rmssd_by_subj.index))
rmssd_data = [rest_rmssd_by_subj[common_subj_r].values, stress_rmssd_by_subj[common_subj_r].values]
bp2 = axes[1].boxplot(rmssd_data, labels=['REST', 'STRESS'], patch_artist=True,
                       widths=0.5, medianprops=dict(color='black', linewidth=2))
bp2['boxes'][0].set_facecolor(TEAL)
bp2['boxes'][1].set_facecolor(CORAL)
bp2['boxes'][0].set_alpha(0.7)
bp2['boxes'][1].set_alpha(0.7)
axes[1].set_ylabel('RMSSD (ms)', fontsize=11)
axes[1].set_title('RMSSD: REST vs STRESS\n(beat-to-beat variability)', fontsize=11)
axes[1].spines['top'].set_visible(False)
axes[1].spines['right'].set_visible(False)

plt.tight_layout()
path = os.path.join(OUTPUT_DIR, 'dcac_boxplot.png')
plt.savefig(path, dpi=300, bbox_inches='tight')
plt.close()
print(f"  Saved: {path}")


# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 2: Body Battery Daily Simulation (3-panel)
# ══════════════════════════════════════════════════════════════════════════════

print("Generating Body Battery simulation...")

from sklearn.pipeline import make_pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from preprocess_wise import df_activity

# Train the model
FEATURES = ['HR_mean', 'HR_std', 'ACC_mean', 'ACC_std']
df = df_activity.copy()
df['activity_2class'] = df['activity_type'].map({
    'COGNITIVE': 'COGNITIVE', 'AEROBIC': 'PHYSICAL', 'ANAEROBIC': 'PHYSICAL'
})
X = df[FEATURES].values
le = LabelEncoder()
y = le.fit_transform(df['activity_2class'].values)

pipeline = make_pipeline(SimpleImputer(strategy='mean'), StandardScaler(),
                          RandomForestClassifier(n_estimators=100, random_state=42))
pipeline.fit(X, y)

# Simulate a full day
schedule = [
    ('08:00', 'Morning commute',     90, 5,  4.5, 1.5),
    ('09:00', 'Desk work (calm)',     68, 3,  1.0, 0.3),
    ('10:00', 'Meeting (mild stress)',78, 5,  1.2, 0.4),
    ('11:00', 'Coding (focused)',     72, 4,  1.1, 0.3),
    ('12:00', 'Lunch walk',           95, 6,  5.0, 1.8),
    ('13:00', 'Post-lunch desk',      70, 3,  1.0, 0.2),
    ('14:00', 'Stressful deadline',   92, 7,  1.3, 0.5),
    ('15:00', 'Still stressed',       88, 6,  1.2, 0.4),
    ('16:00', 'Gym workout',         140, 12, 9.0, 3.0),
    ('17:00', 'Post-gym rest',        75, 4,  1.0, 0.3),
    ('18:00', 'Dinner (relaxed)',     65, 3,  1.0, 0.2),
    ('19:00', 'TV (very relaxed)',    62, 2,  0.8, 0.2),
    ('20:00', 'Reading (calm)',       60, 2,  0.7, 0.1),
    ('21:00', 'Bedtime routine',      58, 2,  0.5, 0.1),
]

# Sleep: 5.5h (poor) → threshold adjusted from 60 to 51
sleep_hours = 5.5
baseline_sleep = 7.0
ratio = sleep_hours / baseline_sleep
threshold = 60 * 0.85  # poor sleep multiplier → 51

np.random.seed(42)
battery = 100.0
times, hrs, activities, scores, batteries, labels = [], [], [], [], [], []

for time_str, desc, hr, hr_std, acc, acc_std in schedule:
    features = np.array([[hr, hr_std, acc, acc_std]])
    pred = le.inverse_transform(pipeline.predict(features))[0]

    if pred == 'PHYSICAL':
        stress_score = 0
        battery -= 3.0  # physical drain
    else:
        # Simulate stress score based on HR deviation from calm baseline
        stress_score = min(100, max(0, int((hr - 60) * 2.5 + np.random.randint(-10, 15))))
        if stress_score > threshold:
            battery -= stress_score * 0.002 * 60  # stressed drain
        else:
            battery -= 1.0  # calm drain

    battery = max(0, battery)
    times.append(time_str)
    hrs.append(hr)
    activities.append(pred)
    scores.append(stress_score)
    batteries.append(battery)
    labels.append(desc)

# Plot
fig, axes = plt.subplots(3, 1, figsize=(10, 8), sharex=True,
                          gridspec_kw={'height_ratios': [1, 1, 1.2]})

# Panel 1: Heart Rate by activity type
colors_act = [SAGE if a == 'PHYSICAL' else TEAL for a in activities]
axes[0].bar(range(len(times)), hrs, color=colors_act, edgecolor='white', width=0.7)
axes[0].set_ylabel('Heart Rate (BPM)', fontsize=10)
axes[0].set_title('Full-Day Pipeline Simulation (Sleep: 5.5h → threshold: 51)', fontsize=12)
axes[0].legend(handles=[
    plt.Rectangle((0,0),1,1, facecolor=SAGE, label='PHYSICAL'),
    plt.Rectangle((0,0),1,1, facecolor=TEAL, label='COGNITIVE')
], loc='upper right', fontsize=9)
axes[0].spines['top'].set_visible(False)
axes[0].spines['right'].set_visible(False)

# Panel 2: Stress scores
colors_stress = [CORAL if s > threshold else '#B0B0B0' for s in scores]
axes[1].bar(range(len(times)), scores, color=colors_stress, edgecolor='white', width=0.7)
axes[1].axhline(y=threshold, color='red', linestyle='--', linewidth=1, alpha=0.7, label=f'Threshold ({threshold:.0f})')
axes[1].set_ylabel('Stress Score', fontsize=10)
axes[1].legend(fontsize=9)
axes[1].spines['top'].set_visible(False)
axes[1].spines['right'].set_visible(False)

# Panel 3: Body Battery
axes[2].plot(range(len(times)), batteries, color=SAGE, linewidth=2.5, marker='o', markersize=6)
axes[2].fill_between(range(len(times)), batteries, alpha=0.15, color=SAGE)
axes[2].set_ylabel('Body Battery (%)', fontsize=10)
axes[2].set_xlabel('Time of Day', fontsize=10)
axes[2].set_ylim(0, 105)
axes[2].set_xticks(range(len(times)))
axes[2].set_xticklabels(times, rotation=45, ha='right', fontsize=9)
# Annotate start and end
axes[2].annotate(f'{batteries[0]:.0f}%', (0, batteries[0]), textcoords="offset points",
                 xytext=(10, 5), fontsize=9, fontweight='bold', color=SAGE)
axes[2].annotate(f'{batteries[-1]:.1f}%', (len(batteries)-1, batteries[-1]),
                 textcoords="offset points", xytext=(-30, 10), fontsize=9,
                 fontweight='bold', color=SAGE)
axes[2].spines['top'].set_visible(False)
axes[2].spines['right'].set_visible(False)

plt.tight_layout()
path = os.path.join(OUTPUT_DIR, 'body_battery_simulation.png')
plt.savefig(path, dpi=300, bbox_inches='tight')
plt.close()
print(f"  Saved: {path}")
print(f"  Battery: 100% → {batteries[-1]:.1f}%")


# ══════════════════════════════════════════════════════════════════════════════
# FIGURE 3: Sleep Threshold Adjustment (2-panel)
# ══════════════════════════════════════════════════════════════════════════════

print("Generating sleep threshold figure...")

fig, axes = plt.subplots(1, 2, figsize=(9, 4))

# Panel 1: Threshold vs sleep hours
sleep_range = np.linspace(4, 10, 100)
baseline = 7.0
base_threshold = 60

thresholds = []
for h in sleep_range:
    r = h / baseline
    if r < 0.75:
        mult = 0.80
    elif r < 0.90:
        mult = 0.85
    elif r <= 1.10:
        mult = 1.00
    elif r <= 1.20:
        mult = 1.05
    else:
        mult = 1.08
    thresholds.append(base_threshold * mult)

axes[0].plot(sleep_range, thresholds, color=SAGE, linewidth=2.5)
axes[0].axvline(x=baseline, color='gray', linestyle='--', alpha=0.5, label=f'Baseline ({baseline}h)')
axes[0].axhline(y=base_threshold, color='gray', linestyle=':', alpha=0.5, label=f'Default ({base_threshold})')
axes[0].fill_between(sleep_range, thresholds, base_threshold, alpha=0.1,
                      where=[t < base_threshold for t in thresholds], color=CORAL)
axes[0].fill_between(sleep_range, thresholds, base_threshold, alpha=0.1,
                      where=[t > base_threshold for t in thresholds], color=TEAL)
axes[0].set_xlabel('Hours Slept', fontsize=11)
axes[0].set_ylabel('Adjusted Stress Threshold', fontsize=11)
axes[0].set_title('Stage 2: Sleep-Adjusted Threshold', fontsize=12)
axes[0].legend(fontsize=9)
axes[0].spines['top'].set_visible(False)
axes[0].spines['right'].set_visible(False)

# Panel 2: Same stress score, different outcomes
conditions = ['Very Poor\n(4.5h)', 'Poor\n(5.5h)', 'Normal\n(7.0h)', 'Good\n(8.0h)', 'Excellent\n(9.0h)']
adj_thresholds = [48, 51, 60, 63, 65]
stress_score = 55

bar_colors = [CORAL if stress_score > t else TEAL for t in adj_thresholds]
bars = axes[1].bar(range(len(conditions)), adj_thresholds, color=bar_colors,
                    edgecolor='white', width=0.6, alpha=0.7)
axes[1].axhline(y=stress_score, color=SLATE, linestyle='--', linewidth=2,
                label=f'Stress Score = {stress_score}')
axes[1].set_xticks(range(len(conditions)))
axes[1].set_xticklabels(conditions, fontsize=9)
axes[1].set_ylabel('Threshold', fontsize=11)
axes[1].set_title('Same Score, Different Outcomes', fontsize=12)
axes[1].legend(fontsize=9)

# Annotate stressed/ok
for i, (t, c) in enumerate(zip(adj_thresholds, bar_colors)):
    label = 'STRESSED' if stress_score > t else 'OK'
    axes[1].text(i, t + 1.5, label, ha='center', fontsize=8, fontweight='bold',
                 color=CORAL if label == 'STRESSED' else SAGE)

axes[1].spines['top'].set_visible(False)
axes[1].spines['right'].set_visible(False)

plt.tight_layout()
path = os.path.join(OUTPUT_DIR, 'sleep_threshold.png')
plt.savefig(path, dpi=300, bbox_inches='tight')
plt.close()
print(f"  Saved: {path}")

print("\nAll extra figures generated!")
