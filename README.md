# Digital Twin: Hybrid Stress Detection from Apple Watch

A hybrid stress detection system that uses a 3-stage pipeline to distinguish cognitive stress from physical exertion on Apple Watch. Stage 1 runs a CoreML Random Forest model (93.6% LOSO accuracy) to classify activity as physical or cognitive — filtering out exercise, which is not stress. Stage 2 applies sleep-adjusted HR thresholds to gate stress detection. Stage 3 computes a continuous stress score (0–100) using the validated DC/AC PRSA method (Bauer 2006) on HRV data. Scores drain a Garmin-inspired "Body Battery," which recharges through logged recovery activities. Built natively for Apple Watch using HealthKit, CoreML, and SwiftUI.

**Team:** Camille Tran, Dhyay Thakrar, Levy Sahoo, Essie Cheng, Selina Zhang
**Mentor:** Tauhidur Rahman
**Course:** DSC 180B Capstone, UC San Diego, Winter 2026

Code: https://github.com/Ctt011/Capstone-Behavorial
Website: [PhysioTwin](https://ctt011.github.io/Capstone-Behavorial/)

---

## Architecture

```
Apple Watch Data (HR, Steps, Sleep, HRV)
         |
   STAGE 1 (ML) — Activity Classifier (93.6% LOSO accuracy)
   CoreML Random Forest: PHYSICAL vs COGNITIVE
         |
    PHYSICAL ──→ Skip stress detection (exercise ≠ stress)
         |
    COGNITIVE ──→ STAGE 2 (Rules) — Sleep-adjusted threshold
                        |
                  STAGE 3 (Formulas) — DC/AC stress score 0-100
                        |
                  Body Battery drains based on score
                        |
                  Recovery activities suggested + tracked
```

---

## Getting Started

### Prerequisites

- Python 3.10+
- Xcode 15+ (for iOS app only)

### Setup

```bash
git clone https://github.com/Ctt011/Capstone-Behavorial.git
cd Capstone-Behavorial
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Running Experiments

**Reproduce Stage 1 model training + CoreML export:**
```bash
python src/pipeline/export_stage1_model.py
```
Expected output: 4 model files in `models/` (`.mlmodel`, `.pkl`, `.onnx`, `_preprocessing.json`). Console prints LOSO accuracy per fold and overall accuracy (~93.6%).

**Run the end-to-end pipeline walkthrough:**
```bash
jupyter notebook src/eval/Pipeline_Walkthrough.ipynb
```
Expected output: 34-cell notebook covering data loading → preprocessing → Stage 1 LOSO → Stage 2 sleep rules → Stage 3 DC/AC → Body Battery simulation. All figures render inline.

**Run the biomarker comparison analysis:**
```bash
jupyter notebook src/main_analysis_notebooks/Biomarker_Comparison.ipynb
```
Expected output: ANOVA results, confusion matrices, feature importance plots, 2-class and 3-class LOSO results.

**Verify Stage 1 accuracy (LOSO evaluation):**
```bash
python src/eval/run_evaluation.py
```
Expected output: 22-fold LOSO results with per-fold accuracy, overall accuracy (~93.6%), confusion matrix, and classification report. Pre-generated results are in `results/loso_evaluation.txt`.

To save results to a file:
```bash
python src/eval/run_evaluation.py --save results/loso_evaluation.txt
```

**Parse an Apple Health export:**
```bash
python src/pipeline/parse_apple_health.py
```
Expected output: CSVs for heart rate, SDNN, and sleep data extracted from `export.xml`.

**Run the iOS app:**
Open `digital_twin_app/DigitalTwin.xcodeproj` in Xcode. Requires Apple Watch simulator or paired device.

**Run unit tests:**
```bash
make test           # all tests (skips data tests if dataset absent)
make test-quick     # Stage 2 + Stage 3 only (no dataset needed)
```
Expected output: 47 tests pass covering sleep threshold rules, DC/AC stress formulas, HRV metrics, baseline learning, and edge cases.

---

## File Guide

### Pipeline Scripts (src/pipeline/)

| File | What It Does |
|------|-------------|
| `export_stage1_model.py` | Trains Activity Classifier on WISE data, exports to `models/`. Run this to regenerate the model. |
| `stage3_stress_formulas.py` | DC/AC PRSA formulas for stress scoring (0-100). Python reference implementation. |
| `stage2_sleep_rules.py` | Sleep quality threshold adjustment rules. Python reference implementation. |
| `parse_apple_health.py` | Parses Apple Health `export.xml` into CSVs (HR, SDNN, Sleep). |
| `preprocess_wise.py` | Single source of truth for WISE data preprocessing. Imported by all notebooks. |
| `run_stage2_fitbit.py` | PMData/Fitbit validation script for Stage 2 sleep scoring. |
| `run_evaluation.py` | Reproduces Stage 1 LOSO evaluation (93.6%). Saves results to `results/`. |

### Trained Models (`src/models/`)

| File | What It Does |
|------|-------------|
| `ActivityClassifier.mlmodel` | CoreML Random Forest model (528KB). 4 features: HR_mean, HR_std, ACC_mean, ACC_std. 93.6% LOSO. |
| `ActivityClassifier.pkl` | Serialized sklearn pipeline for Python testing. |
| `ActivityClassifier.onnx` | ONNX format (cross-platform). |
| `ActivityClassifier_preprocessing.json` | StandardScaler parameters (means + stds) for feature preprocessing in Swift. |

### iOS App (`digital_twin_app/DigitalTwin/`)

| File | What It Does |
|------|--------------|
| `ActivityClassifier.mlmodel` | CoreML model (copy for Xcode) |
| `ActivityClassifier_preprocessing.json` | Preprocessing params (copy for Xcode) |
| `StressDetectionPipeline.swift` | 3-stage hybrid pipeline (copy for Xcode) |
| `BodyBatteryView.swift` | Body Battery system — drain, recharge, 30-day history, recovery activities |
| `ActivityManager.swift` | Activity logging (Aerobic, Anaerobic, Cognitive) |
| `HealthKitManager.swift` | HealthKit queries: HR, HRV, Steps, Sleep, workout sessions |
| `ContentView.swift` | Dashboard: battery preview, insights, forecast, heart rate, steps, HRV, sleep |
| `AddActivityView.swift` | UI for logging activities |
| `DigitalTwinApp.swift` | App entry point |

### Analysis Notebooks (`src/main_analysis_notebooks/`)

| File | What It Does |
|------|-------------|
| `Biomarker_Comparison.ipynb` | Stage 1 analysis: 3-way biomarker comparison (Cognitive vs Aerobic vs Anaerobic), LOSO validation, 2-class vs 3-class |
| `StressLevel_model.ipynb` | Stage 2 stress regression (LassoCV, R²=-0.035). Documents why pure ML regression fails on N=22. |
| `WISE_Stress_EDA_Model.ipynb` | Original binary stress classifier (77.1% CV). Q1 work. |
| `AerobicModel.ipynb` | Aerobic exercise classifier |
| `AnaerobicModel.ipynb` | Anaerobic exercise classifier |
| `CognitiveModel.ipynb` | Cognitive stress model |
| `_setup.py` | Path helper — auto-configures CWD and sys.path so notebooks work from the subdirectory |

### Shared Preprocessing (`src/pipeline/`)

| File | What It Does |
|------|-------------|
| `preprocess_wise.py` | Single source of truth for all WISE data preprocessing. Signal loading, segmentation, sliding windows (30s, 50% overlap), per-subject HRV imputation. Imported by all notebooks. |

### Data (`data/`)

| Directory | Contents |
|-----------|----------|
| `22subjects/` | Raw WISE data — 22 subjects, each with ACC, BVP, EDA, HR, IBI, TEMP CSVs |
| `WISE_data_files/` | Dataset metadata: stress labels (v1, v2), subject info, data dictionary |

### Reports (`reports/`)

| Directory | Contents |
|-----------|----------|
| `Q1_report/` | Quarter 1 LaTeX report (submitted Dec 2025) |
| `Q2_report/` | Quarter 2 LaTeX report (in progress) |

---

## Dataset

**WISE (Wearable Stress & Exercise)** — 22 subjects, Empatica E4 wearable.

Download: https://physionet.org/content/wearable-exam-stress/1.0.0/

Each participant completed 3 sessions:
1. **Cognitive stress** — Stroop test, TMCT (mental math)
2. **Aerobic exercise** — Steady cycling (70-110 RPM)
3. **Anaerobic exercise** — Sprint intervals

Signals: EDA, HR, HRV (IBI), TEMP, ACC (3-axis), BVP at up to 64 Hz.

### Participant IDs
- `Sxx` — Male participants (Stage 1 protocol)
- `fxx` — Female participants (Stage 2 protocol)

### Empatica E4 File Format
```
Row 1 → Session start time (UTC)
Row 2 → Sampling frequency (Hz)
Row 3+ → Sensor values
```

---

## Key Results

| Component | Result | Method |
|-----------|--------|--------|
| Activity Classifier (Stage 1) | **93.6% LOSO** | Random Forest, 4 features, 22-fold Leave-One-Subject-Out |
| Stress Regression (attempted) | R²=-0.035 | LassoCV — worse than mean prediction, consistent with literature (Velmovitsky 2022: 55-64% with N=33) |
| Binary Stress Classifier (attempted) | F1=0.46 | Predicts mostly REST due to class imbalance (87:13) |
| DC/AC Stress Formulas (Stage 3) | Implemented | Bauer 2006 PRSA method, validated on WISE IBI data |

---

## Directory Structure

```
Capstone-Behavioral/
├── .github/
│   └── workflows/
│       └── test.yml                      # CI — runs tests on push/PR
├── data/   
│   ├── 22subjects/                       # Raw WISE dataset (22 subjects × 6 signals)
│   └── WISE_data_files/                  # Dataset metadata (labels, data dictionary)
├── digital_twin_app/                     # iOS app (SwiftUI + HealthKit + CoreML)
├── digital_twin_app/ 
│   ├── Q1_report/                        # Quarter 1 LaTeX report
│   └── Q2_report/                        # Quarter 2 LaTeX report + figures
├── src/
│   ├── eval/
│   │   ├── results/                      # Evaluation outputs (LOSO results & PMData sleep validation noteboom)
│   │   ├── Pipeline_Walkthrough.ipynb    # End-to-end pipeline tutorial (34 cells)
│   │   ├── run_evaluation.py             # Stage 1 LOSO evaluation script
│   │   └── run_stage2_fitbit.py          # PMData/Fitbit validation
│   │
│   ├── main_analysis_notebooks/          # Analysis notebooks (Stage 1, Stage 2, EDA)
│   │
│   ├── models/                           # Trained models (CoreML, sklearn, ONNX)
│   │   ├── ActivityClassifier.mlmodel
│   │   ├── ActivityClassifier.onnx
│   │   ├── ActivityClassifier.pkl
│   │   └── ActivityClassifier_preprocessing.pkl
│   │
│   └── pipeline/
│       ├── export_stage1_model.py        # Stage 1 model training + export
│       ├── parse_apple_health.py         # Apple Health XML parser
│       ├── preprocess_wise.py            # Preprocessing (imported by all notebooks)
│       ├── stage2_sleep_rules.py         # Stage 2 sleep threshold rules
│       └── stage3_stress_formulas.py     # Stage 3 DC/AC stress formulas
│
├── tests/                                # Unit tests (pytest) — 47 tests
├── website/website_page_files            # Website assets (images, SVG, style guide)          
│
├── README.md
├── index.html                            # Project website
└── requirements.txt                      # Python dependencies (pinned versions)

```

---

## References

1. Velmovitsky et al. (2022) — Apple Watch stress detection, N=33, 55-64% accuracy
2. Bonneval et al. (2025) — Apple Watch HRV validation: 1.15% error at rest, 93% during movement
3. Hernando et al. (2018) — Apple Watch RR intervals, SDNN robust to data gaps
4. Bahameish & Stockman — Stress vs Neutral F1=56%, Stress vs Relaxation F1=89%
5. Apple (2024) — Behavioral Foundation Model: sleep + sensor fusion improves predictions
6. Bauer et al. (2006) — PRSA method for Deceleration/Acceleration Capacity




