import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API key — environment variable, Info.plist, or fallback
    let mapsKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]
      ?? (Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String)
      ?? "AIzaSyDVeEaBczFbeYifq5tlJSBX-hQm48A9fo4"

    if !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
