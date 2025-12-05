#  Cognitive Behavioral Stress Prediction  
Multimodal physiological dataset (Empatica E4) + curated metadata + stress labels used for modeling cognitive and physical stress responses, and developing personalized digital-twin systems.

---

##  Getting Started

###  Prerequisites

Install required Python packages:

```bash
pip install pandas numpy matplotlib
```

To view notebooks, you will also need **Jupyter**:

```bash
pip install notebook
```

---

##  Dataset Description

This dataset is based on the **WISE Wearable Stress & Exercise Dataset**, combined with cleaned metadata and stress-level labels. It contains synchronized, high-resolution physiological measurements:

- Electrodermal Activity (EDA)  
- Heart Rate (HR)  
- Skin Temperature (TEMP)  
- Accelerometer Data (ACC, 3-axis)  
- Blood Volume Pulse (BVP)  
- Inter-Beat Intervals (IBI)

After filtering corrupted or incomplete sessions, **22 participants** remain in the cleaned dataset.

---

## Running the analysis

To reproduce our analysis on DSMLP or any Python environment:

    python main.py

This will execute `WISE_Stress_EDA_Model.ipynb` and save a fully executed version
as `WISE_Stress_EDA_Model_executed.ipynb`.

---

##  Directory Structure

```
Capstone-Behavorial/
│
├── main.py                        # Entry-point script (DSMLP compatible)
├── WISE_Stress_EDA_Model.ipynb    # Main analysis + model notebook
├── stress_v1.png                  # Protocol V1 visualization
├── stress_v2.png                  # Protocol V2 visualization
│
├── 22subjects/                    # Raw data (22 subjects who completed all 3 tests)
│   └── STRESS/
│       └── S04/, S05/, S08/, f01/, f02/, ...
│
├── WISE_data_files/               # Original dataset files from PhysioNet
│   ├── Data_Dictionary.csv
│   ├── LICENSE.txt
│   ├── Stress_Level_v1.csv       # Self-reported stress labels (V1)
│   ├── Stress_Level_v2.csv       # Self-reported stress labels (V2)
│   ├── subject-info.csv          # Participant metadata
│   ├── data_constraints.txt      # Data quality notes
│   └── Wearable_Dataset.ipynb    # Original dataset exploration
│
├── notebook_drafts/               # Exploratory/draft notebooks
│   ├── EDA-Levy.ipynb
│   ├── EDA_pmdata_draft.ipynb
│   └── WISE statistical analysis & eda.ipynb
│
├── Q1_report/                     # Quarter 1 LaTeX report
└── Q2_report/                     # Quarter 2 LaTeX report
```

### Participant ID Format  
- Men participants → `Sxx` → Stage 1  
- Women participants → `fxx` → Stage 2  

---

##  Files

### Stress-Level Files
Located in `WISE_data_files/`:
- **Stress_Level_v1.csv** — Self-reported stress labels (Stage 1)
- **Stress_Level_v2.csv** — Self-reported stress labels (Stage 2)

###  Participant Metadata
File: `WISE_data_files/subject-info.csv`
Includes:
- Age
- Gender
- Height
- Weight
- Physical activity regularity
- Protocol version

###  Data Quality Notes
File: `WISE_data_files/data_constraints.txt`
Includes:
- Incorrect wristband placement
- Signal dropout
- Misaligned timestamps
- Incomplete protocols

###  Original Dataset Notebook
File: `WISE_data_files/Wearable_Dataset.ipynb`
Provides:
- Signal visualization examples
- Code for loading + aligning physiological streams
- Event segmentation helpers  

---

##  Physiological Signal Files

Each participant folder contains:

| File | Description |
|------|-------------|
| **ACC.csv** | Accelerometer (x, y, z), unit = 1/64 g |
| **BVP.csv** | Photoplethysmography waveform |
| **EDA.csv** | Skin conductance (µS) |
| **TEMP.csv** | Skin temperature (°C) |
| **HR.csv** | Heart rate extracted from BVP |
| **IBI.csv** | Inter-beat intervals (timestamp + duration) |
| **tags.csv** | Event markers |

###  Empatica E4 File Format (Important)

All E4 sensor files follow this structure:

```
Row 1 → Session start time (UTC)
Row 2 → Sampling frequency (Hz)
Row 3+ → Sensor values
```

This ensures correct cross-signal alignment.

---

##  Stress-Level Labels

These files provide ground-truth stress labels for modeling:

- `WISE_data_files/Stress_Level_v1.csv` — Stage 1 (Sxx)
- `WISE_data_files/Stress_Level_v2.csv` — Stage 2 (fxx)  

---

##  Subject Metadata

Included in `WISE_data_files/subject-info.csv`:

- Age  
- Gender  
- Height  
- Weight  
- Physical activity habits  
- Protocol version (V1 / V2)

---

##  Session Types

Each participant completed **three controlled laboratory sessions**:

### 1.  Stress-Induced Cognitive Tasks  
Tasks designed to trigger mental stress using cognitive load.

### 2.  Aerobic Exercise  
Moderate, continuous cycling.

### 3.  Anaerobic Exercise  
Short, high-intensity bursts producing sharp physiological changes.

These allow comparison between **mental stress**, **physical exertion**, and **baseline activity**.

---

##  Using the Dataset

### Clone the Repository

```bash
git clone https://github.com/Ctt011/Capstone-Behavorial.git
cd Capstone-Behavorial
```

### Launch the Notebook

```bash
jupyter notebook WISE_Stress_EDA_Model.ipynb
```

### View Files

- Open CSV files via  
  - Pandas  
  - VSCode  
  - Excel  
- Use the notebook to generate time-series plots  
- Analyze stress patterns or build ML models

---

##  Research Purpose

This dataset is used to:

- Extract robust physiological features  
- Compare induced lab stress vs. real-world daily stress  
- Evaluate domain adaptation methods (e.g., CORAL, DANN)  
- Study cross-condition generalization  
- Build toward a **personalized stress digital twin**










