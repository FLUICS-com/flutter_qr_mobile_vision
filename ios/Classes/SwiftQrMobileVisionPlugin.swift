import Flutter
import UIKit
import MLKitVision
import MLKitBarcodeScanning

class MapArgumentReader {
    
    let args: [String: Any]?
    
    init(_ args: [String: Any]?) {
        self.args = args
    }
    
    func string(key: String) -> String? {
        return args?[key] as? String
    }
    
    func int(key: String) -> Int? {
        return (args?[key] as? NSNumber)?.intValue
    }
    
    func float(key: String) -> Float? {
        return (args?[key] as? NSNumber)?.floatValue
    }
    
    func stringArray(key: String) -> [String]? {
        return args?[key] as? [String]
    }
    
}

public class SwiftQrMobileVisionPlugin: NSObject, FlutterPlugin {
    
    let textureRegistry: FlutterTextureRegistry
    let channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel, textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        self.channel = channel
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.github.rmtmckenzie/qr_mobile_vision", binaryMessenger: registrar.messenger());
        let instance = SwiftQrMobileVisionPlugin(channel: channel, textureRegistry: registrar.textures());
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    var reader: QrReader? = nil
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let argReader = MapArgumentReader(call.arguments as? [String: Any])
        
        switch call.method{
        case "start":
            if reader != nil {
                result(FlutterError(code: "ALREADY_RUNNING", message: "Start cannot be called when already running", details: ""))
                return
            }
            
            //      let heartBeatTimeout = argReader.int(key: "heartBeatTimeout")
            
            guard let targetWidth = argReader.int(key: "targetWidth"),
                  let targetHeight = argReader.int(key: "targetHeight"),
                  let zoomFactor = argReader.float(key: "zoomFactor"),
                  let cameraPosition = argReader.int(key: "cameraLensFacing"),
                  let formatStrings = argReader.stringArray(key: "formats") else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing a required argument", details: "Expecting targetWidth, targetHeight, formats, and optionally heartbeatTimeout"))
                return
            }
            
            let options = BarcodeScannerOptions(formatStrings: formatStrings)
            
            let texture = TextureHandler(registry: textureRegistry)
            
            
            do {
                reader = try QrReader(
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    zoomFactor: zoomFactor,
                    cameraPosition: cameraPosition,
                    textureHandler: texture,
                    options: options) { [unowned self] qr in
                    self.channel.invokeMethod("qrRead", arguments: qr)
                }
                
                reader!.start();
                result([
                    "surfaceWidth": reader!.previewSize.height,
                    "surfaceHeight": reader!.previewSize.width,
                    "surfaceOrientation": 0, //TODO: check on iPAD
                    "textureId": texture.textureId!
                ])
            } catch {
                result(FlutterError(code: "PERMISSION_DENIED", message: "QrReader initialization threw an exception", details: error.localizedDescription))
            }
            
        case "stop":
            reader?.stop();
            reader = nil
            result(nil)
        case "setCameraLensFacing":
            guard
                let cameraLensFacing = (call.arguments as? NSNumber)?.intValue
            else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing a required argument", details: "Expecting setCameraLensFacing"))
                return
            }
            do {
                try reader!.setCameraLensFacing(position: cameraLensFacing)
            } catch  {
                result(FlutterError(code: "PERMISSION_DENIED", message: "QrReader initialization threw an exception", details: error.localizedDescription))
            }
            
            result(nil)
        case "getCameraLensFacing":
            if reader != nil {
                let cameraLensFacing = reader?.getCameraLensFacing()
                result(cameraLensFacing)
            } else {
                result(nil)
            }
        case "getTextureSize":
            if reader?.previewSize != nil {
                result([
                    "surfaceWidth": reader!.previewSize.height,
                    "surfaceHeight": reader!.previewSize.width,
                ])
            } else {
                result(nil)
            }
        case "toggleTorch":
            if reader != nil {
                reader?.toggleTorch()
                result(nil)
            } else {
                result(nil)
            }
        case "setZoomFactor":
            guard
                let zoomFactor = (call.arguments as? NSNumber)?.floatValue
            else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing a required argument", details: "Expecting setZoomFactor"))
                return
            }
            reader?.setZoomFactor(zoomFactor: zoomFactor)
            result(nil)
        case "getZoomFactor":
            if reader != nil {
                result(reader?.getZoomFactor())
            } else {
                result(nil)
            }
        case "heartBeat":
            //      reader?.heartBeat();
            result(nil)
        default : result(FlutterMethodNotImplemented);
        }
    }
}
