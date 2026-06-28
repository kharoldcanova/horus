"""
AudioHeartbeatCNN: 1D Convolutional Neural Network for
contact-microphone heartbeat detection through solid materials.

Input:  8000 samples x 1 channel (filtered audio at 4000 Hz)
Architecture: Lightweight 1D Conv blocks
Output: Binary classification (sigmoid)

Exports to: assets/models/heartbeat_audio_cnn.tflite
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import os

INPUT_LENGTH = 8000  # 2 seconds at 4000 Hz
SAMPLE_RATE = 4000.0


def build_audio_cnn():
    """Lightweight 1D CNN for 8k-sample audio windows."""
    inputs = keras.Input(shape=(INPUT_LENGTH, 1), name="audio_input")

    # Downsample aggressively while building features
    x = layers.Conv1D(16, kernel_size=65, strides=8, padding="same", activation="relu")(inputs)
    x = layers.BatchNormalization()(x)

    x = layers.Conv1D(32, kernel_size=17, strides=4, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)

    x = layers.Conv1D(64, kernel_size=9, strides=4, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)

    x = layers.GlobalAveragePooling1D()(x)

    x = layers.Dense(32, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(16, activation="relu")(x)
    x = layers.Dropout(0.2)(x)

    outputs = layers.Dense(1, activation="sigmoid", name="heartbeat")(x)

    model = keras.Model(inputs=inputs, outputs=outputs, name="audio_heartbeat_cnn")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="binary_crossentropy",
        metrics=["accuracy", keras.metrics.Precision(), keras.metrics.Recall()],
    )
    return model


def generate_synthetic_audio_data(num_samples=3000):
    """Generate realistic contact-microphone heartbeat signals.

    Models the acoustic/vibrational signature of a heartbeat
    transmitted through solid material as detected by a phone
    microphone pressed against the surface.

    Heartbeat characteristics at contact mic:
    - Low-frequency thump ~20-50 Hz (main mechanical impact)
    - Harmonics up to ~150 Hz
    - Pulse width ~80-150ms
    - Rate: 30-200 BPM
    """
    t = np.arange(INPUT_LENGTH) / SAMPLE_RATE
    X = np.zeros((num_samples, INPUT_LENGTH, 1))
    y = np.zeros((num_samples,))

    for i in range(num_samples):
        has_heartbeat = np.random.random() > 0.35
        y[i] = 1.0 if has_heartbeat else 0.0

        # Base noise: electrical + ambient
        noise = np.random.normal(0, 0.015, INPUT_LENGTH)

        # Low-frequency structural rumble (building, wind, machinery)
        rumble_freq = np.random.uniform(3, 15)
        rumble = 0.01 * np.sin(2 * np.pi * rumble_freq * t + np.random.random() * 2 * np.pi)
        rumble += 0.005 * np.sin(2 * np.pi * rumble_freq * 0.5 * t)

        # Contact noise (handling, movement)
        for _ in range(np.random.poisson(2)):
            impulse_pos = np.random.randint(0, INPUT_LENGTH)
            impulse_width = np.random.randint(5, 30)
            impulse_amp = np.random.uniform(0.02, 0.08)
            end = min(INPUT_LENGTH, impulse_pos + impulse_width)
            impulse = impulse_amp * np.exp(
                -0.5 * ((np.arange(impulse_pos, end) - impulse_pos) / (impulse_width / 4)) ** 2
            )
            noise[:end - impulse_pos] += impulse[:min(len(impulse), INPUT_LENGTH - impulse_pos)]
            # Fix: properly add the impulse
            for j in range(impulse_pos, end):
                if j < INPUT_LENGTH:
                    noise[j] += impulse_amp * np.exp(
                        -0.5 * ((j - impulse_pos) / (impulse_width / 4)) ** 2
                    )

        if has_heartbeat:
            bpm = np.random.uniform(30, 200)
            hr = bpm / 60.0

            signal = np.zeros(INPUT_LENGTH)
            n_cycles = int(INPUT_LENGTH / SAMPLE_RATE * hr) + 1

            for c in range(n_cycles):
                center = int(c * SAMPLE_RATE / hr)
                if center >= INPUT_LENGTH:
                    break

                # Main pulse (low frequency thump)
                pulse_width = np.random.uniform(0.04, 0.12)  # 40-120ms
                pw_samples = int(pulse_width * SAMPLE_RATE)
                start = max(0, center - pw_samples)
                end_pulse = min(INPUT_LENGTH, center + pw_samples)
                amp = np.random.uniform(0.3, 1.0)

                for j in range(start, end_pulse):
                    # Asymmetric pulse: faster attack, slower decay
                    rel_pos = (j - center) / pw_samples
                    if rel_pos < 0:
                        envelope = np.exp(-0.5 * (rel_pos / 0.3) ** 2)
                    else:
                        envelope = np.exp(-0.5 * (rel_pos / 0.5) ** 2)

                    # Main thump + harmonic content
                    val = amp * envelope
                    val += 0.3 * amp * np.sin(2 * np.pi * 2.0 * rel_pos) * envelope
                    signal[j] += val

                # Add a smaller pre-ejection component (S1-like)
                if c < n_cycles - 1:
                    next_center = int((c + 1) * SAMPLE_RATE / hr)
                    gap = (next_center - center)
                    if gap > int(0.1 * SAMPLE_RATE):
                        pre_pos = center + int(gap * 0.45)
                        if pre_pos < INPUT_LENGTH:
                            pw = int(0.03 * SAMPLE_RATE)
                            pre_start = max(0, pre_pos - pw // 2)
                            pre_end = min(INPUT_LENGTH, pre_pos + pw // 2)
                            for j in range(pre_start, pre_end):
                                env = np.exp(-0.5 * ((j - pre_pos) / (pw / 3)) ** 2)
                                signal[j] += 0.2 * amp * env

            mixed = signal + noise + rumble
        else:
            # No heartbeat: add structured noise (machinery, footsteps)
            mixed = noise + rumble

            # Add periodic machinery-like noise
            for _ in range(np.random.randint(1, 4)):
                mach_freq = np.random.uniform(10, 100)  # Hz
                mach_amp = np.random.uniform(0.005, 0.03)
                mixed += mach_amp * np.sin(
                    2 * np.pi * mach_freq * t + np.random.random() * 2 * np.pi
                )

        X[i, :, 0] = mixed

    return X, y


def train():
    print("Generating synthetic audio training data...")
    X_train, y_train = generate_synthetic_audio_data(3000)
    X_val, y_val = generate_synthetic_audio_data(1000)
    X_test, y_test = generate_synthetic_audio_data(500)

    print(f"Training samples:   {len(X_train)}, heartbeat ratio: {y_train.mean():.2f}")
    print(f"Validation samples: {len(X_val)}, heartbeat ratio: {y_val.mean():.2f}")
    print(f"Test samples:       {len(X_test)}, heartbeat ratio: {y_test.mean():.2f}")
    print(f"Input shape: {X_train.shape}")

    model = build_audio_cnn()
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=8, restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6
        ),
        keras.callbacks.ModelCheckpoint(
            "best_audio_model.h5", monitor="val_accuracy", save_best_only=True
        ),
    ]

    history = model.fit(
        X_train, y_train,
        batch_size=32,
        epochs=80,
        validation_data=(X_val, y_val),
        callbacks=callbacks,
        verbose=1,
    )

    val_loss, val_acc, val_prec, val_rec = model.evaluate(X_test, y_test)
    print(f"\nTest Results:")
    print(f"  Accuracy:  {val_acc:.3f}")
    print(f"  Precision: {val_prec:.3f}")
    print(f"  Recall:    {val_rec:.3f}")

    return model, history


def export_tflite(model, output_path="../assets/models/heartbeat_audio_cnn.tflite"):
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
    print(f"\nTFLite model exported to {output_path}")
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
    print("\nDone! Audio model saved as heartbeat_audio_cnn.tflite")
