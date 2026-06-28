# Horus — Detección de Latidos Cardíacos mediante Teléfono Inteligente para Búsqueda y Rescate Urbano

> [English](README.md) | **Español**

**Horus** es una aplicación móvil de código abierto que utiliza los sensores inerciales del teléfono inteligente (acelerómetro y giroscopio), capacidades de audio y fotopletismografía por cámara para detectar latidos cardíacos humanos a través de estructuras sólidas como escombros y rubble. El sistema está diseñado para personal de primera respuesta en operaciones de Búsqueda y Rescate Urbano (USAR), proporcionando una herramienta de bajo costo y ampliamente accesible para localizar sobrevivientes en zonas de desastre.

---

## 1. Resumen

La ventana de oro para rescatar víctimas atrapadas bajo escombros es de 72 horas. Las herramientas actuales para localizar sobrevivientes — detectores sísmicos/acústicos, imágenes térmicas y sistemas basados en radar como NASA FINDER — son costosos, escasos y requieren entrenamiento especializado. Los teléfonos inteligentes, utilizados por más de 5 mil millones de personas en todo el mundo, contienen sensores inerciales MEMS (acelerómetros y giroscopios) capaces de detectar vibraciones mecánicas en el rango de 0.5–30 Hz, que abarca la actividad cardíaca humana. Este trabajo presenta **Horus**, una aplicación multimodal para teléfonos inteligentes que combina sismocardiografía (SCG), girocardiografía (GCG), auscultación por micrófono de contacto y fotopletismografía remota (rPPG) para detectar señales cardíacas. Todo el procesamiento se realiza en el dispositivo mediante pipelines de procesamiento de señales en Dart y una red neuronal convolucional 1D (CNN) cuantizada que se ejecuta a través de TensorFlow Lite, eliminando la necesidad de conectividad de red en escenarios de desastre.

---

## 2. Planteamiento del Problema

### 2.1 El Desafío

Tras eventos de colapso estructural — terremotos, bombardeos o accidentes industriales — el desafío principal para los equipos de rescate es localizar rápidamente a los sobrevivientes atrapados en espacios vacíos bajo los escombros. Las metodologías actuales incluyen:

- **Equipos caninos:** Altamente efectivos pero limitados por la disponibilidad del guía, la fatiga del animal y los peligros ambientales.
- **Detectores sísmicos/acústicos** (ej., Delsar, Searcheye): Sensores basados en geófonos que detectan vibraciones a través de medios sólidos. Costo: \$5,000–\$20,000 por unidad.
- **Sistemas basados en radar** (ej., NASA FINDER): Radar de microondas capaz de detectar latidos a través de 9+ metros de escombros. Costo: >\$100,000.
- **Imágenes térmicas:** Limitadas a detección en superficie y obstruidas por los escombros.

### 2.2 La Oportunidad

Los teléfonos inteligentes modernos integran acelerómetros y giroscopios MEMS multieje como componentes estándar. Investigaciones recientes (Centracchio et al., 2025) demuestran que las IMU de teléfonos inteligentes pueden detectar latidos cardíacos con un 97.3% de sensibilidad utilizando señales de girocardiografía (GCG), con errores de intervalo entre latidos de ±5.22 ms. Este rendimiento se aproxima a los estándares de grado clínico utilizando hardware que ya está en los bolsillos del personal de primera respuesta.

---

## 3. Fundamentos Fisiológicos y Físicos

### 3.1 Mecánica Cardíaca

Cada ciclo cardíaco genera vibraciones mecánicas a través de:

1. **Contracción miocárdica:** La despolarización ventricular causa movimiento rotacional y de traslación del músculo cardíaco.
2. **Cierre valvular:** El primer sonido cardíaco (S1, cierre mitral y tricúspide) y el segundo sonido cardíaco (S2, cierre aórtico y pulmonar) producen energía mecánica de amplio espectro.
3. **Retroceso balistocardiográfico:** La eyección de sangre hacia la aorta genera una fuerza de retroceso (tercera ley de Newton) transmitida a la pared torácica.

Estas vibraciones se manifiestan en la superficie del pecho como:
- Aceleraciones lineales (medidas por SCG): 0.1–10 m/s²
- Velocidades angulares (medidas por GCG): 0.1–10 °/s
- Rango de frecuencia dominante: 1–30 Hz

### 3.2 Transmisión de Vibraciones a Través de Medios Sólidos

Las vibraciones mecánicas se propagan a través de estructuras sólidas (concreto, ladrillo, varilla de refuerzo) como:
- **Ondas de compresión (ondas P):** Propagación más rápida, baja atenuación en medios homogéneos.
- **Ondas de corte (ondas S):** Más lentas, mayor atenuación.
- **Ondas superficiales (Rayleigh/Love):** Confinadas a los límites.

Para las frecuencias de interés (1–30 Hz), la atenuación a través de concreto reforzado es de aproximadamente 0.5–3 dB/m dependiendo de la composición, el contenido de humedad y las discontinuidades estructurales. Un teléfono inteligente colocado en contacto directo con un elemento estructural continuo (viga, columna, losa) puede detectar vibraciones transmitidas a través de varios metros de escombros.

### 3.3 Modalidades de Sensores

| Modalidad | Sensor | Señal | Rango de Frecuencia | Contacto Requerido |
|-----------|--------|-------|---------------------|---------------------|
| Sismocardiografía (SCG) | Acelerómetro | Aceleración lineal (m/s²) | 0.5–30 Hz | Físico (estructura) |
| Girocardiografía (GCG) | Giroscopio | Velocidad angular (°/s) | 0.5–30 Hz | Físico (estructura) |
| Auscultación de Contacto | Micrófono | Presión acústica (Pa) | 20–200 Hz | Físico (estructura) |
| rPPG | Cámara | Intensidad de canal de color | 0.5–5 Hz | Visual (rostro/piel) |

---

## 4. Trabajo Relacionado

### 4.1 Mecanocardiografía con Teléfono Inteligente

Avances recientes han establecido la viabilidad de la monitorización cardíaca mediante teléfonos inteligentes:

- **Centracchio et al. (2025)** demostraron que los sensores inerciales de teléfonos inteligentes pueden medir la frecuencia cardíaca instantánea y la frecuencia respiratoria con una fuerte correlación lineal (R² > 0.999) en comparación con el ECG de referencia, superando GCG a SCG tanto en sensibilidad (97.3% vs. 89.3%) como en valor predictivo positivo (97.9% vs. 93.3%).

- **Wu et al. (2023)** revisaron la girocardiografía para monitorización de FC, estableciendo que las mediciones basadas en giroscopio capturan hasta el 60% de la energía vibratoria cardíaca y son en gran medida independientes de la gravedad y la postura del usuario.

- **Elgendi et al. (2023)** propusieron un flujo de trabajo estandarizado para el procesamiento de señales GCG en teléfonos inteligentes, incluyendo selección de ejes (el eje de guiñada muestra la menor deriva) y métricas de evaluación (MAE, RMSE, correlación de Pearson, pruebas de equivalencia).

- **Lahdenoja et al. (2018)** validaron la detección de fibrilación auricular mediante acelerómetro y giroscopio de teléfono inteligente, demostrando aplicabilidad clínica.

### 4.2 Estetoscopia con Teléfono Inteligente

- **Luo et al. (2022)** desarrollaron Echoes (iOS) y posteriormente FonoCheck (Android), demostrando que usuarios no médicos pueden grabar sonidos cardíacos de calidad diagnóstica con micrófonos de teléfonos inteligentes, con un 74.6% de grabaciones calificadas como de buena calidad en 1,148 usuarios y 7,597 grabaciones.

- **Un estudio hospitalario de 2025** validó la medición de sonidos cardíacos con teléfono inteligente en 296 pacientes hospitalizados, logrando un 86% de grabaciones de buena calidad en múltiples departamentos.

### 4.3 Fotopletismografía Remota

- **Google Research (2026)** publicó Monitoreo Pasivo de Frecuencia Cardíaca (PHRM) en Nature, demostrando la medición pasiva de la frecuencia cardíaca a partir de video de la cámara frontal durante el uso cotidiano del teléfono inteligente. Conjunto de datos y modelo de código abierto disponibles.

- **GRGB rPPG (2023)** estableció algoritmos rPPG eficientes de baja complejidad que superan a los métodos basados en ML en condiciones controladas.

### 4.4 Tecnología de Respuesta ante Desastres

- **NASA FINDER** utiliza radar de microondas para detectar latidos a través de 9+ m de escombros pero cuesta >\$100K y requiere operación especializada.
- **Delsar/Rescue Radar** utilizan conjuntos de geófonos para detección sísmica a \$5K–\$20K.
- **Ningún trabajo previo** ha evaluado sistemáticamente la detección basada en IMU de teléfonos inteligentes a través de estructuras de escombros para aplicaciones USAR.

---

## 5. Arquitectura del Sistema

### 5.1 Vista General

Horus opera en tres modos de detección, seleccionables según el escenario:

```
┌──────────────────────────────────────────────────────────┐
│                  App Horus (Flutter)                       │
├──────────────────────────────────────────────────────────┤
│                    Selector de Modo                       │
├────────────┬──────────────────┬──────────────────────────┤
│  Modo 1:   │  Modo 2:         │  Modo 3:                 │
│  IMU       │  Audio Contacto  │  Cámara rPPG             │
│  (GCG/SCG) │  Estetoscopio    │  (video facial)          │
├────────────┴──────────────────┴──────────────────────────┤
│              Pipeline de Procesamiento de Señales          │
│  Sensor Crudo → Filtro Pasa Banda → FFT → Detección de Picos │
├──────────────────────────────────────────────────────────┤
│              Clasificador ML (TFLite CNN 1D)              │
│          Entrada: ventana de 256 muestras (≈2s @ 128 Hz)   │
│          Salida: {latido_detectado: bool, bpm, confianza} │
├──────────────────────────────────────────────────────────┤
│  Grabación de Sesión  │  Retroalimentación Visual  │  Alerta Sonora │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Modo 1: Sensores Inerciales (Principal)

**Caso de uso:** El rescatista coloca el teléfono inteligente directamente contra un elemento estructural (viga, pared, pavimento) en contacto con la pila de escombros.

**Pipeline:**
1. Datos crudos de acelerómetro + giroscopio capturados a la máxima velocidad del sensor (SENSOR_DELAY_FASTEST, típicamente 100-400 Hz)
2. Compensación de gravedad mediante filtro pasa altos a 0.5 Hz
3. Selección de ejes: eje de guiñada del giroscopio (menor deriva) como principal, eje Z del acelerómetro como secundario
4. Filtro Butterworth pasa banda (4to orden, 0.5–30 Hz)
5. Ventaneo de señal: 256 muestras (≈2 s @ 128 Hz remuestreado)
6. Análisis de espectro FFT para detección de frecuencia fundamental
7. Detección de picos en dominio temporal para estimación de intervalo entre latidos
8. Clasificación CNN 1D para verificación de presencia de latido

### 5.3 Modo 2: Micrófono de Contacto (Secundario)

**Caso de uso:** Confirmación cuando el Modo 1 produce resultados inciertos. El rescatista coloca el micrófono del teléfono (o auricular conectado) contra la superficie.

**Pipeline:**
1. Audio PCM crudo capturado a 44.1 kHz
2. Remuestreado a 1 kHz
3. Filtro pasa banda 20–200 Hz (rango de energía acústica cardíaca)
4. Detección de envolvente mediante transformada de Hilbert
5. Detección de picos para estimación de frecuencia cardíaca
6. Puntuación de confianza basada en análisis de periodicidad

### 5.4 Modo 3: Cámara rPPG (Triaje en Superficie)

**Caso de uso:** Cuando el rostro o la piel de la víctima es visible (acceso en superficie o espacio vacío).

**Pipeline:**
1. Detección facial mediante MediaPipe
2. Selección de ROI (frente/mejillas)
3. Descomposición de canales de color (canal verde preferido para pulso de volumen sanguíneo)
4. Extracción de señal en ventana de 30 s
5. Estimación de frecuencia cardíaca basada en FFT
6. Adaptado de la arquitectura Google PHRM

---

## 6. Modelo de Aprendizaje Automático

### 6.1 Arquitectura

Una red neuronal convolucional 1D diseñada para inferencia en dispositivo móvil:

```
Entrada: (256, 6) — 256 muestras × 6 canales (acelerómetro xyz + giroscopio xyz)
  │
  ├─ Conv1D(32, kernel=7, ReLU) → BatchNorm → MaxPool(3)
  ├─ Conv1D(64, kernel=5, ReLU) → BatchNorm → MaxPool(3)
  ├─ Conv1D(128, kernel=3, ReLU) → BatchNorm → GlobalAvgPool
  ├─ Dense(64, ReLU) → Dropout(0.3)
  ├─ Dense(32, ReLU) → Dropout(0.2)
  └─ Dense(1, Sigmoid) → Clasificación binaria
```

### 6.2 Entrenamiento

- **Conjunto de datos:** Combinación de conjuntos públicos de SCG/GCG (CEBS, Combined Measurement of ECG, Breathing and Seismocardiogram) y datos auto-recolectados.
- **Aumento de datos:** Adición de ruido gaussiano, estiramiento temporal, escalado de amplitud, eliminación de sensores.
- **Cuantización:** Cuantización INT8 post-entrenamiento para despliegue en TFLite.
- **Tamaño objetivo:** < 500 KB.

### 6.3 Inferencia en Dispositivo

- Tiempo de ejecución: TensorFlow Lite mediante `tflite_flutter`
- Ejecución: Dart isolate (UI sin bloqueo)
- Latencia: < 10 ms por inferencia en SoCs móviles modernos
- Consumo: Mínimo (una inferencia por ventana de 2 s)

---

## 7. Métricas de Evaluación

| Métrica | Descripción | Objetivo |
|---------|-------------|----------|
| Sensibilidad | Tasa de verdaderos positivos para detección de latidos | > 90% |
| Valor Predictivo Positivo | Precisión de detecciones positivas | > 90% |
| RMSE | Error cuadrático medio para estimación de BPM | < 5 BPM |
| MAE | Error absoluto medio para BPM | < 3 BPM |
| Tasa de Falsos Positivos | Vibración no humana clasificada como latido | < 5% |
| Rango de Detección | Profundidad máxima de escombros para detección confiable | TBD (campo) |

---

## 8. Limitaciones y Trabajo Futuro

### 8.1 Limitaciones Conocidas

- **Dependencia de contacto:** Los Modos 1 y 2 requieren contacto físico directo entre el teléfono y la estructura. La detección por aire no es factible con los micrófonos actuales de teléfonos inteligentes para frecuencias cardíacas a través de escombros.
- **Variabilidad de hardware:** La calidad de los sensores MEMS varía entre modelos de teléfonos inteligentes. Los dispositivos económicos presentan pisos de ruido más altos y tasas de muestreo máximas más bajas.
- **Artefactos de movimiento:** Las operaciones de rescate implican vibración ambiental significativa (maquinaria, pisadas, viento). El filtrado robusto es crítico.
- **Variabilidad entre sujetos:** La amplitud de la vibración cardíaca varía según la complexión corporal, la edad y la patología.
- **Sin validación clínica:** Este trabajo proporciona validación de ingeniería, no ensayos clínicos para diagnóstico médico.

### 8.2 Direcciones Futuras

- Integración con sensores desplegados por drones para áreas inaccesibles.
- Red de sensores colaborativa: múltiples teléfonos formando un arreglo de detección sísmica.
- Aprendizaje por transferencia para generalizar entre modelos de teléfonos inteligentes.
- Retroalimentación de audio en tiempo real para localización direccional.
- Colaboración con equipos USAR para validación en campo.

---

## 9. Referencias

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

## 10. Licencia

MIT — Código abierto para uso humanitario.

---

**Horas de desarrollo:** `TODO`
**Estado:** Prototipo inicial
**Contacto:** (abierto a colaboraciones de equipos USAR, investigadores y desarrolladores)
