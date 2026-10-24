package com.example.masga

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.masga/accessibility"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        MasgaOverlayManager.onTripRegisteredListener = { datosViaje ->
            channel.invokeMethod("onTripRegistered", datosViaje)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityPermissionEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "isMonitoringActive" -> {
                    result.success(MasgaOverlayManager.isMonitoring(this))
                }
                "startMonitoring" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        aplicarCostosDesdeMapa(args)
                    }
                    MasgaOverlayManager.setMonitoring(this, true)
                    result.success(true)
                }
                "stopMonitoring" -> {
                    MasgaOverlayManager.setMonitoring(this, false)
                    result.success(true)
                }
                "updateCosts" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        aplicarCostosDesdeMapa(args)
                    }
                    result.success(true)
                }
                "showSimulatedOffer" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        aplicarCostosDesdeMapa(args)
                        val plataforma = (args["plataforma"] as? String) ?: "Uber Driver"
                        val tarifaBruta = (args["tarifaBruta"] as? Number)?.toDouble() ?: 115.0
                        val distanciaKm = (args["distanciaKm"] as? Number)?.toDouble() ?: 7.5
                        MasgaOverlayManager.analizarYMostrarOferta(
                            context = this,
                            plataforma = plataforma,
                            tarifaBruta = tarifaBruta,
                            distanciaTotalKm = distanciaKm
                        )
                    }
                    result.success(true)
                }
                "consumePendingTrips" -> {
                    val pendientes = MasgaOverlayManager.consumirViajesPendientes(this)
                    result.success(pendientes)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        MasgaOverlayManager.onTripRegisteredListener = null
        methodChannel = null
        super.onDestroy()
    }

    private fun aplicarCostosDesdeMapa(args: Map<*, *>) {
        val gananciaMeta = (args["gananciaPorKm"] as? Number)?.toDouble()
            ?: MasgaOverlayManager.gananciaMetaPorKm
        val rendimientoKmL = (args["gastoCombustible"] as? Number)?.toDouble()
            ?: MasgaOverlayManager.rendimientoKmPorLitro
        val precioCombustible = (args["precioCombustible"] as? Number)?.toDouble()
            ?: MasgaOverlayManager.precioCombustiblePorLitro
        val impuestosPct = (args["tasaImpuestos"] as? Number)?.toDouble()
            ?: MasgaOverlayManager.tasaImpuestosPorcentaje
        val depreciacion = (args["depreciacionPorKm"] as? Number)?.toDouble()
            ?: MasgaOverlayManager.depreciacionPorKm

        MasgaOverlayManager.actualizarCostos(
            context = this,
            gananciaMeta = gananciaMeta,
            rendimientoKmL = rendimientoKmL,
            precioCombustible = precioCombustible,
            impuestosPct = impuestosPct,
            depreciacion = depreciacion
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, MasgaAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }
}
