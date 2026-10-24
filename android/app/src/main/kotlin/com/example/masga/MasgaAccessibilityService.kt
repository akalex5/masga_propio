package com.example.masga

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class MasgaAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Cimiento listo para extraer texto de viajes (precio y distancia) en pantalla
    }

    override fun onInterrupt() {
        // Se invoca cuando el sistema interrumpe el servicio de accesibilidad
    }
}
