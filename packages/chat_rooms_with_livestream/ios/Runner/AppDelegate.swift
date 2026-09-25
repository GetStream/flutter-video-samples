import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Only answered when the Dart side runs in benchmark mode; idle otherwise.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BenchProbe") {
      BenchProbe.register(messenger: registrar.messenger())
    }
  }
}

/// Process and device readings for the benchmark mode (`lib/bench/`).
///
/// Dart has no view of CPU time, thermal state or battery, so the recorder asks
/// for them once a second over this channel. Kept in this file so the sample's
/// Xcode project needs no new source entries.
enum BenchProbe {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "creator_rooms/bench", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "info": result(info())
      case "sample": result(sample())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func info() -> [String: Any?] {
    UIDevice.current.isBatteryMonitoringEnabled = true
    var system = utsname()
    uname(&system)
    let model = withUnsafeBytes(of: &system.machine) { raw in
      String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
    }
    return [
      "platform": "ios",
      "manufacturer": "Apple",
      "model": model,
      "osVersion": UIDevice.current.systemVersion,
      "cores": ProcessInfo.processInfo.activeProcessorCount,
    ]
  }

  private static func sample() -> [String: Any?] {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    let level = device.batteryLevel
    return [
      // CPU time this process has used since it started, all threads.
      "cpuTimeMs": cpuTimeMs(),
      "threads": threadCount(),
      // What Xcode's memory gauge and the jetsam limit are measured against.
      "footprintMb": footprintMb(),
      // 0 nominal, 1 fair, 2 serious, 3 critical.
      "thermalStatus": ProcessInfo.processInfo.thermalState.rawValue,
      "powerSave": ProcessInfo.processInfo.isLowPowerModeEnabled,
      "batteryPct": level >= 0 ? Double(level) * 100 : nil,
      "charging": device.batteryState == .charging || device.batteryState == .full,
    ]
  }

  private static func cpuTimeMs() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    func ms(_ t: timeval) -> Double { Double(t.tv_sec) * 1000 + Double(t.tv_usec) / 1000 }
    return ms(usage.ru_utime) + ms(usage.ru_stime)
  }

  private static func threadCount() -> Int? {
    var threads: thread_act_array_t?
    var count: mach_msg_type_number_t = 0
    guard task_threads(mach_task_self_, &threads, &count) == KERN_SUCCESS, let threads else {
      return nil
    }
    for i in 0..<Int(count) { mach_port_deallocate(mach_task_self_, threads[i]) }
    vm_deallocate(
      mach_task_self_,
      vm_address_t(UInt(bitPattern: threads)),
      vm_size_t(Int(count) * MemoryLayout<thread_t>.stride)
    )
    return Int(count)
  }

  private static func footprintMb() -> Double? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return nil }
    return Double(info.phys_footprint) / 1024 / 1024
  }
}
