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
                    "openExternalUrl" -> {
                        val url = call.argument<String>("url")
                        val opened = if (url != null) tryOpenExternalUrl(url) else false
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Abre un link (ej. una tarea de Google Classroom) forzando una tarea
    // de Android independiente (FLAG_ACTIVITY_NEW_TASK). Sin esto,
    // url_launcher inicia la actividad externa dentro de la MISMA tarea
    // de Kolexa (usa el context de la Activity sin esa bandera), así que
    // en "apps recientes" se ve como una sola tarjeta que cambia de
    // ícono en vez de dos apps independientes.
    //
    // FLAG_ACTIVITY_MULTIPLE_TASK además evita que, si Classroom ya
    // queda corriendo en segundo plano (ej. el usuario tocó "inicio" en
    // vez de "atrás"), Android simplemente traiga esa tarea vieja al
    // frente TAL COMO la dejaron (ignorando el nuevo link) — con esta
    // bandera cada toque abre una instancia nueva que sí navega a la
    // tarea específica.
    private fun tryOpenExternalUrl(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
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
