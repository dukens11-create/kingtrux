package com.kingtrux.app

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "KingTrux/Maps"
        private const val KEY_PLACEHOLDER = "YOUR_GOOGLE_MAPS_API_KEY_HERE"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logMapsApiKeyStatus()
        checkGooglePlayServices()
    }

    /** Reads the Google Maps API key from AndroidManifest meta-data and logs its status. */
    private fun logMapsApiKeyStatus() {
        Log.d(TAG, "logMapsApiKeyStatus: reading com.google.android.geo.API_KEY from meta-data")
        try {
            val appInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
            when {
                apiKey.isNullOrEmpty() ->
                    Log.e(TAG, "Google Maps API key is MISSING from AndroidManifest.xml – tiles will not load")
                apiKey == KEY_PLACEHOLDER ->
                    Log.w(TAG, "Google Maps API key is still the build placeholder – tiles will not load. " +
                            "Set GOOGLE_MAPS_ANDROID_API_KEY env var and rebuild.")
                else ->
                    Log.i(TAG, "Google Maps API key is present (${apiKey.take(8)}…) – tiles should load")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read Google Maps API key from meta-data", e)
        }
    }

    /** Checks Google Play Services availability and logs / shows an error notification if needed. */
    private fun checkGooglePlayServices() {
        Log.d(TAG, "checkGooglePlayServices: verifying Google Play Services availability")
        val gpsHelper = GoogleApiAvailability.getInstance()
        val result = gpsHelper.isGooglePlayServicesAvailable(this)
        if (result == ConnectionResult.SUCCESS) {
            Log.i(TAG, "Google Play Services: available")
        } else {
            val errorMsg = gpsHelper.getErrorString(result)
            Log.w(TAG, "Google Play Services unavailable: $errorMsg (code $result) – map tiles may not load")
            if (gpsHelper.isUserResolvableError(result)) {
                // Show a system notification so the user can fix the issue.
                gpsHelper.showErrorNotification(this, result)
            }
        }
    }
}
