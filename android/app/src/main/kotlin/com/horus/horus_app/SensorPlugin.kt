package com.horus.horus_app

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SensorPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isRunning = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        sensorManager = binding.applicationContext.getSystemService(android.content.Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        methodChannel = MethodChannel(binding.binaryMessenger, "com.horus.app/sensor_stream")
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.horus.app/sensor_stream/events")
        eventChannel?.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSensorStream" -> {
                startSensors()
                result.success(true)
            }
            "stopSensorStream" -> {
                stopSensors()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun startSensors() {
        if (isRunning) return
        isRunning = true

        accelerometer?.let {
            sensorManager.registerListener(
                this, it,
                SensorManager.SENSOR_DELAY_FASTEST
            )
        }
        gyroscope?.let {
            sensorManager.registerListener(
                this, it,
                SensorManager.SENSOR_DELAY_FASTEST
            )
        }
    }

    private fun stopSensors() {
        if (!isRunning) return
        sensorManager.unregisterListener(this)
        isRunning = false
    }

    private var lastAccel: SensorEvent? = null
    private var lastGyro: SensorEvent? = null
    private var batchCount = 0
    private val batch = mutableListOf<List<Double>>()
    private val batchSize = 20

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> lastAccel = event
            Sensor.TYPE_GYROSCOPE -> lastGyro = event
        }

        val accel = lastAccel ?: return
        val gyro = lastGyro ?: return
        if (System.currentTimeMillis() - accel.timestamp / 1_000_000 > 50) return

        val sample = listOf(
            accel.timestamp / 1_000_000_000.0,
            accel.values[0].toDouble(),
            accel.values[1].toDouble(),
            accel.values[2].toDouble(),
            gyro.values[0].toDouble(),
            gyro.values[1].toDouble(),
            gyro.values[2].toDouble()
        )

        batch.add(sample)
        batchCount++

        if (batchCount >= batchSize) {
            val toSend = batch.toList()
            batch.clear()
            batchCount = 0
            eventSink?.success(toSend)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopSensors()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
    }
}
