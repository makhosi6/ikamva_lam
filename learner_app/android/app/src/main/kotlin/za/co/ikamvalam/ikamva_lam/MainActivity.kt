package za.co.ikamvalam.ikamva_lam

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "za.co.ikamvalam/hf_token",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getIkamvaHfToken") {
                result.success(BuildConfig.IKAMVA_HF_TOKEN)
            } else {
                result.notImplemented()
            }
        }
    }
}
