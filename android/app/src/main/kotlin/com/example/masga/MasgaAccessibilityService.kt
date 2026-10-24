package com.example.masga

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class MasgaAccessibilityService : AccessibilityService() {

    private val regexPrecio = Regex("""\$\s*(\d+(?:[.,]\d{1,2})?)|(\d+(?:[.,]\d{1,2})?)\s*MXN""", RegexOption.IGNORE_CASE)
    private val regexDistanciaKm = Regex("""(\d+(?:[.,]\d{1,2})?)\s*km""", RegexOption.IGNORE_CASE)

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!MasgaOverlayManager.isMonitoring(this)) return

        val packageName = event.packageName?.toString() ?: return
        val plataforma = identificarPlataforma(packageName) ?: return

        // Si el conductor toca "Aceptar" en la app de transporte mientras hay una oferta activa,
        // registramos automáticamente el viaje y cerramos el popup.
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

        val rootNode = rootInActiveWindow ?: return
        val textos = mutableListOf<String>()
        recolectarTextos(rootNode, textos)

        if (textos.isEmpty()) return
        val textoCompleto = textos.joinToString(" | ")

        // Extraer el precio de la oferta (mayor monto detectado en la tarjeta de oferta)
        val precios = regexPrecio.findAll(textoCompleto).mapNotNull { match ->
            val valorStr = (match.groupValues[1].ifEmpty { match.groupValues[2] })
                .replace(",", ".")
            valorStr.toDoubleOrNull()
        }.filter { it >= 20.0 && it <= 5000.0 }.toList()

        // Extraer las distancias en km (ej. distancia a recoger + distancia del viaje)
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
        }
    }

    private fun identificarPlataforma(packageName: String): String? {
        val pkg = packageName.lowercase()
        return when {
            pkg.contains("ubercab.driver") || pkg.contains("uber") -> "Uber Driver"
            pkg.contains("didi") || pkg.contains("sdu.didi") -> "DiDi Conductor"
            pkg.contains("indriver") || pkg.contains("indrive") -> "inDrive"
            else -> null
        }
    }

    private fun recolectarTextos(node: AccessibilityNodeInfo?, lista: MutableList<String>) {
        if (node == null) return
        node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        for (i in 0 until node.childCount) {
            recolectarTextos(node.getChild(i), lista)
        }
    }

    override fun onInterrupt() {
        // Se invoca cuando el sistema interrumpe el servicio de accesibilidad
    }
}
