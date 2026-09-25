package com.example.chat_rooms_with_livestream

import io.flutter.embedding.engine.FlutterEngine
import io.getstream.video.flutter.stream_video_flutter.StreamFlutterActivity

class MainActivity : StreamFlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Only answered when the Dart side runs in benchmark mode; idle otherwise.
        BenchProbe(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
