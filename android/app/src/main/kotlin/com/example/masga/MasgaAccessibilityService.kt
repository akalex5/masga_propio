package com.example.masga

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.graphics.Bitmap
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

    private val mainHandler = Handler(Looper.getMainLooper())
    private val intervaloEscaneoMs = 1200L
    private var ultimoLogDebugMs = 0L
    private var ultimoIntentoOcrMs = 0L
    private var escaneoOcrEnCurso = false

    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    // Detecta botón directo de aceptación con monto, ej: "Aceptar $41.30"
    private val regexBotonAceptarPrecio = Regex(
        """aceptar\s*(?:\$|mx\$|mxn)?\s*(\d{2,4}(?:\.\d{1,2})?)""",
        RegexOption.IGNORE_CASE
    )

    // Detecta precios como "$114.47", "$ 41.30", "MX$114.47" o "114.47 MXN"
    // ignorando "/km" y bonos secundarios como "$29.67 de tarifa Más Rápido"
    private val regexPrecioConSimbolo = Regex(
        """(?:\$|MX\$|MXN\s*\$?)\s*(\d{2,4}(?:\.\d{1,2})?)(?!\s*/\s*km)(?!\s*de\s+tarifa)|(\d{2,4}(?:\.\d{1,2})?)\s*MXN(?!\s*/\s*km)""",
        RegexOption.IGNORE_CASE
    )

    // Respaldo: detecta montos con 2 decimales (ej. "114.47", "41.30") cuando el símbolo "$"
    // viene en un ícono o vista separada
    private val regexPrecioDecimalRespaldo = Regex(
        """(?<!\d[.,])\b(\d{2,4}\.\d{2})\b(?!\s*(?:km|m|min|s|x|%|\s*de\s+tarifa))""",
        RegexOption.IGNORE_CASE
    )

    // Detecta distancias en km (ej. "1.5 km", "(3.3 km)") o en metros (ej. "(650 m)", "min 500 m")
    private val regexDistancia = Regex(
        """(?<!/)\b(\d{1,3}(?:\.\d{1,2})?)\s*km\b(?!/l)|(?:\(\s*|\bmin\s+)(\d{2,3})\s*m\b(?!in)""",
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
        val bloquesTexto = mutableListOf<String>()
        val paquetesEnPantalla = mutableSetOf<String>()
        var plataformaEnPrimerPlano: String? = null
        var ventanaConductoraGrandeVisible = false

        // 1. Si el evento proviene de una app válida (o notificación), extraer su información directa
        if (event != null) {
            val pkgEvento = event.packageName?.toString() ?: ""
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
                if (!esPaqueteIgnorado(pkgRoot)) {
                    paquetesEnPantalla.add(pkgRoot)
                    val platRoot = plataformaPorPaquete(pkgRoot)
                    if (platRoot != null) {
                        plataformaEnPrimerPlano = platRoot
                        ventanaConductoraGrandeVisible = true
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

        val textoNormalizado = normalizarTexto(bloquesTexto.joinToString(" "))
        val plataformaDetectada = plataformaEnPrimerPlano
            ?: identificarPlataformaPorTexto(textoNormalizado)

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

        // 4. Respaldo OCR (para vistas Flutter/Vulkan como OrderShowFlutterFragment de DiDi Conductor):
        // Si la ventana principal de DiDi / Uber / inDrive está abierta en pantalla pero los nodos de
        // accesibilidad no expusieron el precio y distancia, tomamos captura silenciosa y aplicamos OCR.
        if (ventanaConductoraGrandeVisible && plataformaDetectada != null) {
            intentarEscanearConCapturaOcr(plataformaDetectada)
        }
    }

    private fun intentarEscanearConCapturaOcr(plataforma: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        if (escaneoOcrEnCurso) return

        val ahoraMs = System.currentTimeMillis()
        if (ahoraMs - ultimoIntentoOcrMs < 1500L) return
        ultimoIntentoOcrMs = ahoraMs
        escaneoOcrEnCurso = true

        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshotResult: ScreenshotResult) {
                        val hardwareBuffer = screenshotResult.hardwareBuffer
                        val colorSpace = screenshotResult.colorSpace
                        try {
                            val hwBitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                            val softBitmap = hwBitmap?.copy(Bitmap.Config.ARGB_8888, false)
                            hwBitmap?.recycle()
                            hardwareBuffer.close()

                            if (softBitmap != null) {
                                procesarBitmapConMlKit(softBitmap, plataforma)
                            } else {
                                escaneoOcrEnCurso = false
                            }
                        } catch (e: Exception) {
                            try { hardwareBuffer.close() } catch (_: Exception) {}
                            escaneoOcrEnCurso = false
                            Log.e("MasGaOverlay", "Error convirtiendo captura para OCR", e)
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        escaneoOcrEnCurso = false
                        Log.w("MasGaOverlay", "takeScreenshot no disponible temporalmente (code=$errorCode)")
                    }
                }
            )
        } catch (e: Exception) {
            escaneoOcrEnCurso = false
            Log.e("MasGaOverlay", "Excepción al invocar takeScreenshot", e)
        }
    }

    private fun procesarBitmapConMlKit(bitmap: Bitmap, plataforma: String) {
        val image = InputImage.fromBitmap(bitmap, 0)
        textRecognizer.process(image)
            .addOnSuccessListener { visionText ->
                bitmap.recycle()
                escaneoOcrEnCurso = false

                // Ordenar las líneas de arriba hacia abajo y de izquierda a derecha,
                // filtrando cualquier texto de nuestro propio popup flotante MasGa
                val lineasOrdenadas = visionText.textBlocks
                    .flatMap { it.lines }
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
                bitmap.recycle()
                escaneoOcrEnCurso = false
                Log.e("MasGaOverlay", "Error en ML Kit OCR", e)
            }
    }

    private fun esLineaDePopupMasga(linea: String): Boolean {
        val l = linea.lowercase()
        return l.contains("conviene •") ||
            l.contains("no conviene") ||
            l.contains("ganancia neta") ||
            l.contains("oferta bruta:") ||
            l.contains("distancia total:") ||
            l.contains("costos: gasolina") ||
            l.contains("aceptar / registrar") ||
            l.contains("meta: $") ||
            l.contains("masga")
    }

    private fun analizarTextoYDispararOferta(
        plataforma: String,
        textoNormalizado: String,
        origen: String,
        paquetesEnPantalla: Set<String>
    ): Boolean {
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

        // Extraer precios:
        // 1) Priorizar "Aceptar $41.30" si está presente en el botón de DiDi
        val precioBotonAceptar = regexBotonAceptarPrecio.find(textoNormalizado)
            ?.groupValues?.getOrNull(1)?.toDoubleOrNull()
            ?.takeIf { it >= 20.0 && it <= 5000.0 }

        // 2) Precios con símbolo "$" o "MXN" (excluyendo "$29.67 de tarifa...")
        val preciosConSimbolo = regexPrecioConSimbolo.findAll(textoNormalizado).mapNotNull { match ->
            val valorStr = match.groupValues[1].ifEmpty { match.groupValues[2] }
            valorStr.toDoubleOrNull()
        }.filter { it >= 20.0 && it <= 5000.0 }.toList()

        // 3) Respaldo decimal si ya detectamos distancias de viaje en pantalla
        val preciosRespaldo = if (distancias.isNotEmpty() && preciosConSimbolo.isEmpty() && precioBotonAceptar == null) {
            regexPrecioDecimalRespaldo.findAll(textoNormalizado).mapNotNull { match ->
                match.groupValues[1].toDoubleOrNull()
            }.filter { it >= 25.0 && it <= 5000.0 }.toList()
        } else {
            emptyList()
        }

        val tarifaBruta = precioBotonAceptar
            ?: preciosConSimbolo.firstOrNull()
            ?: preciosRespaldo.firstOrNull()

        val ahoraMs = System.currentTimeMillis()
        if (origen == "OCR" || ahoraMs - ultimoLogDebugMs > 2500L) {
            ultimoLogDebugMs = ahoraMs
            Log.d(
                "MasGaOverlay",
                "Scan-$origen [$plataforma] pkgs=$paquetesEnPantalla tarifa=$tarifaBruta dist=$distancias txt=${textoNormalizado.take(280)}"
            )
        }

        if (tarifaBruta != null && distancias.isNotEmpty()) {
            val distanciaTotalKm = if (distancias.size >= 2) {
                distancias[0] + distancias[1]
            } else {
                distancias[0]
            }

            val firma = "$plataforma:${String.format("%.2f", tarifaBruta)}:${String.format("%.1f", distanciaTotalKm)}"
            if (firma != MasgaOverlayManager.ultimaOfertaFirma) {
                Log.d("MasGaOverlay", "¡Oferta detectada por $origen! $firma -> Mostrando Popup Semáforo")
                MasgaOverlayManager.ultimaOfertaFirma = firma
                MasgaOverlayManager.analizarYMostrarOferta(
                    context = this,
                    plataforma = plataforma,
                    tarifaBruta = tarifaBruta,
                    distanciaTotalKm = distanciaTotalKm
                )
            }
            return true
        } else if (origen == "OCR" && distancias.isEmpty()) {
            // Si en la captura OCR de la pantalla activa ya no hay distancias de oferta, limpiamos la firma
            MasgaOverlayManager.ultimaOfertaFirma = ""
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
            pkg.contains("facebook.orca")
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

    override fun onDestroy() {
        mainHandler.removeCallbacks(escaneoPeriodico)
        try { textRecognizer.close() } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onInterrupt() {
        mainHandler.removeCallbacks(escaneoPeriodico)
    }
}
