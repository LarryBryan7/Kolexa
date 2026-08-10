package com.kolexa.kolexa

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "kolexa/manufacturer_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    "openAutostart" -> {
                        val opened = tryOpenAutostartSettings()
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun tryOpenAutostartSettings(): Boolean {
        val intentsToTry = buildAutostartIntents()
        for (intent in intentsToTry) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Intentar el siguiente
            }
        }
        // Fallback: configuración general de batería
        return try {
            val fallback = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun buildAutostartIntents(): List<Intent> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            // ── Xiaomi / MIUI ────────────────────────────────
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> listOf(
                Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                },
                Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.securitycenter.MainActivity"
                    )
                }
            )

            // ── Huawei / EMUI ────────────────────────────────
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                Intent().apply {
                    setClassName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity"
                    )
                }
            )

            // ── Samsung / One UI ─────────────────────────────
            manufacturer.contains("samsung") -> listOf(
                Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity"
                    )
                },
                Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.sm.policy",
                        "com.samsung.android.sm.policy.battery.BatterySaverModeActivity"
                    )
                },
                Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            )

            // ── Oppo / Realme / ColorOS ──────────────────────
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> listOf(
                Intent().apply {
                    setClassName(
                        "com.coloros.oppoguardelf",
                        "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity"
                    )
                }
            )

            // ── OnePlus ──────────────────────────────────────
            manufacturer.contains("oneplus") -> listOf(
                Intent().apply {
                    setClassName(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                    )
                }
            )

            // ── Vivo ─────────────────────────────────────────
            manufacturer.contains("vivo") -> listOf(
                Intent().apply {
                    setClassName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
            )

            else -> emptyList()
        }
    }
}
