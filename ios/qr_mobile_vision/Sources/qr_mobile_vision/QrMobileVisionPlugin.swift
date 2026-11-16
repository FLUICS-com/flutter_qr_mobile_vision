import Flutter
import Foundation

@objc(QrMobileVisionPlugin)
public final class QrMobileVisionPlugin: NSObject, FlutterPlugin {
    private let textureRegistry: FlutterTextureRegistry
    private let channel: FlutterMethodChannel
    private var reader: QrReader?

    private init(channel: FlutterMethodChannel, textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        self.channel = channel
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.github.rmtmckenzie/qr_mobile_vision",
            binaryMessenger: registrar.messenger()
        )
        let plugin = QrMobileVisionPlugin(channel: channel, textureRegistry: registrar.textures())
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "start":
                guard reader == nil else {
                    result(FlutterError(code: "ALREADY_RUNNING", message: "Start cannot be called when already running", details: nil))
                    return
                }
                guard let arguments = call.arguments as? [String: Any],
                      arguments["targetWidth"] is NSNumber, arguments["targetHeight"] is NSNumber,
                      let zoom = arguments["zoomFactor"] as? NSNumber,
                      let lens = arguments["cameraLensFacing"] as? NSNumber,
                      let formats = arguments["formats"] as? [String] else {
                    result(invalidArgument("start"))
                    return
                }
                let reader = try QrReader(
                    zoomFactor: zoom.floatValue,
                    cameraPosition: lens.intValue,
                    textureRegistry: textureRegistry,
                    formats: formats
                ) { [weak self] barcodes in
                    self?.channel.invokeMethod("qrRead", arguments: barcodes)
                }
                self.reader = reader
                let textureId = reader.start()
                result([
                    "surfaceWidth": reader.previewSize.height,
                    "surfaceHeight": reader.previewSize.width,
                    "surfaceOrientation": 0,
                    "textureId": textureId
                ])
            case "stop":
                reader?.stop()
                reader = nil
                result(nil)
            case "setCameraLensFacing":
                guard let lens = call.arguments as? NSNumber else {
                    result(invalidArgument(call.method))
                    return
                }
                try reader?.setCameraLensFacing(position: lens.intValue)
                result(nil)
            case "getCameraLensFacing":
                result(reader?.getCameraLensFacing())
            case "getTextureSize":
                result(reader.map {
                    ["surfaceWidth": $0.previewSize.height, "surfaceHeight": $0.previewSize.width]
                })
            case "toggleTorch":
                try reader?.toggleTorch()
                result(nil)
            case "setZoomFactor":
                guard let zoom = call.arguments as? NSNumber else {
                    result(invalidArgument(call.method))
                    return
                }
                try reader?.setZoomFactor(zoomFactor: zoom.floatValue)
                result(nil)
            case "getZoomFactor":
                result(reader?.zoomFactor)
            case "heartBeat":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: "CAMERA_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func invalidArgument(_ method: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENT", message: "Missing or invalid arguments for \(method)", details: nil)
    }
}
