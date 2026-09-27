package com.ornobaadi.poptimer

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Hosts the `poptimer/haptics` channel, shared with Pop Calc's haptics engine. */
class MainActivity : FlutterActivity() {
    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "poptimer/haptics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        @Suppress("UNCHECKED_CAST")
                        val hits = call.argument<List<Map<String, Any>>>("hits") ?: emptyList()
                        val strength = (call.argument<Double>("strength") ?: 1.0).coerceIn(0.0, 1.0)
                        result.success(play(hits.map { Hit.from(it) }, strength))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** One haptic primitive; [delayMs] is the gap before it starts. */
    private data class Hit(val primitive: String, val scale: Double, val delayMs: Int) {
        companion object {
            fun from(m: Map<String, Any>) = Hit(
                m["p"] as String,
                (m["s"] as Number).toDouble(),
                (m["d"] as Number).toInt(),
            )
        }
    }

    /** Returns false when the device can't vibrate, so Dart can fall back. */
    private fun play(hits: List<Hit>, strength: Double): Boolean {
        val v = vibrator ?: return false
        if (!v.hasVibrator() || hits.isEmpty() || strength <= 0.0) return false

        // Best: rich composed primitives (Android 11+ with a capable motor).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val ids = hits.map { primitiveId(it.primitive) }
            if (ids.all { it != null } && v.areAllPrimitivesSupported(*ids.map { it!! }.toIntArray())) {
                val composition = VibrationEffect.startComposition()
                hits.forEachIndexed { i, hit ->
                    composition.addPrimitive(
                        ids[i]!!,
                        (hit.scale * strength).toFloat().coerceIn(0f, 1f),
                        hit.delayMs,
                    )
                }
                v.vibrate(composition.compose())
                return true
            }
        }

        // Fallback: a waveform of short, amplitude-scaled pulses.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val timings = mutableListOf<Long>()
            val amplitudes = mutableListOf<Int>()
            hits.forEach { hit ->
                val (ms, amp) = pulseFor(hit.primitive)
                timings += hit.delayMs.toLong(); amplitudes += 0
                timings += ms; amplitudes += (amp * hit.scale * strength).toInt().coerceIn(1, 255)
            }
            v.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), amplitudes.toIntArray(), -1))
            return true
        }

        @Suppress("DEPRECATION")
        v.vibrate((hits.sumOf { pulseFor(it.primitive).first + it.delayMs }).coerceAtMost(300L))
        return true
    }

    private fun primitiveId(name: String): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return when (name) {
            "click" -> VibrationEffect.Composition.PRIMITIVE_CLICK
            "tick" -> VibrationEffect.Composition.PRIMITIVE_TICK
            "quickRise" -> VibrationEffect.Composition.PRIMITIVE_QUICK_RISE
            "slowRise" -> VibrationEffect.Composition.PRIMITIVE_SLOW_RISE
            "quickFall" -> VibrationEffect.Composition.PRIMITIVE_QUICK_FALL
            "thud" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                VibrationEffect.Composition.PRIMITIVE_THUD else null
            "lowTick" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                VibrationEffect.Composition.PRIMITIVE_LOW_TICK else null
            else -> null
        }
    }

    /** Duration (ms) and max amplitude used when primitives aren't available. */
    private fun pulseFor(name: String): Pair<Long, Int> = when (name) {
        "click" -> 14L to 220
        "tick" -> 8L to 150
        "lowTick" -> 12L to 120
        "thud" -> 35L to 255
        "quickRise" -> 40L to 170
        "slowRise" -> 80L to 150
        "quickFall" -> 30L to 170
        else -> 12L to 180
    }
}
