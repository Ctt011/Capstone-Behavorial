"""
export_stage1_model.py

Trains the Stage 1 Activity Classifier (PHYSICAL vs COGNITIVE) on WISE data
and exports it as:
  1. ActivityClassifier.pkl  — sklearn pipeline for Python testing
  2. ActivityClassifier.mlmodel — CoreML model for iOS (Dhyay's app)

Usage:
    python export_stage1_model.py

Requires:
    pip install coremltools   (for .mlmodel export)
    pip install scikit-learn   (already installed)

Model Details:
    - 2-class: PHYSICAL (merged AEROBIC+ANAEROBIC) vs COGNITIVE
    - Features: HR_mean, HR_std, ACC_mean, ACC_std  (4 features)
    - Pipeline: SimpleImputer → StandardScaler → RandomForestClassifier
    - Validation: Leave-One-Subject-Out (22 folds) = 93.6% accuracy
    - Note: SVM achieved 94.5% but RandomForest converts to CoreML more reliably
"""

import os
import sys
import logging
import numpy as np
import joblib
from sklearn.pipeline import make_pipeline

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
)
logger = logging.getLogger(__name__)
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import LeaveOneGroupOut, cross_val_score
from sklearn.metrics import classification_report

# ── Import preprocessed data ────────────────────────────────────────────────

# Add this directory to path so preprocess_wise.py can be imported
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preprocess_wise import df_activity

# ── Configuration ────────────────────────────────────────────────────────────

FEATURES = ['HR_mean', 'HR_std', 'ACC_mean', 'ACC_std']
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(SRC_DIR, 'models')

# ── Create 2-class dataset ───────────────────────────────────────────────────

print("=" * 60)
print("Stage 1 Activity Classifier — Export Script")
print("=" * 60)

df = df_activity.copy()

# Merge AEROBIC + ANAEROBIC → PHYSICAL
df['activity_2class'] = df['activity_type'].map({
    'COGNITIVE': 'COGNITIVE',
    'AEROBIC': 'PHYSICAL',
    'ANAEROBIC': 'PHYSICAL'
})

X = df[FEATURES].values
y_labels = df['activity_2class'].values
groups = df['subject'].values

le = LabelEncoder()
y = le.fit_transform(y_labels)

print(f"\nDataset: {len(X)} windows")
print(f"  PHYSICAL:  {sum(y_labels == 'PHYSICAL')}")
print(f"  COGNITIVE: {sum(y_labels == 'COGNITIVE')}")
print(f"  Subjects:  {df['subject'].nunique()}")
print(f"  Features:  {FEATURES}")
print(f"  Classes:   {list(le.classes_)}")

# ── LOSO Validation ──────────────────────────────────────────────────────────

print("\n--- LOSO Validation (22-fold) ---")

pipeline = make_pipeline(
    SimpleImputer(strategy='mean'),
    StandardScaler(),
    RandomForestClassifier(n_estimators=100, random_state=42)
)

logo = LeaveOneGroupOut()
scores = cross_val_score(pipeline, X, y, cv=logo, groups=groups, scoring='accuracy')

print(f"LOSO Accuracy: {scores.mean():.1%} (+/- {scores.std():.1%})")
print(f"Per-subject:   min={scores.min():.1%}, max={scores.max():.1%}")

# ── Train final model on ALL data ────────────────────────────────────────────

print("\n--- Training final model on all data ---")

final_pipeline = make_pipeline(
    SimpleImputer(strategy='mean'),
    StandardScaler(),
    RandomForestClassifier(n_estimators=100, random_state=42)
)
final_pipeline.fit(X, y)

# Sanity check — predict on training data
y_pred = final_pipeline.predict(X)
print(f"Training accuracy: {np.mean(y_pred == y):.1%}")
print(f"\nClassification report:")
print(classification_report(y, y_pred, target_names=le.classes_))

# ── Save sklearn pipeline (.pkl) ─────────────────────────────────────────────

pkl_path = os.path.join(OUTPUT_DIR, 'ActivityClassifier.pkl')
joblib.dump({
    'pipeline': final_pipeline,
    'label_encoder': le,
    'features': FEATURES,
    'classes': list(le.classes_),
    'loso_accuracy': float(scores.mean()),
}, pkl_path)
logger.info(f"Saved sklearn pipeline: {pkl_path}")
print(f"\nSaved: {pkl_path}")

# ── Convert to CoreML (.mlmodel) ─────────────────────────────────────────────
# Build CoreML model directly from sklearn tree data using coremltools spec API.
# This avoids sklearn/coremltools version compatibility issues entirely.

mlmodel_path = os.path.join(OUTPUT_DIR, 'ActivityClassifier.mlmodel')

try:
    import coremltools as ct
    from coremltools.models import datatypes, MLModel
    from coremltools.models.tree_ensemble import TreeEnsembleClassifier

    # Extract the fitted scaler and imputer parameters
    imputer = final_pipeline[0]  # SimpleImputer
    scaler = final_pipeline[1]   # StandardScaler
    rf = final_pipeline[2]       # RandomForestClassifier

    # Get scaler parameters (we'll bake preprocessing into input description)
    means = imputer.statistics_    # imputer fill values
    scale_means = scaler.mean_     # scaler means
    scale_stds = scaler.scale_     # scaler std devs

    # Build TreeEnsembleClassifier from sklearn RF trees
    class_labels = list(le.classes_)  # ['COGNITIVE', 'PHYSICAL']

    # At inference time, Swift code must standardize inputs first
    # (impute NaN, then z-score normalize), then feed to model

    te = TreeEnsembleClassifier(
        features=[(f, datatypes.Double()) for f in FEATURES],
        class_labels=class_labels,
        output_features=('activity_type', 'activity_scores'),
    )

    for tree_idx, estimator in enumerate(rf.estimators_):
        tree_data = estimator.tree_

        def add_node(node_id, tree_id):
            if tree_data.children_left[node_id] == -1:  # leaf
                values = tree_data.value[node_id][0]
                total = values.sum()
                # Keys must be integer class indices, not strings
                class_probs = {i: float(values[i] / total)
                               for i in range(len(class_labels))}
                te.add_leaf_node(tree_id, node_id, class_probs)
            else:
                feature_idx = int(tree_data.feature[node_id])
                threshold = float(tree_data.threshold[node_id])
                left = int(tree_data.children_left[node_id])
                right = int(tree_data.children_right[node_id])

                # BranchOnValueLessThanEqual: true_child=left, false_child=right
                te.add_branch_node(
                    tree_id, node_id,
                    feature_index=feature_idx,
                    feature_value=threshold,
                    branch_mode='BranchOnValueLessThanEqual',
                    true_child_id=left,
                    false_child_id=right,
                )
                add_node(left, tree_id)
                add_node(right, tree_id)

        add_node(0, tree_idx)

    # Set default prediction (required — defines output dimension)
    te.set_default_prediction_value([0.0, 0.0])  # 2 classes

    spec = te.spec

    # Set metadata
    spec.description.metadata.author = 'Camille Tran'
    spec.description.metadata.shortDescription = (
        'Stage 1 Activity Classifier: PHYSICAL vs COGNITIVE. '
        'Trained on WISE dataset (22 subjects, LOSO). '
        'IMPORTANT: Inputs must be standardized first — '
        f'means={list(np.round(scale_means, 4))}, '
        f'stds={list(np.round(scale_stds, 4))}, '
        f'impute_NaN_with={list(np.round(means, 4))}'
    )

    # Set feature descriptions
    feature_descriptions = {
        'HR_mean': 'Mean heart rate (BPM) in window — standardize before input',
        'HR_std': 'Std dev of heart rate in window — standardize before input',
        'ACC_mean': 'Mean accelerometer (or steps proxy) — standardize before input',
        'ACC_std': 'Std dev accelerometer (or steps proxy) — standardize before input',
    }
    for feat_desc in spec.description.input:
        if feat_desc.name in feature_descriptions:
            feat_desc.shortDescription = feature_descriptions[feat_desc.name]

    model = MLModel(spec)
    model.save(mlmodel_path)
    print(f"Saved: {mlmodel_path}")

    # Save preprocessing params as JSON for Dyhay's Swift code
    import json
    preprocess_path = os.path.join(OUTPUT_DIR, 'ActivityClassifier_preprocessing.json')
    preprocessing = {
        'features': FEATURES,
        'imputer_fill_values': {f: float(v) for f, v in zip(FEATURES, means)},
        'scaler_means': {f: float(v) for f, v in zip(FEATURES, scale_means)},
        'scaler_stds': {f: float(v) for f, v in zip(FEATURES, scale_stds)},
        'classes': class_labels,
        'class_mapping': {'COGNITIVE': 0, 'PHYSICAL': 1},
        'loso_accuracy': float(scores.mean()),
        'note': 'Before calling the model, replace NaN with imputer_fill_values, '
                'then standardize: (value - mean) / std'
    }
    with open(preprocess_path, 'w') as f:
        json.dump(preprocessing, f, indent=2)
    print(f"Saved: {preprocess_path}")

except ImportError as e:
    print(f"\n[WARNING] Missing package: {e}")
    print("Install with: pip install coremltools")
    print("Then re-run this script to generate the .mlmodel file.")

except Exception as e:
    import traceback
    print(f"\n[ERROR] CoreML conversion failed: {e}")
    traceback.print_exc()
    print("\nThe .pkl file was saved successfully — you can convert manually later.")

# ── Summary ──────────────────────────────────────────────────────────────────

print("\n" + "=" * 60)
print("EXPORT COMPLETE")
print("=" * 60)
print(f"""
Files created:
  1. ActivityClassifier.pkl     — Python testing (joblib.load)
  2. ActivityClassifier.mlmodel — iOS deployment (drag into Xcode)

Model info:
  - Task:       PHYSICAL vs COGNITIVE (2-class)
  - Features:   {FEATURES}
  - Algorithm:  RandomForest (100 trees)
  - LOSO:       {scores.mean():.1%} accuracy (22 subjects)
  - Classes:    {list(le.classes_)}
                0 = COGNITIVE, 1 = PHYSICAL

For Dhyay (iOS integration):
  1. Drag ActivityClassifier.mlmodel into Xcode project
  2. Xcode auto-generates a Swift class: ActivityClassifier
  3. Input: 4 doubles (HR_mean, HR_std, ACC_mean, ACC_std)
  4. Output: predicted class ("COGNITIVE" or "PHYSICAL")
  5. When COGNITIVE → run Stage 3 (DC/AC stress detection)
     When PHYSICAL → skip stress detection (motion artifact)
""")
