package com.example.masga

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MasgaAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var servicioConectado: Boolean = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val intervaloEscaneoMs = 1200L
    private var ultimoLogDebugMs = 0L
    private var ultimoIntentoOcrMs = 0L
    private var escaneoOcrEnCurso = false
    private var callbackCapturaActiva: TakeScreenshotCallback? = null
    private var ultimaPlataformaConductora: String? = null
    private var ultimoTiempoPlataformaConductoraMs = 0L
    private var escaneosOcrSinOferta = 0

    private val watchdogOcrRunnable = Runnable {
        if (escaneoOcrEnCurso) {
            Log.w("MasGaOverlay", "Watchdog OCR: liberando escaneoOcrEnCurso atascado por callback perdido")
            escaneoOcrEnCurso = false
            callbackCapturaActiva = null
        }
    }

    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    // 1) Detecta botón directo de aceptación con monto, ej: "Aceptar $41.30" o "Aceptar $42.00"
    private val regexBotonAceptarPrecio = Regex(
        """aceptar\s*(?:\$|mx\$|mxn)?\s*(\d{2,4}(?:\.\d{1,2})?)""",
        RegexOption.IGNORE_CASE
    )

    // 2) Detecta precios de oferta como "$53.20", "$67.20", "$42.00", "$114.47"
    // Ignora montos con signo "+" o "-" (que son ganancias/costos del popup MasGa),
    // ignora "/km", ignora promos ("$2,000 extra") e ignora bonos ("$29.67 de tarifa")
    private val regexPrecioConSimbolo = Regex(
        """(?<![+\-])(?:\$|MX\$|MXN\s*\$?)\s*(?![+\-])(\d{2,4}(?:\.\d{1,2})?)(?!\s*/\s*km)(?!\s*de\s+tarifa)(?!\s*extra)""",
        RegexOption.IGNORE_CASE
    )

    // 3) Respaldo: detecta montos con 2 decimales (ej. "114.47", "53.20") sin signo +/-
    private val regexPrecioDecimalRespaldo = Regex(
        """(?<![+\-\d.,])\b(\d{2,4}\.\d{2})\b(?!\s*(?:km|m|min|s|x|%|viajes|puntos|de\s+tarifa|extra))""",
        RegexOption.IGNORE_CASE
    )

    // Detecta distancias de viaje como "6 min (1.6 km)", "16 min (7.8 km)", "(2 km)" o "(650 m)"
    private val regexDistancia = Regex(
        """(?<!/)\b(\d{1,3}(?:\.\d{1,2})?)\s*km\b(?!/l)|(?:\(\s*|\bmin\s+)(\d{2,3})\s*m\b(?!in)""",
        RegexOption.IGNORE_CASE
    )

    // Detecta tiempos de viaje en minutos como "5 min (1.3 km)", "21 min (10.9 km)", "15 min"
    private val regexMinutos = Regex(
        """\b(\d{1,3})\s*(?:min|minutos|mins)\b""",
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
        servicioConectado = true
        Log.d("MasGaOverlay", "MasgaAccessibilityService conectado correctamente")
        MasgaOverlayManager.setMonitoring(this, true)
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN or
                AccessibilityServiceInfo.FEEDBACK_GENERIC or
                AccessibilityServiceInfo.FEEDBACK_VISUAL
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

        // Si el conductor toca "Aceptar" en la app de conductor mientras hay una oferta activa
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            val textoClick = event.text.joinToString(" ").lowercase()
            if (textoClick.contains("aceptar") || textoClick.contains("accept")) {
                val ultimaOferta = MasgaOverlayManager.ultimaOfertaDatos
                if (ultimaOferta != null) {
                    Log.d("MasGaOverlay", "Click en Aceptar detectado, registrando viaje automáticamente")
                    MasgaOverlayManager.registrarViajeAceptado(this, ultimaOferta)
                    MasgaOverlayManager.cerrarPopup()
                    MasgaOverlayManager.ultimaOfertaDatos = null
                }
                return
            }
        }

        escanearPantallaActual(event)
    }

    private fun escanearPantallaActual(event: AccessibilityEvent?) {
        val ahoraMs = System.currentTimeMillis()
        val bloquesTexto = mutableListOf<String>()
        val paquetesEnPantalla = mutableSetOf<String>()
        var plataformaEnPrimerPlano: String? = null
        var ventanaConductoraGrandeVisible = false
        var capturaSistemaActiva = false
        var otraAppEnPrimerPlano = false

        // 1. Si el evento proviene de una app válida (o notificación), extraer su información directa
        if (event != null) {
            val pkgEvento = event.packageName?.toString() ?: ""
            if (pkgEvento.contains("smartcapture")) {
                return
            }
            val platEvento = plataformaPorPaquete(pkgEvento)
            if (platEvento != null) {
                ultimaPlataformaConductora = platEvento
                ultimoTiempoPlataformaConductoraMs = ahoraMs
            }
            if (!esPaqueteIgnorado(pkgEvento)) {
                paquetesEnPantalla.add(pkgEvento)

                val textosEvento = mutableListOf<String>()
                for (t in event.text) {
                    t?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { textosEvento.add(it) }
                }
                event.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                    textosEvento.add(it)
                }

                val notif = event.parcelableData as? Notification
                if (notif?.extras != null) {
                    val extras = notif.extras
                    extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.let { textosEvento.add(it) }
                    extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.let { textosEvento.add(it) }
                    extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.let { textosEvento.add(it) }
                    extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.let { textosEvento.add(it) }
                }

                try {
                    val sourceNode = event.source
                    if (sourceNode != null) {
                        recolectarTextos(sourceNode, textosEvento)
                    }
                } catch (_: Exception) {
                }

                if (textosEvento.isNotEmpty()) {
                    bloquesTexto.add(textosEvento.joinToString(" "))
                }
            }
        }

        // 2. Escanear SIEMPRE rootInActiveWindow (ventana principal activa)
        try {
            val activeRoot = rootInActiveWindow
            if (activeRoot != null) {
                val pkgRoot = activeRoot.packageName?.toString() ?: ""
                val pkgRootLower = pkgRoot.lowercase()
                if (pkgRootLower.contains("smartcapture")) {
                    capturaSistemaActiva = true
                } else if (pkgRootLower.contains("com.sec.android.app.launcher") ||
                    pkgRootLower.contains("com.example.masga")
                ) {
                    otraAppEnPrimerPlano = true
                    ultimaPlataformaConductora = null
                    if (!pkgRootLower.contains("com.example.masga") && MasgaOverlayManager.ultimaOfertaFirma.isNotEmpty()) {
                        MasgaOverlayManager.ultimaOfertaFirma = ""
                        MasgaOverlayManager.cerrarPopup()
                    }
                } else if (!esPaqueteIgnorado(pkgRoot)) {
                    paquetesEnPantalla.add(pkgRoot)
                    val platRoot = plataformaPorPaquete(pkgRoot)
                    if (platRoot != null) {
                        plataformaEnPrimerPlano = platRoot
                        ventanaConductoraGrandeVisible = true
                        ultimaPlataformaConductora = platRoot
                        ultimoTiempoPlataformaConductoraMs = ahoraMs
                    } else if (pkgRoot.isNotEmpty()) {
                        otraAppEnPrimerPlano = true
                        ultimaPlataformaConductora = null
                        if (MasgaOverlayManager.ultimaOfertaFirma.isNotEmpty()) {
                            MasgaOverlayManager.ultimaOfertaFirma = ""
                            MasgaOverlayManager.cerrarPopup()
                        }
                    }
                    val textosRoot = mutableListOf<String>()
                    recolectarTextos(activeRoot, textosRoot)
                    if (textosRoot.isNotEmpty()) {
                        val bloque = textosRoot.joinToString(" ")
                        if (!bloquesTexto.contains(bloque)) {
                            bloquesTexto.add(bloque)
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }

        // 3. Escanear todas las ventanas interactivas (verificando tamaño para ignorar burbujas pequeñas)
        try {
            val listaVentanas = windows
            if (!listaVentanas.isNullOrEmpty()) {
                val bounds = Rect()
                for (ventana in listaVentanas) {
                    val root = try { ventana.root } catch (_: Exception) { null }
                    val pkgVentana = root?.packageName?.toString() ?: ""
                    val pkgVentanaLower = pkgVentana.lowercase()
                    if (pkgVentanaLower.contains("smartcapture")) {
                        capturaSistemaActiva = true
                        continue
                    }

                    val tituloVentana = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        ventana.title?.toString() ?: ""
                    } else {
                        ""
                    }

                    ventana.getBoundsInScreen(bounds)
                    val esVentanaGrande = bounds.width() > 500 && bounds.height() > 400

                    val platVentana = plataformaPorPaquete(pkgVentana)
                        ?: identificarPlataformaPorTexto(tituloVentana)

                    if (platVentana != null && esVentanaGrande) {
                        if (plataformaEnPrimerPlano == null) {
                            plataformaEnPrimerPlano = platVentana
                        }
                        ventanaConductoraGrandeVisible = true
                        ultimaPlataformaConductora = platVentana
                        ultimoTiempoPlataformaConductoraMs = ahoraMs
                    }

                    if (root == null || esPaqueteIgnorado(pkgVentana)) {
                        continue
                    }
                    paquetesEnPantalla.add(pkgVentana)

                    val textosVentana = mutableListOf<String>()
                    recolectarTextos(root, textosVentana)
                    if (textosVentana.isNotEmpty()) {
                        val bloque = textosVentana.joinToString(" ")
                        if (!bloquesTexto.contains(bloque)) {
                            bloquesTexto.add(bloque)
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }

        // Si el usuario está tomando una captura de pantalla (miniatura de Samsung SmartCapture activa),
        // pausamos este ciclo para no leer la miniatura de la captura anterior
        if (capturaSistemaActiva) return

        val textoNormalizado = normalizarTexto(bloquesTexto.joinToString(" "))
        val plataformaDetectada = plataformaEnPrimerPlano
            ?: identificarPlataformaPorTexto(textoNormalizado)
            ?: if (!otraAppEnPrimerPlano && (ahoraMs - ultimoTiempoPlataformaConductoraMs < 30_000L)) {
                ultimaPlataformaConductora
            } else {
                null
            }

        if (plataformaDetectada != null && textoNormalizado.isNotEmpty()) {
            val encontroOfertaEnNodos = analizarTextoYDispararOferta(
                plataforma = plataformaDetectada,
                textoNormalizado = textoNormalizado,
                origen = "Nodos",
                paquetesEnPantalla = paquetesEnPantalla
            )
            if (encontroOfertaEnNodos) {
                return
            }
        }

        // 4. Respaldo OCR para vistas Flutter/Vulkan (como OrderShowFlutterFragment de DiDi Conductor)
        // Si estamos dentro de DiDi / Uber / inDrive (no en el Launcher ni en MasGa), ejecutamos captura + OCR
        if (!otraAppEnPrimerPlano && plataformaDetectada != null &&
            (ventanaConductoraGrandeVisible || (ahoraMs - ultimoTiempoPlataformaConductoraMs < 30_000L))
        ) {
            intentarEscanearConCapturaOcr(plataformaDetectada)
        }
    }

    private fun intentarEscanearConCapturaOcr(plataforma: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        val ahoraMs = System.currentTimeMillis()
        // Si hay un escaneo en curso pero lleva más de 2.4s, lo liberamos para nunca quedar bloqueados
        if (escaneoOcrEnCurso && (ahoraMs - ultimoIntentoOcrMs < 2400L)) return
        if (ahoraMs - ultimoIntentoOcrMs < 1150L) return

        ultimoIntentoOcrMs = ahoraMs
        escaneoOcrEnCurso = true
        mainHandler.removeCallbacks(watchdogOcrRunnable)
        mainHandler.postDelayed(watchdogOcrRunnable, 2400L)

        // Obtenemos las coordenadas exactas del popup de MasGa ANTES de capturar
        val rectPopup = MasgaOverlayManager.obtenerRectanguloPopupEnPantalla()

        // Guardamos referencia fuerte al callback para evitar que el GC de Android 16 lo recolecte
        // ("ScreenCaptureListenerWrapper consumer not alive") mientras SurfaceFlinger captura la pantalla
        val callback = object : TakeScreenshotCallback {
            override fun onSuccess(screenshotResult: ScreenshotResult) {
                callbackCapturaActiva = null
                val hardwareBuffer = screenshotResult.hardwareBuffer
                val colorSpace = screenshotResult.colorSpace
                try {
                    val hwBitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                    // Sólo copiamos como mutable si el popup de MasGa está visible y necesitamos cubrirlo
                    val necesitaEnmascarar = rectPopup != null
                    val softBitmap = hwBitmap?.copy(Bitmap.Config.ARGB_8888, necesitaEnmascarar)
                    hwBitmap?.recycle()
                    hardwareBuffer.close()

                    if (softBitmap != null) {
                        if (rectPopup != null) {
                            enmascararZonasIgnoradas(softBitmap, rectPopup)
                        }
                        procesarBitmapConMlKit(softBitmap, plataforma, rectPopup)
                    } else {
                        mainHandler.removeCallbacks(watchdogOcrRunnable)
                        escaneoOcrEnCurso = false
                    }
                } catch (e: Exception) {
                    try { hardwareBuffer.close() } catch (_: Exception) {}
                    mainHandler.removeCallbacks(watchdogOcrRunnable)
                    escaneoOcrEnCurso = false
                    Log.e("MasGaOverlay", "Error convirtiendo captura para OCR", e)
                }
            }

            override fun onFailure(errorCode: Int) {
                callbackCapturaActiva = null
                mainHandler.removeCallbacks(watchdogOcrRunnable)
                escaneoOcrEnCurso = false
                Log.w("MasGaOverlay", "takeScreenshot no disponible temporalmente (code=$errorCode)")
            }
        }
        callbackCapturaActiva = callback

        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                callback
            )
        } catch (e: Exception) {
            callbackCapturaActiva = null
            mainHandler.removeCallbacks(watchdogOcrRunnable)
            escaneoOcrEnCurso = false
            Log.e("MasGaOverlay", "Excepción al invocar takeScreenshot", e)
        }
    }

    /**
     * Pinta un rectángulo blanco sólido sobre nuestro propio popup flotante de MasGa (si está visible).
     * Así ML Kit jamás puede leer nuestros propios montos de ganancia neta (+$22.57, $-5.98, etc.).
     */
    private fun enmascararZonasIgnoradas(bitmap: Bitmap, rectPopup: Rect?) {
        if (rectPopup == null) return
        val canvas = Canvas(bitmap)
        val paintBlanco = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val left = (rectPopup.left - 16).coerceAtLeast(0).toFloat()
        val top = (rectPopup.top - 16).coerceAtLeast(0).toFloat()
        val right = (rectPopup.right + 16).coerceAtMost(bitmap.width).toFloat()
        val bottom = (rectPopup.bottom + 16).coerceAtMost(bitmap.height).toFloat()
        canvas.drawRect(left, top, right, bottom, paintBlanco)
    }

    private fun procesarBitmapConMlKit(bitmap: Bitmap, plataforma: String, rectPopup: Rect?) {
        val image = InputImage.fromBitmap(bitmap, 0)
        textRecognizer.process(image)
            .addOnSuccessListener { visionText ->
                // Ignorar barra de estado superior (top < 80) y cualquier línea dentro del popup de MasGa
                val lineasOrdenadas = visionText.textBlocks
                    .flatMap { it.lines }
                    .filter { linea ->
                        val box = linea.boundingBox ?: return@filter true
                        val fueraDeBarraEstado = box.top >= 80
                        val fueraDePopup = rectPopup == null || !Rect.intersects(rectPopup, box)
                        fueraDeBarraEstado && fueraDePopup
                    }
                    .sortedWith(compareBy({ (it.boundingBox?.top ?: 0) / 24 }, { it.boundingBox?.left ?: 0 }))
                    .map { it.text.trim() }
                    .filter { it.isNotEmpty() && !esLineaDePopupMasga(it) }

                if (lineasOrdenadas.isNotEmpty()) {
                    val textoOcrNormalizado = normalizarTexto(lineasOrdenadas.joinToString(" "))
                    val plataformaFinal = identificarPlataformaPorTexto(textoOcrNormalizado) ?: plataforma
                    analizarTextoYDispararOferta(
                        plataforma = plataformaFinal,
                        textoNormalizado = textoOcrNormalizado,
                        origen = "OCR",
                        paquetesEnPantalla = setOf(plataformaFinal)
                    )
                }
            }
            .addOnFailureListener { e ->
                Log.e("MasGaOverlay", "Error en ML Kit OCR", e)
            }
            .addOnCompleteListener {
                try { bitmap.recycle() } catch (_: Exception) {}
                mainHandler.removeCallbacks(watchdogOcrRunnable)
                escaneoOcrEnCurso = false
            }
    }

    private fun esLineaDePopupMasga(linea: String): Boolean {
        val l = linea.lowercase()
        return l.contains("conviene") ||
            l.contains("ganancia neta") ||
            l.contains("oferta bruta") ||
            l.contains("distancia total") ||
            l.contains("ida ") ||
            l.contains("+ viaje") ||
            l.contains("= total") ||
            l.contains("costos:") ||
            l.contains("gasolina") ||
            l.contains("deprec.") ||
            l.contains("descartar") ||
            l.contains("aceptar /") ||
            l.contains("registrar") ||
            l.contains("meta:") ||
            l.contains("masga") ||
            l.contains("/ km") ||
            l.contains("/km") ||
            l.contains("/h") ||
            l.contains("/ h") ||
            l.contains("+$") ||
            l.contains("$-") ||
            l.contains("-$")
    }

    private fun analizarTextoYDispararOferta(
        plataforma: String,
        textoNormalizado: String,
        origen: String,
        paquetesEnPantalla: Set<String>
    ): Boolean {
        val txtLower = textoNormalizado.lowercase()

        val tienePalabrasDeOferta = txtLower.contains("rechazo permitido") ||
            txtLower.contains("pon tu precio") ||
            txtLower.contains("más rápido") ||
            txtLower.contains("aceptar $") ||
            txtLower.contains("puntos") ||
            txtLower.contains("uberx") ||
            txtLower.contains("exclusivo")

        // Si DiDi está en la pantalla de espera sin oferta ("Buscando solicitudes de viaje" / "Centro de viajes")
        // y NO hay palabras clave de tarjeta de oferta activa, cerramos el popup y limpiamos la firma
        val esPantallaEsperaSinOferta = !tienePalabrasDeOferta && (
            txtLower.contains("buscando solicitudes de viaje") ||
                txtLower.contains("puedes revisar el mapa mientras tanto") ||
                txtLower.contains("centro de viajes")
            )

        if (esPantallaEsperaSinOferta) {
            if (MasgaOverlayManager.ultimaOfertaFirma.isNotEmpty()) {
                MasgaOverlayManager.ultimaOfertaFirma = ""
                MasgaOverlayManager.cerrarPopup()
            }
            return false
        }

        // Extraer distancias en km (convirtiendo metros si aplica)
        val distancias = regexDistancia.findAll(textoNormalizado).mapNotNull { match ->
            val kmStr = match.groupValues[1]
            val mStr = match.groupValues[2]
            if (kmStr.isNotEmpty()) {
                kmStr.toDoubleOrNull()
            } else if (mStr.isNotEmpty()) {
                val metros = mStr.toDoubleOrNull()
                if (metros != null) metros / 1000.0 else null
            } else {
                null
            }
        }.filter { it >= 0.1 && it <= 300.0 }.toList()

        // Extraer tiempos en minutos (ej. "5 min (1.3 km)" + "21 min (10.9 km)" = 26 min)
        val tiemposMinutos = regexMinutos.findAll(textoNormalizado).mapNotNull { match ->
            match.groupValues[1].toDoubleOrNull()
        }.filter { it >= 1.0 && it <= 240.0 }.toList()

        // Extraer precios:
        // 1) Priorizar "Aceptar $67.20" o "Aceptar $84.10" si está presente en el botón naranja de DiDi
        val precioBotonAceptar = regexBotonAceptarPrecio.find(textoNormalizado)
            ?.groupValues?.getOrNull(1)?.toDoubleOrNull()
            ?.takeIf { it >= 25.0 && it <= 5000.0 }

        // 2) Precios con símbolo "$" y 2 decimales (ej. "$53.20", "$67.20", "$84.10", "$114.47")
        val preciosConSimbolo = regexPrecioConSimbolo.findAll(textoNormalizado).mapNotNull { match ->
            match.groupValues[1].toDoubleOrNull()
        }.filter { it >= 25.0 && it <= 5000.0 }.toList()

        // 3) Respaldo decimal sólo si hay al menos 2 distancias de viaje (recolección + destino)
        val preciosRespaldo = if (distancias.size >= 2 && preciosConSimbolo.isEmpty() && precioBotonAceptar == null) {
            regexPrecioDecimalRespaldo.findAll(textoNormalizado).mapNotNull { match ->
                match.groupValues[1].toDoubleOrNull()
            }.filter { it >= 25.0 && it <= 5000.0 }.toList()
        } else {
            emptyList()
        }

        val tarifaBruta = precioBotonAceptar
            ?: preciosConSimbolo.firstOrNull()
            ?: preciosRespaldo.firstOrNull()

        val esOfertaValida = tarifaBruta != null &&
            distancias.isNotEmpty() &&
            (distancias.size >= 2 || tienePalabrasDeOferta)

        val ahoraMs = System.currentTimeMillis()
        if (origen == "OCR" || ahoraMs - ultimoLogDebugMs > 2500L) {
            ultimoLogDebugMs = ahoraMs
            Log.d(
                "MasGaOverlay",
                "Scan-$origen [$plataforma] tarifa=$tarifaBruta dist=$distancias min=$tiemposMinutos valida=$esOfertaValida txt=${textoNormalizado.take(260)}"
            )
        }

        if (esOfertaValida && tarifaBruta != null) {
            escaneosOcrSinOferta = 0
            val distanciaIdaKm = if (distancias.size >= 2) distancias[0] else 0.0
            val distanciaViajeKm = if (distancias.size >= 2) distancias[1] else distancias[0]
            val distanciaTotalKm = if (distancias.size >= 2) {
                distanciaIdaKm + distanciaViajeKm
            } else {
                distancias[0]
            }

            val tiempoTotalMinutos = when {
                tiemposMinutos.size >= 2 -> tiemposMinutos[0] + tiemposMinutos[1]
                tiemposMinutos.size == 1 -> tiemposMinutos[0]
                else -> 0.0
            }

            val firma = "$plataforma:${String.format("%.2f", tarifaBruta)}:${String.format("%.1f", distanciaTotalKm)}"
            if (firma != MasgaOverlayManager.ultimaOfertaFirma) {
                Log.d("MasGaOverlay", "¡Oferta detectada por $origen! $firma (${tiempoTotalMinutos} min) -> Mostrando Popup")
                MasgaOverlayManager.ultimaOfertaFirma = firma
                MasgaOverlayManager.analizarYMostrarOferta(
                    context = this,
                    plataforma = plataforma,
                    tarifaBruta = tarifaBruta,
                    distanciaTotalKm = distanciaTotalKm,
                    tiempoTotalMinutos = tiempoTotalMinutos,
                    distanciaIdaKm = distanciaIdaKm,
                    distanciaViajeKm = distanciaViajeKm
                )
            } else {
                // La misma oferta sigue visible en pantalla: renovamos el tiempo de vida del popup
                MasgaOverlayManager.renovarTiempoPopup()
            }
            return true
        } else if (origen == "OCR" && MasgaOverlayManager.ultimaOfertaFirma.isNotEmpty()) {
            escaneosOcrSinOferta++
            if (escaneosOcrSinOferta >= 2) {
                escaneosOcrSinOferta = 0
                MasgaOverlayManager.ultimaOfertaFirma = ""
                MasgaOverlayManager.cerrarPopup()
            }
        }
        return false
    }

    private fun normalizarTexto(raw: String): String {
        var s = raw.replace('\u00A0', ' ')
        // Eliminar comas de miles como "1,250.00" -> "1250.00"
        s = s.replace(Regex("""(\d),(\d{3})\b"""), "$1$2")
        // Unir decimales separados por espacios o con coma decimal: "41 . 30" o "3,3" -> "41.30", "3.3"
        s = s.replace(Regex("""(\d)\s*[.,]\s*(\d{1,2})\b"""), "$1.$2")
        return s
    }

    private fun esPaqueteIgnorado(pkgRaw: String): Boolean {
        val pkg = pkgRaw.lowercase()
        return pkg.isEmpty() ||
            pkg.contains("com.example.masga") ||
            pkg == "com.android.systemui" ||
            pkg.contains("cocktailbarservice") ||
            pkg.contains("com.sec.android.app.launcher") ||
            pkg.contains("honeyboard") ||
            pkg.contains("inputmethod") ||
            pkg.contains("facebook.orca") ||
            pkg.contains("smartcapture")
    }

    private fun plataformaPorPaquete(pkgRaw: String): String? {
        val pkg = pkgRaw.lowercase()
        return when {
            pkg.contains("didiglobal") ||
                pkg.contains("didichuxing") ||
                pkg.contains("taxis99") ||
                pkg.contains("didi") ||
                pkg.contains("xiaojukeji") ||
                pkg.contains("sdu") -> "DiDi Conductor"
            pkg.contains("ubercab") || pkg.contains("uber") -> "Uber Driver"
            pkg.contains("indriver") || pkg.contains("indrive") || pkg.contains("sinet") -> "inDrive"
            else -> null
        }
    }

    private fun identificarPlataformaPorTexto(textoPantalla: String): String? {
        val txt = textoPantalla.lowercase()
        return when {
            txt.contains("didi conductor") ||
                txt.contains("tarifa más rápido") ||
                txt.contains("más rápido") ||
                txt.contains("pon tu precio") ||
                txt.contains("rechazo permitido") ||
                txt.contains("tarjeta bancaria verificada") ||
                txt.contains("elige un nuevo precio") -> "DiDi Conductor"
            txt.contains("uberx") || txt.contains("uber flash") || txt.contains("exclusivo") -> "Uber Driver"
            txt.contains("indrive") -> "inDrive"
            txt.contains("min (") && txt.contains("km)") -> "DiDi Conductor"
            else -> null
        }
    }

    private fun recolectarTextos(
        node: AccessibilityNodeInfo?,
        lista: MutableList<String>,
        profundidad: Int = 0
    ) {
        if (node == null || profundidad > 50) return
        node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            node.hintText?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            node.paneTitle?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
            node.tooltipText?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { lista.add(it) }
        }
        val count = node.childCount
        for (i in 0 until count) {
            val child = try { node.getChild(i) } catch (_: Exception) { null }
            recolectarTextos(child, lista, profundidad + 1)
        }
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        servicioConectado = false
        escaneoOcrEnCurso = false
        callbackCapturaActiva = null
        mainHandler.removeCallbacks(escaneoPeriodico)
        mainHandler.removeCallbacks(watchdogOcrRunnable)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        servicioConectado = false
        escaneoOcrEnCurso = false
        callbackCapturaActiva = null
        mainHandler.removeCallbacks(escaneoPeriodico)
        mainHandler.removeCallbacks(watchdogOcrRunnable)
        try { textRecognizer.close() } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onInterrupt() {
        escaneoOcrEnCurso = false
        callbackCapturaActiva = null
        mainHandler.removeCallbacks(escaneoPeriodico)
        mainHandler.removeCallbacks(watchdogOcrRunnable)
    }
}
