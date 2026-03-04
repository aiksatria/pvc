package id.web.idm.pvc

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class DownloadMethodChannel(private val context: Context) : MethodCallHandler {
    companion object {
        const val CHANNEL = "id.web.idm.pvc/download"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(DownloadMethodChannel(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d("DownloadMethodChannel", "Method called: ${call.method}")
        when (call.method) {
            "downloadFile" -> {
                try {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    
                    if (url == null || fileName == null) {
                        result.error("INVALID_ARGUMENTS", "URL and fileName are required", null)
                        return
                    }
                    
                    downloadFile(url, fileName, result)
                } catch (e: Exception) {
                    Log.e("DownloadMethodChannel", "Failed to download file", e)
                    result.error("DOWNLOAD_ERROR", "Failed to download file", e.message)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun downloadFile(url: String, fileName: String, result: Result) {
        try {
            Log.d("DownloadMethodChannel", "Starting download for URL: $url")
            
            val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            
            val request = DownloadManager.Request(Uri.parse(url)).apply {
                setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI or DownloadManager.Request.NETWORK_MOBILE)
                setAllowedOverRoaming(false)
                setTitle(fileName)
                setDescription("Downloading wallpaper")
                setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            }
            
            val downloadId = downloadManager.enqueue(request)
            Log.d("DownloadMethodChannel", "Download started with ID: $downloadId")
            
            result.success(downloadId.toString())
        } catch (e: Exception) {
            Log.e("DownloadMethodChannel", "Failed to start download", e)
            result.error("DOWNLOAD_ERROR", "Failed to start download", e.message)
        }
    }
}