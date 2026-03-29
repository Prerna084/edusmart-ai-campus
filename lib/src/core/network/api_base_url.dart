import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const _androidEmulatorBaseUrl = 'http://10.0.2.2:8000';
const _defaultLocalBaseUrl = 'http://192.168.29.170:8000'; // ✅ your laptop IP

const _loopbackHosts = {'127.0.0.1', 'localhost'};

String resolveApiBaseUrl() {
  final configuredBaseUrl = dotenv.env['API_BASE_URL']?.trim();

  // 🔥 DEBUG PRINT (VERY IMPORTANT)
  debugPrint("🔥 ENV API_BASE_URL: $configuredBaseUrl");

  // ❌ If .env is NOT loaded → fallback safely
  if (configuredBaseUrl == null || configuredBaseUrl.isEmpty) {
    debugPrint("⚠️ .env not loaded, using fallback URL");
    return _defaultBaseUrlForPlatform();
  }

  final parsedUri = Uri.tryParse(configuredBaseUrl);

  // ❌ Invalid URL → fallback
  if (parsedUri == null) {
    debugPrint("❌ Invalid API_BASE_URL format, using fallback");
    return _defaultBaseUrlForPlatform();
  }

  final host = parsedUri.host.toLowerCase();

  final shouldRewriteLoopback =
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _loopbackHosts.contains(host);

  // 🔁 Rewrite only for emulator
  if (shouldRewriteLoopback) {
    debugPrint("🔁 Rewriting localhost → 10.0.2.2 for emulator");
    return parsedUri.replace(host: '10.0.2.2').toString();
  }

  // ✅ Normal case (REAL DEVICE → use LAN IP)
  return configuredBaseUrl;
}

String _defaultBaseUrlForPlatform() {
  // 📱 Android Emulator
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    debugPrint("📱 Using Android emulator URL");
    return _androidEmulatorBaseUrl;
  }

  // 💻 Real device / fallback → use LAN IP (NOT 127.0.0.1)
  debugPrint("🌐 Using default LAN URL");
  return _defaultLocalBaseUrl;
}