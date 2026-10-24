package com.example.masga

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

object MasgaOverlayManager {
    private const val PREFS_NAME = "masga_native_prefs"
    private const val KEY_MONITORING = "monitoring_active"
    private const val KEY_PENDING_TRIPS = "pending_trips_json"
    private const val NOTIFICATION_CHANNEL_ID = "masga_monitor_channel"
    private const val NOTIFICATION_ID = 1001

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private const val AUTO_CLOSE_MS = 10_000L

    private val autoCerrarRunnable = Runnable {
        cerrarPopup()
        ultimaOfertaFirma = ""
    }

    // Callback para avisar en vivo a Flutter cuando se registra un viaje desde el popup
    var onTripRegisteredListener: ((Map<String, Any>) -> Unit)? = null

    // Costos sincronizados desde MisCostosScreen
    var gananciaMetaPorKm: Double = 10.0
    var rendimientoKmPorLitro: Double = 14.0
    var precioCombustiblePorLitro: Double = 24.0
    var tasaImpuestosPorcentaje: Double = 8.0
    var depreciacionPorKm: Double = 2.50

    // Última oferta mostrada para evitar duplicar el mismo popup
    var ultimaOfertaFirma: String = ""
    var ultimaOfertaDatos: Map<String, Any>? = null

    fun actualizarCostos(
        context: Context? = null,
        gananciaMeta: Double,
        rendimientoKmL: Double,
        precioCombustible: Double,
        impuestosPct: Double,
        depreciacion: Double
    ) {
        gananciaMetaPorKm = gananciaMeta
        rendimientoKmPorLitro = if (rendimientoKmL > 0) rendimientoKmL else 14.0
        precioCombustiblePorLitro = precioCombustible
        tasaImpuestosPorcentaje = impuestosPct
        depreciacionPorKm = depreciacion

        if (context != null) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putFloat("gananciaMetaPorKm", gananciaMetaPorKm.toFloat())
                .putFloat("rendimientoKmPorLitro", rendimientoKmPorLitro.toFloat())
                .putFloat("precioCombustiblePorLitro", precioCombustiblePorLitro.toFloat())
                .putFloat("tasaImpuestosPorcentaje", tasaImpuestosPorcentaje.toFloat())
                .putFloat("depreciacionPorKm", depreciacionPorKm.toFloat())
                .apply()
        }
    }

    private fun cargarCostosPersistidos(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.contains("gananciaMetaPorKm")) {
            gananciaMetaPorKm = prefs.getFloat("gananciaMetaPorKm", 10.0f).toDouble()
            rendimientoKmPorLitro = prefs.getFloat("rendimientoKmPorLitro", 14.0f).toDouble()
            precioCombustiblePorLitro = prefs.getFloat("precioCombustiblePorLitro", 24.0f).toDouble()
            tasaImpuestosPorcentaje = prefs.getFloat("tasaImpuestosPorcentaje", 8.0f).toDouble()
            depreciacionPorKm = prefs.getFloat("depreciacionPorKm", 2.50f).toDouble()
        }
    }

    fun isMonitoring(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_MONITORING, false)
    }

    fun setMonitoring(context: Context, active: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_MONITORING, active).apply()
        if (active) {
            mostrarNotificacionPermanente(context)
        } else {
            ocultarNotificacionPermanente(context)
            cerrarPopup()
            ultimaOfertaFirma = ""
            ultimaOfertaDatos = null
        }
    }

    private fun mostrarNotificacionPermanente(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Monitoreo de Viajes MasGa",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene activo el análisis de ofertas de Uber, DiDi e inDrive"
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }

        val notification = builder
            .setContentTitle("MasGa activo en segundo plano")
            .setContentText("Analizando ofertas de Uber Driver, DiDi e inDrive...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun ocultarNotificacionPermanente(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    fun analizarYMostrarOferta(
        context: Context,
        plataforma: String,
        tarifaBruta: Double,
        distanciaTotalKm: Double,
        tiempoTotalMinutos: Double = 0.0,
        distanciaIdaKm: Double = 0.0,
        distanciaViajeKm: Double = 0.0
    ) {
        if (distanciaTotalKm <= 0 || tarifaBruta <= 0) return
        cargarCostosPersistidos(context)

        // Cálculo directo solicitado:
        // $/km = Tarifa ÷ Km totales
        val pagoPorKm = tarifaBruta / distanciaTotalKm
        // $/h = (Tarifa ÷ Minutos totales) × 60
        val minutosEfectivos = if (tiempoTotalMinutos > 0.0) {
            tiempoTotalMinutos
        } else {
            ((distanciaTotalKm / 24.0) * 60.0).coerceAtLeast(3.0)
        }
        val gananciaPorHora = (tarifaBruta / minutosEfectivos) * 60.0
        val conviene = pagoPorKm >= gananciaMetaPorKm

        val costoGasolina = (distanciaTotalKm / rendimientoKmPorLitro) * precioCombustiblePorLitro
        val costoImpuestos = tarifaBruta * (tasaImpuestosPorcentaje / 100.0)
        val costoDepreciacion = distanciaTotalKm * depreciacionPorKm

        val horaActual = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
        val datosViaje = mapOf<String, Any>(
            "plataforma" to plataforma,
            "tarifaBruta" to tarifaBruta,
            "distanciaKm" to distanciaTotalKm,
            "costoGasolina" to costoGasolina,
            "costoImpuestos" to costoImpuestos,
            "costoDepreciacion" to costoDepreciacion,
            "gananciaNeta" to tarifaBruta,
            "gananciaPorKmNeto" to pagoPorKm,
            "gananciaPorHora" to gananciaPorHora,
            "conviene" to conviene,
            "hora" to "Hoy, $horaActual"
        )
        ultimaOfertaDatos = datosViaje

        mostrarPopupFlotante(
            context = context.applicationContext,
            gananciaPorHora = gananciaPorHora,
            pagoPorKm = pagoPorKm,
            conviene = conviene,
            distanciaIdaKm = distanciaIdaKm,
            distanciaViajeKm = distanciaViajeKm,
            distanciaTotalKm = distanciaTotalKm
        )
    }

    fun renovarTiempoPopup() {
        mainHandler.removeCallbacks(autoCerrarRunnable)
        mainHandler.postDelayed(autoCerrarRunnable, AUTO_CLOSE_MS)
    }

    fun mostrarPopupFlotante(
        context: Context,
        gananciaPorHora: Double,
        pagoPorKm: Double,
        conviene: Boolean,
        distanciaIdaKm: Double = 0.0,
        distanciaViajeKm: Double = 0.0,
        distanciaTotalKm: Double = 0.0
    ) {
        mainHandler.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                android.util.Log.w("MasGaOverlay", "Sin permiso de superposición (canDrawOverlays = false)")
                return@post
            }

            // Remover sincrónicamente cualquier popup anterior ANTES de crear el nuevo
            removerVistaActualSincrono()

            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val density = context.resources.displayMetrics.density
            fun dp(value: Int): Int = (value * density).roundToInt()

            val colorSemaforo = if (conviene) Color.parseColor("#10B981") else Color.parseColor("#EF4444")

            // Contenedor compacto:
            // 1) Arriba a la izquierda el badge "Conviene" / "No conviene"
            // 2) En fila intermedia: "Ida X.X km + Viaje Y.Y km = Total Z.Z km"
            // 3) Abajo en una sola fila: "+$200.00/h" a la izquierda y "$10.00/km" a la derecha
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(18), dp(14), dp(18), dp(14))
                background = GradientDrawable().apply {
                    setColor(Color.WHITE)
                    cornerRadius = dp(18).toFloat()
                    setStroke(dp(2), colorSemaforo)
                }
                elevation = dp(12).toFloat()
            }

            // Cápsula superior izquierda: "Conviene" / "No conviene"
            val badgeEstado = TextView(context).apply {
                text = if (conviene) "Conviene" else "No conviene"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTypeface(typeface, Typeface.BOLD)
                setPadding(dp(14), dp(5), dp(14), dp(5))
                background = GradientDrawable().apply {
                    setColor(colorSemaforo)
                    cornerRadius = dp(8).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.START
                }
            }
            card.addView(badgeEstado)

            // Fila intermedia: desglose de kilómetros (Ida + Viaje = Total)
            if (distanciaTotalKm > 0.0) {
                val textoDesglose = if (distanciaIdaKm > 0.0 && distanciaViajeKm > 0.0) {
                    String.format(
                        Locale.US,
                        "Ida %.1f km + Viaje %.1f km = Total %.1f km",
                        distanciaIdaKm,
                        distanciaViajeKm,
                        distanciaTotalKm
                    )
                } else {
                    String.format(Locale.US, "Total %.1f km", distanciaTotalKm)
                }

                val txtDesgloseKm = TextView(context).apply {
                    text = textoDesglose
                    setTextColor(Color.parseColor("#344054"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
                    setTypeface(typeface, Typeface.BOLD)
                    setPadding(0, dp(8), 0, 0)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                }
                card.addView(txtDesgloseKm)
            }

            // Fila inferior: "+$200.00/h" (izquierda) y "$10.00/km" (derecha)
            val filaMetricas = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(6), 0, 0)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            val txtPorHora = TextView(context).apply {
                text = String.format(Locale.US, "+$%.2f/h", gananciaPorHora)
                setTextColor(Color.parseColor("#101828"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 23f)
                setTypeface(typeface, Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }

            val txtPorKm = TextView(context).apply {
                text = String.format(Locale.US, "$%.2f/km", pagoPorKm)
                setTextColor(Color.parseColor("#101828"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 23f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.END
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            filaMetricas.addView(txtPorHora)
            filaMetricas.addView(txtPorKm)
            card.addView(filaMetricas)

            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val screenWidth = context.resources.displayMetrics.widthPixels
            val params = WindowManager.LayoutParams(
                (screenWidth * 0.88).roundToInt(),
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dp(44)
            }

            // Permitir arrastrar verticalmente, o cerrar al tocar el popup
            var initialY = 0
            var initialTouchY = 0f
            var seArrastro = false
            card.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialY = params.y
                        initialTouchY = event.rawY
                        seArrastro = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val deltaY = (event.rawY - initialTouchY).roundToInt()
                        if (kotlin.math.abs(deltaY) > dp(8)) {
                            seArrastro = true
                        }
                        params.y = initialY + deltaY
                        try {
                            wm.updateViewLayout(card, params)
                        } catch (_: Exception) {
                        }
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!seArrastro) {
                            cerrarPopup()
                        }
                        true
                    }
                    else -> false
                }
            }

            try {
                wm.addView(card, params)
                overlayView = card
                renovarTiempoPopup()
            } catch (e: Exception) {
                android.util.Log.e("MasGaOverlay", "Error al mostrar popup flotante", e)
            }
        }
    }

    fun obtenerRectanguloPopupEnPantalla(): Rect? {
        val view = overlayView ?: return null
        if (!view.isAttachedToWindow || view.width <= 0 || view.height <= 0) return null
        val loc = IntArray(2)
        view.getLocationOnScreen(loc)
        return Rect(loc[0], loc[1], loc[0] + view.width, loc[1] + view.height)
    }

    private fun removerVistaActualSincrono() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        } finally {
            overlayView = null
        }
    }

    fun cerrarPopup() {
        mainHandler.removeCallbacks(autoCerrarRunnable)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            removerVistaActualSincrono()
        } else {
            mainHandler.post {
                removerVistaActualSincrono()
            }
        }
    }

    fun registrarViajeAceptado(context: Context, datosViaje: Map<String, Any>) {
        val listener = onTripRegisteredListener
        if (listener != null) {
            mainHandler.post {
                listener(datosViaje)
            }
            return
        }

        // Si Flutter no está en memoria, guardamos en cola local para sincronizar al abrir
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(KEY_PENDING_TRIPS, "[]") ?: "[]"
        val array = try {
            JSONArray(rawJson)
        } catch (_: Exception) {
            JSONArray()
        }
        val obj = JSONObject()
        for ((k, v) in datosViaje) {
            obj.put(k, v)
        }
        array.put(obj)
        prefs.edit().putString(KEY_PENDING_TRIPS, array.toString()).apply()
    }

    fun consumirViajesPendientes(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(KEY_PENDING_TRIPS, "[]") ?: "[]"
        prefs.edit().putString(KEY_PENDING_TRIPS, "[]").apply()

        val resultado = mutableListOf<Map<String, Any>>()
        try {
            val array = JSONArray(rawJson)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val map = mutableMapOf<String, Any>()
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    map[key] = obj.get(key)
                }
                resultado.add(map)
            }
        } catch (_: Exception) {
        }
        return resultado
    }
}
