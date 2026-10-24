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
import android.widget.Button
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
        distanciaTotalKm: Double
    ) {
        if (distanciaTotalKm <= 0 || tarifaBruta <= 0) return
        cargarCostosPersistidos(context)

        val costoGasolina = (distanciaTotalKm / rendimientoKmPorLitro) * precioCombustiblePorLitro
        val costoImpuestos = tarifaBruta * (tasaImpuestosPorcentaje / 100.0)
        val costoDepreciacion = distanciaTotalKm * depreciacionPorKm
        val costoTotal = costoGasolina + costoImpuestos + costoDepreciacion
        val gananciaNeta = tarifaBruta - costoTotal
        val gananciaPorKmNeto = gananciaNeta / distanciaTotalKm
        val conviene = gananciaPorKmNeto >= gananciaMetaPorKm

        val horaActual = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
        val datosViaje = mapOf<String, Any>(
            "plataforma" to plataforma,
            "tarifaBruta" to tarifaBruta,
            "distanciaKm" to distanciaTotalKm,
            "costoGasolina" to costoGasolina,
            "costoImpuestos" to costoImpuestos,
            "costoDepreciacion" to costoDepreciacion,
            "gananciaNeta" to gananciaNeta,
            "gananciaPorKmNeto" to gananciaPorKmNeto,
            "conviene" to conviene,
            "hora" to "Hoy, $horaActual"
        )
        ultimaOfertaDatos = datosViaje

        mostrarPopupFlotante(
            context = context.applicationContext,
            plataforma = plataforma,
            tarifaBruta = tarifaBruta,
            distanciaKm = distanciaTotalKm,
            costoGasolina = costoGasolina,
            costoImpuestos = costoImpuestos,
            costoDepreciacion = costoDepreciacion,
            gananciaNeta = gananciaNeta,
            gananciaPorKmNeto = gananciaPorKmNeto,
            metaPorKm = gananciaMetaPorKm,
            conviene = conviene,
            datosViaje = datosViaje
        )
    }

    fun mostrarPopupFlotante(
        context: Context,
        plataforma: String,
        tarifaBruta: Double,
        distanciaKm: Double,
        costoGasolina: Double,
        costoImpuestos: Double,
        costoDepreciacion: Double,
        gananciaNeta: Double,
        gananciaPorKmNeto: Double,
        metaPorKm: Double,
        conviene: Boolean,
        datosViaje: Map<String, Any>
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

            val colorSemaforo = if (conviene) Color.parseColor("#0D9488") else Color.parseColor("#DC2626")
            val colorFondoClaro = if (conviene) Color.parseColor("#F0FDFA") else Color.parseColor("#FEF2F2")

            // Contenedor principal de la tarjeta flotante
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                background = GradientDrawable().apply {
                    setColor(Color.WHITE)
                    cornerRadius = dp(20).toFloat()
                    setStroke(dp(3), colorSemaforo)
                }
                elevation = dp(12).toFloat()
            }

            // Encabezado tipo semáforo (Verde = Conviene / Rojo = No conviene)
            val header = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), dp(12), dp(12), dp(12))
                background = GradientDrawable().apply {
                    setColor(colorSemaforo)
                    cornerRadii = floatArrayOf(
                        dp(17).toFloat(), dp(17).toFloat(),
                        dp(17).toFloat(), dp(17).toFloat(),
                        0f, 0f, 0f, 0f
                    )
                }
            }

            val tituloSemaforo = TextView(context).apply {
                text = if (conviene) {
                    "CONVIENE • $plataforma"
                } else {
                    "NO CONVIENE • $plataforma"
                }
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTypeface(typeface, Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }

            val btnCerrarIcon = TextView(context).apply {
                text = "✕"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                setTypeface(typeface, Typeface.BOLD)
                setPadding(dp(8), dp(2), dp(8), dp(2))
                setOnClickListener { cerrarPopup() }
            }

            header.addView(tituloSemaforo)
            header.addView(btnCerrarIcon)
            card.addView(header)

            // Cuerpo de la tarjeta
            val body = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(16), dp(14), dp(16), dp(14))
            }

            // Fila principal: Ganancia Neta y $/km Neto
            val filaPrincipal = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(12), dp(10), dp(12), dp(10))
                background = GradientDrawable().apply {
                    setColor(colorFondoClaro)
                    cornerRadius = dp(12).toFloat()
                }
            }

            val colGanancia = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            colGanancia.addView(TextView(context).apply {
                text = "Ganancia Neta"
                setTextColor(Color.parseColor("#475467"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            })
            colGanancia.addView(TextView(context).apply {
                val signo = if (gananciaNeta >= 0) "+" else ""
                text = String.format(Locale.US, "%s$%.2f MXN", signo, gananciaNeta)
                setTextColor(colorSemaforo)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                setTypeface(typeface, Typeface.BOLD)
            })

            val colPorKm = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.END
            }
            colPorKm.addView(TextView(context).apply {
                text = String.format(Locale.US, "Meta: $%.2f/km", metaPorKm)
                setTextColor(Color.parseColor("#475467"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            })
            colPorKm.addView(TextView(context).apply {
                text = String.format(Locale.US, "$%.2f / km", gananciaPorKmNeto)
                setTextColor( Color.parseColor("#1E3A8A"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
                setTypeface(typeface, Typeface.BOLD)
            })

            filaPrincipal.addView(colGanancia)
            filaPrincipal.addView(colPorKm)
            body.addView(filaPrincipal)

            // Resumen bruto y distancia
            val txtBrutoDistancia = TextView(context).apply {
                text = String.format(
                    Locale.US,
                    "Oferta bruta: $%.2f MXN  •  Distancia total: %.1f km",
                    tarifaBruta,
                    distanciaKm
                )
                setTextColor(Color.parseColor("#101828"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setTypeface(typeface, Typeface.BOLD)
                setPadding(0, dp(10), 0, dp(4))
            }
            body.addView(txtBrutoDistancia)

            // Desglose de costos
            val txtDesglose = TextView(context).apply {
                text = String.format(
                    Locale.US,
                    "Costos: Gasolina -$%.2f | Imp. -$%.2f | Deprec. -$%.2f",
                    costoGasolina,
                    costoImpuestos,
                    costoDepreciacion
                )
                setTextColor(Color.parseColor("#667085"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setPadding(0, 0, 0, dp(12))
            }
            body.addView(txtDesglose)

            // Botones de acción: Descartar / Registrar viaje
            val filaBotones = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            val btnDescartar = Button(context).apply {
                text = "Descartar"
                isAllCaps = false
                setTextColor(Color.parseColor("#475467"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#F2F4F7"))
                    cornerRadius = dp(20).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(0, dp(42), 1f).apply {
                    marginEnd = dp(8)
                }
                setOnClickListener { cerrarPopup() }
            }

            val btnRegistrar = Button(context).apply {
                text = "Aceptar / Registrar"
                isAllCaps = false
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTypeface(typeface, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#2563EB"))
                    cornerRadius = dp(20).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(0, dp(42), 1.3f)
                setOnClickListener {
                    registrarViajeAceptado(context, datosViaje)
                    cerrarPopup()
                }
            }

            filaBotones.addView(btnDescartar)
            filaBotones.addView(btnRegistrar)
            body.addView(filaBotones)

            card.addView(body)

            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val screenWidth = context.resources.displayMetrics.widthPixels
            val params = WindowManager.LayoutParams(
                (screenWidth * 0.92).roundToInt(),
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dp(48)
            }

            // Permitir arrastrar la tarjeta flotante verticalmente por la pantalla
            var initialY = 0
            var initialTouchY = 0f
            header.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialY = params.y
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.y = initialY + (event.rawY - initialTouchY).roundToInt()
                        try {
                            wm.updateViewLayout(card, params)
                        } catch (_: Exception) {
                        }
                        true
                    }
                    else -> false
                }
            }

            try {
                wm.addView(card, params)
                overlayView = card
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
