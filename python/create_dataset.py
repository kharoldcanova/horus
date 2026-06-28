"""
Utility for creating datasets from recorded sensor sessions.

Usage:
  python create_dataset.py --input path/to/sessions/ --output dataset.npz

Each session file should be a CSV with columns:
  timestamp, ax, ay, az, gx, gy, gz, label

Label: 1 = heartbeat present, 0 = no heartbeat
"""

import argparse
import glob
import os

import numpy as np
import pandas as pd

WINDOW_SIZE = 256
STRIDE = 32


def load_session(filepath):
    df = pd.read_csv(filepath)
    required = ["timestamp", "ax", "ay", "az", "gx", "gy", "gz", "label"]
    for col in required:
        if col not in df.columns:
            raise ValueError(f"Missing column {col} in {filepath}")
    return df[required].values.astype(np.float32)


def window_sequence(data, window_size=WINDOW_SIZE, stride=STRIDE):
    X, y = [], []
    for start in range(0, len(data) - window_size + 1, stride):
        window = data[start : start + window_size]
        X.append(window[:, 1:7])
        labels = window[:, -1]
        label = 1.0 if labels.mean() > 0.5 else 0.0
        y.append(label)
    return np.array(X), np.array(y)


def create_dataset(input_pattern, output_path):
    files = glob.glob(input_pattern)
    if not files:
        print(f"No files found matching: {input_pattern}")
        return

    print(f"Found {len(files)} session files")
    all_X, all_y = [], []

    for fpath in sorted(files):
        try:
            data = load_session(fpath)
            X, y = window_sequence(data)
            if len(X) > 0:
                all_X.append(X)
                all_y.append(y)
                print(f"  {os.path.basename(fpath)}: {len(X)} windows")
        except Exception as e:
            print(f"  Error loading {fpath}: {e}")

    if not all_X:
        print("No valid windows extracted. Check your data.")
        return

    X = np.concatenate(all_X, axis=0)
    y = np.concatenate(all_y, axis=0)

    pos_ratio = y.mean()
    print(f"\nTotal windows: {len(X)}")
    print(f"Shape: {X.shape}")
    print(f"Positive ratio: {pos_ratio:.3f}")

    np.savez_compressed(output_path, X=X, y=y)
    print(f"Dataset saved to {output_path} ({os.path.getsize(output_path) / 1e6:.1f} MB)")


def split_dataset(dataset_path, val_split=0.2, test_split=0.1):
    data = np.load(dataset_path)
    X, y = data["X"], data["y"]

    n = len(X)
    indices = np.random.permutation(n)
    n_val = int(n * val_split)
    n_test = int(n * test_split)

    val_idx = indices[:n_val]
    test_idx = indices[n_val : n_val + n_test]
    train_idx = indices[n_val + n_test :]

    train_path = dataset_path.replace(".npz", "_train.npz")
    val_path = dataset_path.replace(".npz", "_val.npz")
    test_path = dataset_path.replace(".npz", "_test.npz")

    np.savez_compressed(train_path, X=X[train_idx], y=y[train_idx])
    np.savez_compressed(val_path, X=X[val_idx], y=y[val_idx])
    np.savez_compressed(test_path, X=X[test_idx], y=y[test_idx])

    print(f"Train: {len(train_idx)}, Val: {len(val_idx)}, Test: {len(test_idx)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create dataset from sensor sessions")
    parser.add_argument("--input", required=True, help="Glob pattern for session CSVs")
    parser.add_argument("--output", default="dataset.npz", help="Output .npz path")
    parser.add_argument("--split", action="store_true", help="Split into train/val/test")
    args = parser.parse_args()

    create_dataset(args.input, args.output)
    if args.split:
        split_dataset(args.output)
