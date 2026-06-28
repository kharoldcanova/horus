# Horus — Smartphone-Based Heartbeat Detection for Urban Search and Rescue

> **English** | [Español](README.es.md)

**Horus** is an open-source mobile application that leverages smartphone inertial sensors (accelerometer and gyroscope), audio capabilities, and camera-based photoplethysmography to detect human heartbeats through solid structures such as rubble and debris. The system is designed for first responders in Urban Search and Rescue (USAR) operations, providing a low-cost, widely-accessible tool for locating survivors in disaster zones.

---

## 1. Abstract

The golden window for rescuing victims trapped under rubble is 72 hours. Current tools for locating survivors — seismic/acoustic detectors, thermal imaging, and radar-based systems like NASA FINDER — are expensive, scarce, and require specialized training. Smartphones, carried by over 5 billion people worldwide, contain MEMS inertial sensors (accelerometers and gyroscopes) capable of detecting mechanical vibrations in the 0.5–30 Hz range, which encompasses human cardiac activity. This work presents **Horus**, a multi-modal smartphone application that combines seismocardiography (SCG), gyrocardiography (GCG), contact microphone auscultation, and remote photoplethysmography (rPPG) to detect heartbeat signals. All processing is performed on-device using Dart-based signal processing pipelines and a quantized 1D convolutional neural network (CNN) running via TensorFlow Lite, eliminating the need for network connectivity in disaster scenarios.

---

## 2. Problem Statement

### 2.1 The Challenge

After structural collapse events — earthquakes, bombings, or industrial accidents — the primary challenge for rescue teams is rapidly locating survivors trapped in void spaces beneath rubble. Current methodologies include:

- **Canine teams:** Highly effective but limited by handler availability, canine fatigue, and environmental hazards.
- **Seismic/acoustic detectors** (e.g., Delsar, Searcheye): Geophone-based sensors that detect vibrations through solid media. Cost: \$5,000–\$20,000 per unit.
- **Radar-based systems** (e.g., NASA FINDER): Microwave radar capable of detecting heartbeat through 9+ meters of rubble. Cost: >\$100,000.
- **Thermal imaging:** Limited to surface-level detection and obstructed by debris.

### 2.2 The Opportunity

Modern smartphones integrate multi-axis MEMS accelerometers and gyroscopes as standard components. Recent research (Centracchio et al., 2025) demonstrates that smartphone IMUs can detect heartbeats with 97.3% sensitivity using gyrocardiography (GCG) signals, with inter-beat interval errors of ±5.22 ms. This performance approaches clinical-grade standards using hardware already in the pockets of first responders.

---

## 3. Physiological and Physical Foundations

### 3.1 Cardiac Mechanics

Each cardiac cycle generates mechanical vibrations through:

1. **Myocardial contraction:** Ventricular depolarization causes rotational and translational motion of the heart muscle.
2. **Valvular closure:** The first heart sound (S1, mitral and tricuspid closure) and second heart sound (S2, aortic and pulmonary closure) produce broad-spectrum mechanical energy.
3. **Ballistocardiographic recoil:** Ejection of blood into the aorta generates a recoil force (Newton's third law) transmitted to the chest wall.

These vibrations manifest at the chest surface as:
- Linear accelerations (measured by SCG): 0.1–10 m/s²
- Angular velocities (measured by GCG): 0.1–10 °/s
- Dominant frequency range: 1–30 Hz

### 3.2 Vibration Transmission Through Solid Media

Mechanical vibrations propagate through solid structures (concrete, brick, rebar) as:
- **Compression waves (P-waves):** Fastest propagation, low attenuation in homogeneous media
- **Shear waves (S-waves):** Slower, higher attenuation
- **Surface waves (Rayleigh/Love):** Confined to boundaries

For the frequencies of interest (1–30 Hz), attenuation through reinforced concrete is approximately 0.5–3 dB/m depending on composition, moisture content, and structural discontinuities. A smartphone placed in direct contact with a continuous structural element (beam, column, slab) can detect vibrations transmitted through several meters of rubble.

### 3.3 Sensor Modalities

| Modality | Sensor | Signal | Frequency Range | Contact Required |
|----------|--------|--------|-----------------|------------------|
| Seismocardiography (SCG) | Accelerometer | Linear acceleration (m/s²) | 0.5–30 Hz | Physical (structure) |
| Gyrocardiography (GCG) | Gyroscope | Angular velocity (°/s) | 0.5–30 Hz | Physical (structure) |
| Contact Auscultation | Microphone | Acoustic pressure (Pa) | 20–200 Hz | Physical (structure) |
| rPPG | Camera | Color channel intensity | 0.5–5 Hz | Visual (face/skin) |

---

## 4. Related Work

### 4.1 Smartphone Mechanocardiography

Recent advances have established the viability of smartphone-based cardiac monitoring:

- **Centracchio et al. (2025)** demonstrated that smartphone inertial sensors can measure instantaneous heart rate and breathing rate with strong linear correlation (R² > 0.999) compared to reference ECG, with GCG outperforming SCG in both sensitivity (97.3% vs. 89.3%) and positive predictive value (97.9% vs. 93.3%).

- **Wu et al. (2023)** reviewed gyrocardiography for HR monitoring, establishing that gyroscope-based measurements capture up to 60% of cardiac vibrational energy and are largely independent of gravity and user posture.

- **Elgendi et al. (2023)** proposed a standardized workflow for smartphone GCG signal processing, including axis selection (yaw axis shows lowest drift) and evaluation metrics (MAE, RMSE, Pearson correlation, equivalence testing).

- **Lahdenoja et al. (2018)** validated atrial fibrillation detection using smartphone accelerometer and gyroscope, demonstrating clinical applicability.

### 4.2 Smartphone Stethoscopy

- **Luo et al. (2022)** developed Echoes (iOS) and later FonoCheck (Android), demonstrating that non-medical users can record diagnostic-quality heart sounds with smartphone microphones, with 74.6% of recordings rated as good quality across 1,148 users and 7,597 recordings.

- **A 2025 hospital study** validated smartphone heart sound measurement across 296 hospitalized patients, achieving 86% good-quality recordings across multiple departments.

### 4.3 Remote Photoplethysmography

- **Google Research (2026)** published Passive Heart Rate Monitoring (PHRM) in Nature, demonstrating passive heart rate measurement from front-facing camera video during everyday smartphone use. Open-source dataset and model available.

- **GRGB rPPG (2023)** established efficient low-complexity rPPG algorithms outperforming ML-based methods in controlled conditions.

### 4.4 Disaster Response Technology

- **NASA FINDER** uses microwave radar to detect heartbeats through 9+ m of rubble but costs >\$100K and requires specialized operation.
- **Delsar/Rescue Radar** systems use geophone arrays for seismic detection at \$5K–\$20K.
- **No prior work** has systematically evaluated smartphone IMU-based detection through rubble structures for USAR applications.

---

## 5. System Architecture

### 5.1 Overview

Horus operates in three detection modes, selectable based on scenario:

```
┌──────────────────────────────────────────────────────┐
│                    Horus App (Flutter)                │
├──────────────────────────────────────────────────────┤
│                    Mode Selector                      │
├────────────┬──────────────────┬──────────────────────┤
│  Mode 1:   │  Mode 2:         │  Mode 3:             │
│  IMU       │  Audio Contact   │  Camera rPPG         │
│  (GCG/SCG) │  Stethoscope     │  (facial video)      │
├────────────┴──────────────────┴──────────────────────┤
│              Signal Processing Pipeline               │
│  Raw Sensor → Bandpass Filter → FFT → Peak Detection  │
├──────────────────────────────────────────────────────┤
│              ML Classifier (TFLite 1D CNN)            │
│          Input: 256-sample window (≈ 2s @ 128 Hz)     │
│          Output: {heartbeat_detected: bool, bpm, conf} │
├──────────────────────────────────────────────────────┤
│  Session Recording  │  Visual Feedback  │  Audio Alert │
└──────────────────────────────────────────────────────┘
```

### 5.2 Mode 1: Inertial Sensors (Primary)

**Use case:** The rescuer places the smartphone directly against a structural element (beam, wall, pavement) in contact with the rubble pile.

**Pipeline:**
1. Raw accelerometer + gyroscope data captured at maximum sensor rate (SENSOR_DELAY_FASTEST, typically 100-400 Hz)
2. Gravity compensation via high-pass filter at 0.5 Hz
3. Axis selection: gyroscope yaw axis (lowest drift) as primary, accelerometer Z-axis as secondary
4. Butterworth bandpass filter (4th order, 0.5–30 Hz)
5. Signal windowing: 256 samples (≈2 s @ 128 Hz resampled)
6. FFT spectrum analysis for fundamental frequency detection
7. Peak detection in time domain for inter-beat interval estimation
8. 1D CNN classification for heartbeat presence verification

### 5.3 Mode 2: Contact Microphone (Secondary)

**Use case:** Confirmation when Mode 1 yields uncertain results. The rescuer places the phone's microphone (or connected earphone) against the surface.

**Pipeline:**
1. Raw PCM audio captured at 44.1 kHz
2. Downsampled to 1 kHz
3. Bandpass filter 20–200 Hz (cardiac acoustic energy range)
4. Envelope detection via Hilbert transform
5. Peak detection for heart rate estimation
6. Confidence scoring based on periodicity analysis

### 5.4 Mode 3: Camera rPPG (Surface Triage)

**Use case:** When the victim's face or skin is visible (surface-level or void access).

**Pipeline:**
1. Face detection via MediaPipe
2. ROI selection (forehead/cheeks)
3. Color channel decomposition (green channel preferred for blood volume pulse)
4. Signal extraction over 30 s window
5. FFT-based heart rate estimation
6. Adapted from Google PHRM architecture

---

## 6. Machine Learning Model

### 6.1 Architecture

A 1D convolutional neural network designed for mobile inference:

```
Input: (256, 6) — 256 samples × 6 channels (accel xyz + gyro xyz)
  │
  ├─ Conv1D(32, kernel=7, ReLU) → BatchNorm → MaxPool(3)
  ├─ Conv1D(64, kernel=5, ReLU) → BatchNorm → MaxPool(3)
  ├─ Conv1D(128, kernel=3, ReLU) → BatchNorm → GlobalAvgPool
  ├─ Dense(64, ReLU) → Dropout(0.3)
  ├─ Dense(32, ReLU) → Dropout(0.2)
  └─ Dense(1, Sigmoid) → Binary classification
```

### 6.2 Training

- **Dataset:** Combination of public SCG/GCG datasets (CEBS, Combined Measurement of ECG, Breathing and Seismocardiogram) and self-collected data.
- **Augmentation:** Gaussian noise addition, time stretching, amplitude scaling, sensor dropout.
- **Quantization:** Post-training INT8 quantization for TFLite deployment.
- **Target size:** < 500 KB.

### 6.3 On-Device Inference

- Runtime: TensorFlow Lite via `tflite_flutter`
- Execution: Dart isolate (non-blocking UI)
- Latency: < 10 ms per inference on modern mobile SoCs
- Power: Minimal (single inference per 2 s window)

---

## 7. Evaluation Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Sensitivity | True positive rate for heartbeat detection | > 90% |
| Positive Predictive Value | Precision of positive detections | > 90% |
| RMSE | Root mean square error for BPM estimation | < 5 BPM |
| MAE | Mean absolute error for BPM | < 3 BPM |
| False Positive Rate | Non-human vibration classified as heartbeat | < 5% |
| Detection Range | Maximum rubble depth for reliable detection | TBD (field) |

---

## 8. Limitations and Future Work

### 8.1 Known Limitations

- **Contact dependency:** Mode 1 and 2 require direct physical contact between phone and structure. Air-coupled detection is not feasible with current smartphone microphones for cardiac frequencies through rubble.
- **Hardware variability:** MEMS sensor quality varies across smartphone models. Budget devices exhibit higher noise floors and lower maximum sampling rates.
- **Motion artifacts:** Rescue operations involve significant ambient vibration (machinery, footsteps, wind). Robust filtering is critical.
- **Inter-subject variability:** Cardiac vibration amplitude varies with body habitus, age, and pathology.
- **No clinical validation:** This work provides engineering validation, not clinical trials for medical diagnosis.

### 8.2 Future Directions

- Integration with drone-deployed sensors for inaccessible areas
- Crowdsourced sensor network: multiple phones forming a seismic detection array
- Transfer learning to generalize across smartphone models
- Real-time audio feedback for directional localization
- Collaboration with USAR teams for field validation

---

## 9. References

1. Centracchio, J., et al. (2025). Accuracy of the Instantaneous Breathing and Heart Rates Estimated by Smartphone Inertial Units. *Sensors*, 25(4), 1094.

2. Wu, W., et al. (2023). Detection of heart rate using smartphone gyroscope data: a scoping review. *Frontiers in Cardiovascular Medicine*, 10, 1329290.

3. Elgendi, M., et al. (2023). Revolutionizing smartphone gyrocardiography for heart rate monitoring. *Frontiers in Cardiovascular Medicine*, 10, 1237043.

4. Lahdenoja, O., et al. (2018). Atrial Fibrillation Detection via Accelerometer and Gyroscope of a Smartphone. *IEEE JBHI*, 22(1), 108-118.

5. Luo, H., et al. (2022). Smartphone as an electronic stethoscope: factors influencing heart sound quality. *European Heart Journal — Digital Health*, 3(3), 473-480.

6. Luo, H., et al. (2025). Smartphone for heart sound measurement in hospital: feasibility and influencing factors. *European Heart Journal — Digital Health*.

7. Google Research. (2026). Towards passive heart health monitoring via smartphone camera. *Nature*.

8. Tadi, M. J., et al. (2017). Comprehensive comparison of gyrocardiography with ECG, echocardiography, and PWD. *Computing in Cardiology*.

9. Sieciński, S., et al. (2020). Gyrocardiography: A Review of the Definition, History, Waveform Description, and Applications. *Sensors*, 20(22), 6675.

10. NASA JPL. (2015). FINDER: Finding Individuals for Disaster and Emergency Response.

---

## 10. License

MIT — Open source for humanitarian use.

---

**Horas de desarrollo:** `TODO`
**Estado:** Prototipo inicial
**Contacto:** (abierto a colaboraciones de USAR teams, investigadores, y desarrolladores)
