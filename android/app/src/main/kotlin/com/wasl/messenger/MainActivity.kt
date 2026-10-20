package com.wasl.messenger

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHODS =
            "com.wasl.messenger/bluetooth"

        private const val EVENTS =
            "com.wasl.messenger/events"

        private const val SERVICE_NAME = "WaslRFCOMM"

        private val UUID_WASL = UUID.fromString(
            "f0e1d2c3-b4a5-4678-9012-123456789abc"
        )
    }

    private val pool = Executors.newCachedThreadPool()
    private val handler = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)

    private val sockets =
        ConcurrentHashMap<String, BluetoothSocket>()

    private val writers =
        ConcurrentHashMap<String, PrintWriter>()

    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var server: BluetoothServerSocket? = null

    private val adapter: BluetoothAdapter?
        get() = BluetoothAdapter.getDefaultAdapter()

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        EventChannel(
            engine.dartExecutor.binaryMessenger,
            EVENTS
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink?
            ) {
                sink = events
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            METHODS
        ).setMethodCallHandler { call, result ->

            try {
                when (call.method) {

                    "isSupported" -> {
                        result.success(adapter != null)
                    }

                    "isEnabled" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "Bluetooth permission required",
                                null
                            )
                        } else {
                            result.success(
                                adapter?.isEnabled == true
                            )
                        }
                    }

                    "requestEnable" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "Bluetooth permission required",
                                null
                            )
                        } else {
                            startActivity(
                                Intent(
                                    BluetoothAdapter.ACTION_REQUEST_ENABLE
                                )
                            )
                            result.success(true)
                        }
                    }

                    "getPairedDevices" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "Bluetooth permission required",
                                null
                            )
                        } else {
                            val devices =
                                adapter?.bondedDevices?.map {
                                    mapOf(
                                        "name" to (it.name ?: "جهاز"),
                                        "address" to it.address
                                    )
                                } ?: emptyList<Map<String, String>>()

                            result.success(devices)
                        }
                    }

                    "startServer" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "صلاحية البلوتوث غير متاحة",
                                null
                            )
                        } else {
                            startServer(result)
                        }
                    }

                    "connect" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "صلاحية البلوتوث غير متاحة",
                                null
                            )
                        } else {
                            val address =
                                call.argument<String>("address")

                            if (address.isNullOrBlank()) {
                                result.error(
                                    "ADDRESS",
                                    "عنوان الجهاز مطلوب",
                                    null
                                )
                            } else {
                                connect(address, result)
                            }
                        }
                    }

                    "sendMessage" -> {
                        if (!hasConnectPermission()) {
                            result.error(
                                "PERMISSION",
                                "صلاحية البلوتوث غير متاحة",
                                null
                            )
                        } else {
                            val address =
                                call.argument<String>("address")

                            val message =
                                call.argument<String>("message")

                            if (address.isNullOrBlank() ||
                                message == null
                            ) {
                                result.error(
                                    "ARGUMENT",
                                    "بيانات الرسالة ناقصة",
                                    null
                                )
                            } else {
                                pool.execute {
                                    try {
                                        val writer = writers[address]
                                            ?: throw IllegalStateException(
                                                "الجهاز غير متصل"
                                            )

                                        synchronized(writer) {
                                            writer.println(message)
                                            writer.flush()

                                            if (writer.checkError()) {
                                                throw java.io.IOException(
                                                    "فشل الإرسال"
                                                )
                                            }
                                        }

                                        handler.post {
                                            result.success(true)
                                        }
                                    } catch (e: Exception) {
                                        handler.post {
                                            result.error(
                                                "SEND",
                                                e.message
                                                    ?: "فشل إرسال الرسالة",
                                                null
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    "disconnect" -> {
                        val address =
                            call.argument<String>("address")

                        if (address.isNullOrBlank()) {
                            closeAll()
                        } else {
                            closePeer(address)
                        }

                        result.success(true)
                    }

                    "stopServer" -> {
                        stopServer()
                        result.success(true)
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: SecurityException) {
                result.error(
                    "PERMISSION",
                    e.message ?: "صلاحية البلوتوث غير متاحة",
                    null
                )
            } catch (e: Exception) {
                result.error(
                    "NATIVE_ERROR",
                    e.message ?: "حدث خطأ في البلوتوث",
                    null
                )
            }
        }
    }

    private fun hasConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun emit(
        type: String,
        address: String? = null,
        name: String? = null,
        message: String? = null
    ) {
        val event = mutableMapOf<String, Any>(
            "type" to type
        )

        address?.let { event["address"] = it }
        name?.let { event["name"] = it }
        message?.let { event["message"] = it }

        handler.post {
            sink?.success(event)
        }
    }

    private fun startServer(
        result: MethodChannel.Result
    ) {
        val bluetooth = adapter

        if (bluetooth == null) {
            result.error(
                "UNSUPPORTED",
                "لا يوجد بلوتوث",
                null
            )
            return
        }

        if (!hasConnectPermission()) {
            result.error(
                "PERMISSION",
                "صلاحية البلوتوث غير متاحة",
                null
            )
            return
        }

        if (!bluetooth.isEnabled) {
            result.error(
                "BLUETOOTH_OFF",
                "شغّل البلوتوث أولاً",
                null
            )
            return
        }

        if (!running.compareAndSet(false, true)) {
            result.success(true)
            return
        }

        pool.execute {
            try {
                val listeningSocket =
                    bluetooth.listenUsingRfcommWithServiceRecord(
                        SERVICE_NAME,
                        UUID_WASL
                    )

                server = listeningSocket

                handler.post {
                    result.success(true)
                }

                emit("serverStarted")

                while (running.get()) {
                    val client = listeningSocket.accept()

                    pool.execute {
                        registerPeer(client)
                    }
                }
            } catch (e: Exception) {
                if (running.get()) {
                    emit(
                        "serverError",
                        message = e.message ?: "خطأ بالخادم"
                    )

                    handler.post {
                        running.set(false)
                    }
                }
            } finally {
                running.set(false)

                try {
                    server?.close()
                } catch (_: Exception) {
                }

                server = null
            }
        }
    }

    private fun connect(
        address: String,
        result: MethodChannel.Result
    ) {
        pool.execute {
            var socket: BluetoothSocket? = null

            try {
                val device = adapter?.getRemoteDevice(address)
                    ?: throw IllegalStateException(
                        "البلوتوث غير متاح"
                    )

                adapter?.cancelDiscovery()

                socket =
                    device.createRfcommSocketToServiceRecord(
                        UUID_WASL
                    )

                socket.connect()
                registerPeer(socket)

                handler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {
                }

                emit(
                    "connectionError",
                    address,
                    message = e.message ?: "تعذر الاتصال بالجهاز"
                )

                handler.post {
                    result.error(
                        "CONNECT_FAILED",
                        e.message ?: "تعذر الاتصال بالجهاز",
                        null
                    )
                }
            }
        }
    }

    private fun registerPeer(socket: BluetoothSocket) {
        val address = socket.remoteDevice.address

        val name = try {
            socket.remoteDevice.name ?: "جهاز"
        } catch (_: Exception) {
            "جهاز"
        }

        closePeer(address, false)

        try {
            val writer = PrintWriter(
                OutputStreamWriter(
                    socket.outputStream,
                    Charsets.UTF_8
                ),
                true
            )

            sockets[address] = socket
            writers[address] = writer

            emit(
                "connected",
                address,
                name
            )

            pool.execute {
                try {
                    val reader = BufferedReader(
                        InputStreamReader(
                            socket.inputStream,
                            Charsets.UTF_8
                        )
                    )

                    while (true) {
                        val line = reader.readLine() ?: break

                        emit(
                            "message",
                            address,
                            name,
                            line
                        )
                    }
                } catch (e: Exception) {
                    if (running.get() || sockets[address] === socket) {
                        emit(
                            "connectionError",
                            address,
                            message = e.message ?: "انقطع الاتصال"
                        )
                    }
                } finally {
                    if (sockets[address] === socket) {
                        closePeer(address)
                    } else {
                        try {
                            socket.close()
                        } catch (_: Exception) {
                        }
                    }
                }
            }
        } catch (e: Exception) {
            try {
                socket.close()
            } catch (_: Exception) {
            }

            emit(
                "connectionError",
                address,
                message = e.message ?: "تعذر إعداد الاتصال"
            )
        }
    }

    private fun closePeer(
        address: String,
        notify: Boolean = true
    ) {
        writers.remove(address)

        try {
            sockets.remove(address)?.close()
        } catch (_: Exception) {
        }

        if (notify) {
            emit("disconnected", address)
        }
    }

    private fun closeAll() {
        sockets.keys.toList().forEach { address ->
            closePeer(address)
        }
    }

    private fun stopServer() {
        running.set(false)

        try {
            server?.close()
        } catch (_: Exception) {
        }

        server = null
        closeAll()
        emit("serverStopped")
    }

    override fun onDestroy() {
        stopServer()
        pool.shutdownNow()
        super.onDestroy()
    }
}