package com.example.masga

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class MasgaAccessibilityService : AccessibilityService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val intervaloEscaneoMs = 1000L

    // Detecta precios como "$114.47", "$ 114.47", "MX$114.47" o "114.47 MXN"
    // ignorando montos seguidos de "/km"
    private val regexPrecio = Regex(
        """(?:\$|MX\$)\s*(\d{2,4}(?:[.,]\d{1,2})?)(?!\s*/\s*km)|(\d{2,4}(?:[.,]\d{1,2})?)\s*MXN(?!\s*/\s*km)""",
        RegexOption.IGNORE_CASE
    )

    // Detecta distancias como "(1.5 km)", "(9.5 km)", "1.5 km", "9,5 km"
    // ignorando "/km" o "Km/L"
    private val regexDistanciaKm = Regex(
        """(?<!/)\b(\d{1,3}(?:[.,]\d{1,2})?)\s*km\b(?!/l)""",
        RegexOption.IGNORE_CASE
    )

    private val escaneoPeriodico = object : Runnable {
        override fun run() {
            if (MasgaOverlayManager.isMonitoring(this@MasgaAccessibilityService)) {
                escanearPantallaActual(null)
            }
            mainHandler.postDelayed(this, intervaloEscaneoMs)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            flags = flags or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
        }
        mainHandler.removeCallbacks(escaneoPeriodico)
        mainHandler.postDelayed(escaneoPeriodico, intervaloEscaneoMs)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!MasgaOverlayManager.isMonitoring(this)) return

        val packageName = event.packageName?.toString() ?: ""
        if (packageName.contains("com.example.masga")) return

        // Si el conductor toca "Aceptar" mientras hay una oferta activa
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            val textoClick = event.text.joinToString(" ").lowercase()
            if (textoClick.contains("aceptar") || textoClick.contains("accept")) {
                val ultimaOferta = MasgaOverlayManager.ultimaOfertaDatos
                if (ultimaOferta != null) {
                    MasgaOverlayManager.registrarViajeAceptado(this, ultimaOferta)
                    MasgaOverlayManager.cerrarPopup()
                    MasgaOverlayManager.ultimaOfertaDatos = null
                }
                return
            }
        }

        escanearPantallaActual(packageName)
    }

    private fun escanearPantallaActual(eventPackageName: String?) {
        val textos = mutableListOf<String>()
        var paqueteDetectado = eventPackageName ?: ""

        // 1. Escanear todas las ventanas interactivas en pantalla (bottom sheets, diálogos y mapa)
        try {
            val listaVentanas = windows
            if (!listaVentanas.isNullOrEmpty()) {
                for (ventana in listaVentanas) {
                    val root = ventana.root ?: continue
                    val pkgVentana = root.packageName?.toString() ?: ""
                    if (pkgVentana.contains("com.example.masga") || pkgVentana == "com.android.systemui") {
                        continue
                    }
                    if (paqueteDetectado.isEmpty() && pkgVentana.isNotEmpty()) {
                        paqueteDetectado = pkgVentana
                    }
                    recolectarTextos(root, textos)
                }
            }
        } catch (_: Exception) {
        }

        // 2. Respaldo: escanear rootInActiveWindow si windows estuvo vacío
        if (textos.isEmpty()) {
            val root = rootInActiveWindow ?: return
            val pkgRoot = root.packageName?.toString() ?: ""
            if (pkgRoot.contains("com.example.masga")) return
            if (paqueteDetectado.isEmpty()) {
                paqueteDetectado = pkgRoot
            }
            recolectarTextos(root, textos)
        }

        if (textos.isEmpty()) return

        // Unir con espacio simple para que nodos separados como ["$", "114.47"] o ["1.5", "km"]
        // queden unidos como "$ 114.47" y "1.5 km"
        val textoCompleto = textos.joinToString(" ")

        val plataforma = identificarPlataforma(paqueteDetectado, textoCompleto)
        if (plataforma == null) {
            return
        }

        // Extraer precios válidos de la oferta (ej. en DiDi viene $114.47 y $29.67 de bono -> toma el mayor: $114.47)
        val precios = regexPrecio.findAll(textoCompleto).mapNotNull { match ->
            val valorStr = (match.groupValues[1].ifEmpty { match.groupValues[2] })
                .replace(",", ".")
            valorStr.toDoubleOrNull()
        }.filter { it >= 20.0 && it <= 5000.0 }.toList()

        // Extraer distancias en km (ej. en DiDi: "5 min (1.5 km)" + "17 min (9.5 km)" = 11.0 km)
        val distancias = regexDistanciaKm.findAll(textoCompleto).mapNotNull { match ->
            match.groupValues[1].replace(",", ".").toDoubleOrNull()
        }.filter { it > 0.1 && it <= 300.0 }.toList()

        if (precios.isNotEmpty() && distancias.isNotEmpty()) {
            val tarifaBruta = precios.maxOrNull() ?: return
            val distanciaTotalKm = distancias.take(2).sum()

            val firma = "$plataforma:${String.format("%.2f", tarifaBruta)}:${String.format("%.1f", distanciaTotalKm)}"
            if (firma != MasgaOverlayManager.ultimaOfertaFirma) {
                MasgaOverlayManager.ultimaOfertaFirma = firma
                MasgaOverlayManager.analizarYMostrarOferta(
                    context = this,
                    plataforma = plataforma,
                    tarifaBruta = tarifaBruta,
                    distanciaTotalKm = distanciaTotalKm
                )
            }
        } else {
            // Si ya no hay oferta en pantalla, limpiamos la firma para que vuelva a detectar la siguiente
            MasgaOverlayManager.ultimaOfertaFirma = ""
        }
    }

    private fun identificarPlataforma(packageName: String, textoPantalla: String): String? {
        val pkg = packageName.lowercase()
        val txt = textoPantalla.lowercase()

        return when {
            // En México/LatAm DiDi Conductor usa el paquete com.taxis99.driver o com.xiaojukeji / com.sdu.didi
            pkg.contains("taxis99") || pkg.contains("didi") || pkg.contains("xiaojukeji") || pkg.contains("sdu") -> "DiDi Conductor"
            pkg.contains("ubercab") || pkg.contains("uber") -> "Uber Driver"
            pkg.contains("indriver") || pkg.contains("indrive") -> "inDrive"
            // Detección por textos propios de la tarjeta de oferta de DiDi / Uber / inDrive
            txt.contains("tarifa más rápido") || txt.contains("más rápido") || txt.contains("tarjeta bancaria verificada") -> "DiDi Conductor"
            txt.contains("uberx") || txt.contains("uber flash") || txt.contains("exclusivo") -> "Uber Driver"
            txt.contains("indrive") -> "inDrive"
            txt.contains("min (") && txt.contains("km)") -> "DiDi Conductor"
            else -> null
        }
    }

    private fun recolectarTextos(node: AccessibilityNodeInfo?, lista: MutableList<String>) {
        if (node == null) return
        node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            node.paneTitle?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
            node.tooltipText?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        }
        for (i in 0 until node.childCount) {
            recolectarTextos(node.getChild(i), lista)
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(escaneoPeriodico)
        super.onDestroy()
    }

    override fun onInterrupt() {
        mainHandler.removeCallbacks(escaneoPeriodico)
    }
}
