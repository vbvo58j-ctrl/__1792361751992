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
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD = "com.wasl.messenger/bluetooth"
        private const val EVENTS = "com.wasl.messenger/events"
        private const val SERVICE_NAME = "BlosabRFCOMM"
        private val UUID_SERVICE: UUID = UUID.fromString("f0e1d2c3-b4a5-4678-9012-123456789abc")
    }
    private val pool = Executors.newCachedThreadPool()
    private val handler = Handler(Looper.getMainLooper())
    private val sockets = ConcurrentHashMap<String, BluetoothSocket>()
    private val writers = ConcurrentHashMap<String, PrintWriter>()
    private val running = AtomicBoolean(false)
    private var server: BluetoothServerSocket? = null
    private var sink: EventChannel.EventSink? = null
    private val adapter: BluetoothAdapter? get() = BluetoothAdapter.getDefaultAdapter()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isSupported" -> result.success(adapter != null)
                    "isEnabled" -> { if (!hasConnectPermission()) result.error("PERMISSION_DENIED", "Bluetooth permission required", null) else result.success(adapter?.isEnabled == true) }
                    "requestEnable" -> { if (!hasConnectPermission()) result.error("PERMISSION_DENIED", "Bluetooth permission required", null) else { startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)); result.success(true) } }
                    "getPairedDevices" -> {
                        if (!hasConnectPermission()) { result.error("PERMISSION_DENIED", "Bluetooth permission required", null); return@setMethodCallHandler }
                        result.success(adapter?.bondedDevices?.map { mapOf("name" to (it.name ?: "جهاز"), "address" to it.address) } ?: emptyList<Map<String, String>>())
                    }
                    "startServer" -> { if (!hasConnectPermission()) result.error("PERMISSION_DENIED", "Bluetooth permission required", null) else { startServer(result) } }
                    "connect" -> { if (!hasConnectPermission()) result.error("PERMISSION_DENIED", "Bluetooth permission required", null) else connect(call.argument<String>("address") ?: "", result) }
                    "sendMessage" -> {
                        val address = call.argument<String>("address") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val writer = writers[address]
                        if (writer == null) result.success(false) else { writer.println(message); result.success(!writer.checkError()) }
                    }
                    "disconnect" -> { val address = call.argument<String>("address"); if (address == null) closeAll() else closePeer(address); result.success(true) }
                    "stopServer" -> { stopServer(); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) { result.error("PERMISSION_DENIED", e.message, null) }
              catch (e: Exception) { result.error("BLUETOOTH_ERROR", e.message, null) }
        }
    }

    private fun hasConnectPermission(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun emit(type: String, address: String? = null, name: String? = null, message: String? = null) {
        val data = mutableMapOf<String, Any>("type" to type)
        if (address != null) data["address"] = address
        if (name != null) data["name"] = name
        if (message != null) data["message"] = message
        handler.post { sink?.success(data) }
    }

    private fun startServer(result: MethodChannel.Result) {
        if (adapter == null) { result.error("UNSUPPORTED", "Bluetooth unavailable", null); return }
        if (!running.compareAndSet(false, true)) { result.success(true); return }
        pool.execute {
            try {
                server = adapter?.listenUsingRfcommWithServiceRecord(SERVICE_NAME, UUID_SERVICE)
                handler.post { result.success(true) }
                while (running.get()) {
                    val socket = server?.accept() ?: break
                    registerPeer(socket)
                }
            } catch (e: Exception) {
                handler.post { emit("error", message = e.message ?: "تعذر تشغيل خادم البلوتوث") }
                running.set(false)
            }
        }
    }

    private fun connect(address: String, result: MethodChannel.Result) {
        pool.execute {
            try {
                val device = adapter?.getRemoteDevice(address) ?: throw Exception("جهاز غير معروف")
                val socket = device.createRfcommSocketToServiceRecord(UUID_SERVICE)
                adapter?.cancelDiscovery()
                socket.connect()
                registerPeer(socket)
                handler.post { result.success(true) }
            } catch (e: Exception) { handler.post { result.error("CONNECT_FAILED", e.message, null) } }
        }
    }

    private fun registerPeer(socket: BluetoothSocket) {
        val address = socket.remoteDevice.address
        sockets[address]?.close()
        sockets[address] = socket
        writers[address] = PrintWriter(socket.outputStream, true, Charsets.UTF_8)
        emit("connected", address, socket.remoteDevice.name ?: "جهاز")
        pool.execute {
            try {
                val reader = BufferedReader(InputStreamReader(socket.inputStream, Charsets.UTF_8))
                while (running.get() || socket.isConnected) {
                    val line = reader.readLine() ?: break
                    emit("message", address, socket.remoteDevice.name ?: "جهاز", line)
                }
            } catch (_: Exception) {
            } finally {
                if (sockets[address] === socket) closePeer(address)
            }
        }
    }

    private fun closePeer(address: String) {
        writers.remove(address)
        sockets.remove(address)?.let { try { it.close() } catch (_: Exception) {} }
        emit("disconnected", address)
    }
    private fun closeAll() { sockets.keys.toList().forEach { closePeer(it) } }
    private fun stopServer() {
        running.set(false)
        try { server?.close() } catch (_: Exception) {}
        server = null
        closeAll()
    }
    override fun onDestroy() { stopServer(); pool.shutdownNow(); super.onDestroy() }
}