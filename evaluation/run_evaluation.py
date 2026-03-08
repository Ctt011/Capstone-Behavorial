"""
run_evaluation.py

Reproduces the Stage 1 LOSO (Leave-One-Subject-Out) evaluation for the
Activity Classifier (PHYSICAL vs COGNITIVE).

Usage:
    python run_evaluation.py
    python run_evaluation.py --save results.txt

Expects:
    - preprocess_wise.py in the same directory
    - 22subjects/ folder with WISE dataset

Output:
    - Per-fold (per-subject) accuracy
    - Overall LOSO accuracy (~93.6%)
    - Confusion matrix
    - Classification report (precision, recall, F1)
"""

import os
import sys
import logging
import argparse
import numpy as np
from sklearn.pipeline import make_pipeline

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
)
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
)

# ── Import preprocessed data from the single source of truth ────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preprocess_wise import df_activity

# ── Configuration ───────────────────────────────────────────────────────────
FEATURES = ['HR_mean', 'HR_std', 'ACC_mean', 'ACC_std']
CLASSES = ['COGNITIVE', 'PHYSICAL']


logger = logging.getLogger(__name__)


def run_loso_evaluation():
    """Run 22-fold LOSO cross-validation and return results."""
    logger.info("Starting LOSO evaluation")

    df = df_activity.copy()

    # Merge AEROBIC + ANAEROBIC -> PHYSICAL (2-class)
    df['activity_2class'] = df['activity_type'].map({
        'COGNITIVE': 'COGNITIVE',
        'AEROBIC': 'PHYSICAL',
        'ANAEROBIC': 'PHYSICAL',
    })

    X = df[FEATURES].values
    y_labels = df['activity_2class'].values
    groups = df['subject'].values
    subjects = df['subject'].values

    le = LabelEncoder()
    y = le.fit_transform(y_labels)

    # ── LOSO cross-validation ───────────────────────────────────────────────
    logo = LeaveOneGroupOut()
    fold_results = []
    all_y_true = []
    all_y_pred = []

    for fold_idx, (train_idx, test_idx) in enumerate(logo.split(X, y, groups)):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        held_out = subjects[test_idx[0]]

        pipeline = make_pipeline(
            SimpleImputer(strategy='mean'),
            StandardScaler(),
            RandomForestClassifier(n_estimators=100, random_state=42),
        )
        pipeline.fit(X_train, y_train)
        y_pred = pipeline.predict(X_test)

        acc = accuracy_score(y_test, y_pred)
        logger.info(f"Fold {fold_idx + 1:2d} | Subject {held_out:>4s} | Acc {acc:.1%} | n={len(y_test)}")
        fold_results.append({
            'fold': fold_idx + 1,
            'subject': held_out,
            'accuracy': acc,
            'n_samples': len(y_test),
        })

        all_y_true.extend(y_test)
        all_y_pred.extend(y_pred)

    all_y_true = np.array(all_y_true)
    all_y_pred = np.array(all_y_pred)
    overall_acc = accuracy_score(all_y_true, all_y_pred)

    logger.info(f"LOSO complete — Overall accuracy: {overall_acc:.1%} ({len(all_y_true)} windows)")

    return fold_results, all_y_true, all_y_pred, le, overall_acc


def format_results(fold_results, y_true, y_pred, le, overall_acc):
    """Format results as a printable string."""
    lines = []
    lines.append("=" * 60)
    lines.append("Stage 1 Activity Classifier — LOSO Evaluation")
    lines.append("  Task:     PHYSICAL vs COGNITIVE (2-class)")
    lines.append(f"  Features: {FEATURES}")
    lines.append("  Model:    RandomForest (100 trees)")
    lines.append("  CV:       Leave-One-Subject-Out (22 folds)")
    lines.append("=" * 60)

    lines.append(f"\n{'Fold':>4}  {'Subject':>8}  {'Accuracy':>8}  {'Samples':>7}")
    lines.append("-" * 35)
    for r in fold_results:
        lines.append(
            f"{r['fold']:4d}  {r['subject']:>8}  {r['accuracy']:8.1%}  {r['n_samples']:7d}"
        )

    accs = [r['accuracy'] for r in fold_results]
    lines.append("-" * 35)
    lines.append(f"{'':>4}  {'Mean':>8}  {np.mean(accs):8.1%}")
    lines.append(f"{'':>4}  {'Std':>8}  {np.std(accs):8.1%}")
    lines.append(f"{'':>4}  {'Min':>8}  {np.min(accs):8.1%}")
    lines.append(f"{'':>4}  {'Max':>8}  {np.max(accs):8.1%}")

    lines.append(f"\nOverall LOSO Accuracy: {overall_acc:.1%}")
    lines.append(f"Total windows evaluated: {len(y_true)}")

    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred)
    class_names = le.classes_
    lines.append(f"\nConfusion Matrix:")
    lines.append(f"{'':>12} {'Pred ' + class_names[0]:>15} {'Pred ' + class_names[1]:>15}")
    for i, name in enumerate(class_names):
        lines.append(f"{'True ' + name:>12} {cm[i, 0]:15d} {cm[i, 1]:15d}")

    # Classification report
    lines.append(f"\nClassification Report:")
    lines.append(classification_report(y_true, y_pred, target_names=class_names))

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Reproduce Stage 1 LOSO evaluation (~93.6% accuracy)"
    )
    parser.add_argument(
        "--save", type=str, default=None,
        help="Optional: save results to a text file (e.g., --save results.txt)"
    )
    args = parser.parse_args()

    print("\nRunning LOSO evaluation (22 folds)...\n")
    fold_results, y_true, y_pred, le, overall_acc = run_loso_evaluation()

    output = format_results(fold_results, y_true, y_pred, le, overall_acc)
    print(output)

    if args.save:
        save_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), args.save
        )
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        with open(save_path, 'w') as f:
            f.write(output)
        print(f"\nResults saved to: {save_path}")


if __name__ == '__main__':
    main()
