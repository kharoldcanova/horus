"""
HeartbeatCNN: 1D Convolutional Neural Network for
smartphone-based seismocardiography/gyrocardiography detection.

Architecture:
  Input: 256 samples x 6 channels (accel_xyz + gyro_xyz)
  Conv1D blocks -> GlobalAvgPool -> Dense -> Binary classification

Output: TFLite model (~200-500 KB) for on-device inference.
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import os

INPUT_LENGTH = 256
NUM_CHANNELS = 6
SAMPLE_RATE = 128.0


def build_heartbeat_cnn():
    inputs = keras.Input(shape=(INPUT_LENGTH, NUM_CHANNELS), name="sensor_input")

    x = layers.Conv1D(32, kernel_size=7, padding="same", activation="relu")(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(pool_size=3, strides=2)(x)

    x = layers.Conv1D(64, kernel_size=5, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(pool_size=3, strides=2)(x)

    x = layers.Conv1D(128, kernel_size=5, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(pool_size=3, strides=2)(x)

    x = layers.Conv1D(128, kernel_size=3, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling1D()(x)

    x = layers.Dense(64, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(32, activation="relu")(x)
    x = layers.Dropout(0.2)(x)

    outputs = layers.Dense(1, activation="sigmoid", name="heartbeat")(x)

    model = keras.Model(inputs=inputs, outputs=outputs, name="heartbeat_cnn")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="binary_crossentropy",
        metrics=["accuracy", keras.metrics.Precision(), keras.metrics.Recall()],
    )
    return model


def generate_synthetic_data(num_samples=5000):
    """Generate synthetic SCG/GCG-like signals for initial training.

    Real heartbeat signals are sinusoidal-like bursts at ~1-2 Hz
    with harmonic content. This generates plausible training data.
    """
    t = np.arange(INPUT_LENGTH) / SAMPLE_RATE
    X = np.zeros((num_samples, INPUT_LENGTH, NUM_CHANNELS))
    y = np.zeros((num_samples,))

    for i in range(num_samples):
        has_heartbeat = np.random.random() > 0.3
        y[i] = 1.0 if has_heartbeat else 0.0

        for ch in range(NUM_CHANNELS):
            noise = np.random.normal(0, 0.02, INPUT_LENGTH)

            low_freq_drift = 0.005 * np.sin(
                2 * np.pi * 0.1 * t + np.random.random() * 2 * np.pi
            )

            if has_heartbeat:
                bpm = np.random.uniform(50, 150)
                hr = bpm / 60.0

                n_cycles = int(INPUT_LENGTH / SAMPLE_RATE * hr)
                heartbeats = np.zeros(INPUT_LENGTH)

                for c in range(n_cycles):
                    center = int(c * SAMPLE_RATE / hr)
                    if center < INPUT_LENGTH:
                        width = np.random.randint(8, 16)
                        start = max(0, center - width)
                        end = min(INPUT_LENGTH, center + width)
                        amp = np.random.uniform(0.3, 1.0)
                        envelope = np.exp(
                            -0.5
                            * (
                                (np.arange(start, end) - center)
                                / (width / 3)
                            )
                            ** 2
                        )
                        heartbeats[start:end] += amp * envelope

                signal = heartbeats + noise + low_freq_drift
            else:
                signal = noise + low_freq_drift
                signal += 0.01 * np.sin(
                    2 * np.pi * np.random.uniform(3, 8) * t
                    + np.random.random() * 2 * np.pi
                )

            X[i, :, ch] = signal

    return X, y


def train():
    print("Generating synthetic training data...")
    X_train, y_train = generate_synthetic_data(4000)
    X_val, y_val = generate_synthetic_data(1000)

    pos_ratio = y_train.mean()
    print(f"Training samples: {len(X_train)}, "
          f"heartbeat ratio: {pos_ratio:.2f}")

    model = build_heartbeat_cnn()
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=10, restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=5, min_lr=1e-6
        ),
        keras.callbacks.ModelCheckpoint(
            "best_model.h5", monitor="val_accuracy", save_best_only=True
        ),
    ]

    history = model.fit(
        X_train, y_train,
        batch_size=64,
        epochs=100,
        validation_data=(X_val, y_val),
        callbacks=callbacks,
        verbose=1,
    )

    val_loss, val_acc, val_prec, val_rec = model.evaluate(X_val, y_val)
    print(f"\nValidation Results:")
    print(f"  Accuracy:  {val_acc:.3f}")
    print(f"  Precision: {val_prec:.3f}")
    print(f"  Recall:    {val_rec:.3f}")

    return model, history


def export_tflite(model, output_path="../assets/models/heartbeat_cnn.tflite"):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
    ]
    converter.inference_input_type = tf.float32
    converter.inference_output_type = tf.float32

    tflite_model = converter.convert()

    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    print(f"TFLite model exported to {output_path}")
    print(f"Model size: {size_kb:.1f} KB")

    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print(f"Input shape:  {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")
    print(f"Input dtype:  {input_details[0]['dtype']}")
    print(f"Output dtype: {output_details[0]['dtype']}")

    return tflite_model


if __name__ == "__main__":
    model, history = train()
    export_tflite(model)
    print("\nDone! Model saved as heartbeat_cnn.tflite")
