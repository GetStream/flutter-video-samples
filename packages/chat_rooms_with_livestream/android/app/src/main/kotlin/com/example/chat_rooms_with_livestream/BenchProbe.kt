package com.example.chat_rooms_with_livestream

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Process and device readings for the benchmark mode (`lib/bench/`).
 *
 * Dart has no view of CPU time, thermal state or battery, so the recorder asks
 * for them once a second over this channel. Every reading here is cheap enough
 * to take at that rate - the expensive ones (PSS) are left to the recorder to
 * throttle.
 */
class BenchProbe(private val context: Context) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(info())
                "sample" -> result.success(sample(call.argument<Boolean>("pss") ?: false))
                else -> result.notImplemented()
            }
        }
    }

    private fun info(): Map<String, Any?> = mapOf(
        "platform" to "android",
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "device" to Build.DEVICE,
        "osVersion" to Build.VERSION.RELEASE,
        "sdkInt" to Build.VERSION.SDK_INT,
        "cores" to Runtime.getRuntime().availableProcessors(),
        "abi" to Build.SUPPORTED_ABIS.firstOrNull(),
    )

    private fun sample(withPss: Boolean): Map<String, Any?> {
        val runtime = Runtime.getRuntime()
        val battery = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val tempTenths = battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val plugged = battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager

        return mapOf(
            // CPU time this process has used since it started, all threads.
            "cpuTimeMs" to Process.getElapsedCpuTime(),
            "threads" to threadCount(),
            "javaHeapMb" to (runtime.totalMemory() - runtime.freeMemory()) / MB,
            "nativeHeapMb" to Debug.getNativeHeapAllocatedSize() / MB,
            "pssMb" to if (withPss) Debug.getPss() / 1024.0 else null,
            // 0 none .. 6 shutdown. Needs API 29.
            "thermalStatus" to if (Build.VERSION.SDK_INT >= 29) power?.currentThermalStatus else null,
            // Forecast of how close the device is to severe throttling, 1.0 = throttling.
            "thermalHeadroom" to if (Build.VERSION.SDK_INT >= 30) {
                power?.getThermalHeadroom(10)?.takeUnless { it.isNaN() }?.toDouble()
            } else {
                null
            },
            "powerSave" to power?.isPowerSaveMode,
            "batteryPct" to if (level >= 0 && scale > 0) level * 100.0 / scale else null,
            "batteryTempC" to tempTenths?.takeIf { it != Int.MIN_VALUE }?.let { it / 10.0 },
            "charging" to (plugged != 0),
            "batteryCurrentMa" to batteryManager
                ?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                ?.takeIf { it != Int.MIN_VALUE }
                ?.let { it / 1000.0 },
        )
    }

    private fun threadCount(): Int? = try {
        File("/proc/self/status").useLines { lines ->
            lines.firstOrNull { it.startsWith("Threads:") }
                ?.substringAfter(':')
                ?.trim()
                ?.toIntOrNull()
        }
    } catch (e: Exception) {
        null
    }

    companion object {
        const val CHANNEL = "creator_rooms/bench"
        private const val MB = 1024.0 * 1024.0
    }
}
