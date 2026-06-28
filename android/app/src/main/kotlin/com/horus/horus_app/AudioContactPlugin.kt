package com.horus.horus_app

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native plugin for contact microphone (stethoscope mode).
 *
 * Captures raw PCM audio from the device microphone at 44100 Hz,
 * normalizes samples to -1.0..1.0, and sends them to Dart via EventChannel.
 *
 * The Dart side handles resampling (44100 → 4000 Hz), bandpass filtering
 * (20-200 Hz), and heartbeat detection via PeakDetection.
 */
class AudioContactPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isRunning = false
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(
            binding.binaryMessenger,
            "com.horus.app/audio_stream"
        )
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(
            binding.binaryMessenger,
            "com.horus.app/audio_stream/events"
        )
        eventChannel?.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAudioStream" -> {
                startRecording()
                result.success(true)
            }
            "stopAudioStream" -> {
                stopRecording()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun startRecording() {
        if (isRunning) return

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(4096)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuffer * 2
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            audioRecord?.release()
            audioRecord = null
            return
        }

        audioRecord?.startRecording()
        isRunning = true

        val buffer = ShortArray(minBuffer / 2) // minBuffer is in bytes → short count
        recordingThread = Thread {
            android.os.Process.setThreadPriority(
                android.os.Process.THREAD_PRIORITY_URGENT_AUDIO
            )
            while (isRunning) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                if (read > 0) {
                    val samples = buffer.take(read).map {
                        (it.toDouble() / 32768.0).coerceIn(-1.0, 1.0)
                    }
                    eventSink?.success(samples)
                }
            }
        }
        recordingThread?.start()
    }

    private fun stopRecording() {
        isRunning = false
        try {
            recordingThread?.join(500)
        } catch (_: InterruptedException) {
            recordingThread?.interrupt()
        }
        recordingThread = null
        audioRecord?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // Already stopped
            }
            it.release()
        }
        audioRecord = null
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopRecording()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
    }

    companion object {
        private const val SAMPLE_RATE = 44100
    }
}
