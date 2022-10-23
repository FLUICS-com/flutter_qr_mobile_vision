import Foundation
import AVFoundation
import MLKitVision
import MLKitBarcodeScanning
import os.log


extension BarcodeScannerOptions {
    convenience init(formatStrings: [String]) {
        let formats = formatStrings.map { (format) -> BarcodeFormat? in
            switch format  {
            case "ALL_FORMATS":
                return .all
            case "AZTEC":
                return .aztec
            case "CODE_128":
                return .code128
            case "CODE_39":
                return .code39
            case "CODE_93":
                return .code93
            case "CODABAR":
                return .codaBar
            case "DATA_MATRIX":
                return .dataMatrix
            case "EAN_13":
                return .EAN13
            case "EAN_8":
                return .EAN8
            case "ITF":
                return .ITF
            case "PDF417":
                return .PDF417
            case "QR_CODE":
                return .qrCode
            case "UPC_A":
                return .UPCA
            case "UPC_E":
                return .UPCE
            default:
                // ignore any unknown values
                return nil
            }
        }.reduce([]) { (result, format) -> BarcodeFormat in
            guard let format = format else {
                return result
            }
            return result.union(format)
        }
        
        self.init(formats: formats)
    }
}

class OrientationHandler {
    
    var lastKnownOrientation: UIDeviceOrientation!
    
    init() {
        setLastOrientation(UIDevice.current.orientation, defaultOrientation: .portrait)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil, using: orientationDidChange(_:))
    }
    
    func setLastOrientation(_ deviceOrientation: UIDeviceOrientation, defaultOrientation: UIDeviceOrientation?) {
        
        // set last device orientation but only if it is recognized
        switch deviceOrientation {
        case .unknown, .faceUp, .faceDown:
            lastKnownOrientation = defaultOrientation ?? lastKnownOrientation
            break
        default:
            lastKnownOrientation = deviceOrientation
        }
    }
    
    func orientationDidChange(_ notification: Notification) {
        let deviceOrientation = UIDevice.current.orientation
        
        let prevOrientation = lastKnownOrientation
        setLastOrientation(deviceOrientation, defaultOrientation: nil)
        
        if prevOrientation != lastKnownOrientation {
            //TODO: notify of orientation change??? (but mostly why bother...)
        }
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

protocol QrReaderResponses {
    func surfaceReceived(buffer: CMSampleBuffer)
    func qrReceived(code: String)
}

class QrReader: NSObject {
    let targetWidth: Int
    let targetHeight: Int
    let textureRegistry: FlutterTextureRegistry
    let isProcessing = Atomic<Bool>(false)
    var captureDevice: AVCaptureDevice!
    var captureSession: AVCaptureSession!
    var textureId: Int64!
    var pixelBuffer : CVPixelBuffer?
    var previewSize: CMVideoDimensions!
    var barcodeDetector: BarcodeScanner
    var cameraPosition = AVCaptureDevice.Position.back
    let qrCallback: (_:[[String: Any]]) -> Void
    var input: AVCaptureInput!
    var output: AVCaptureVideoDataOutput!
    var isTorchOn = false
    var zoomFactor = Zoom.zoom2x.rawValue
    
    init(targetWidth: Int, targetHeight: Int, zoomFactor: Float, cameraPosition: Int, textureRegistry: FlutterTextureRegistry, options: BarcodeScannerOptions, qrCallback: @escaping (_:[[String: Any]]) -> Void) {
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.textureRegistry = textureRegistry
        self.qrCallback = qrCallback
        self.barcodeDetector = BarcodeScanner.barcodeScanner(options: options)
        self.zoomFactor = zoomFactor
        self.cameraPosition = cameraPosition == 1 ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
        
        
        super.init()
        initCamera()
    }
    
    func initCamera() {
        captureSession = AVCaptureSession()
        
        if #available(iOS 10.0, *) {
            captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: cameraPosition)
        } else {
            for device in AVCaptureDevice.devices(for: AVMediaType.video) {
                if device.position == cameraPosition {
                    captureDevice = device
                    break
                }
            }
        }
        
        if captureDevice == nil {
            captureDevice = AVCaptureDevice.default(for: AVMediaType.video)!
        }
        
        // catch?
        self.input = try! AVCaptureDeviceInput.init(device: captureDevice)
        previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        
        self.output = AVCaptureVideoDataOutput()
        self.output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        self.output.alwaysDiscardsLateVideoFrames = true
        
        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        self.output.setSampleBufferDelegate(self, queue: queue)
        
        captureSession.addInput(self.input)
        captureSession.addOutput(self.output)
        setZoomFactor(zoomFactor: self.zoomFactor)
    }
    
    func start() {
        captureSession.startRunning()
        self.textureId = textureRegistry.register(self)
    }
    
    func stop() {
        captureSession.stopRunning()
        pixelBuffer = nil
        textureRegistry.unregisterTexture(textureId)
        textureId = nil
    }
    
    func toggleTorch() {
        if captureDevice.hasTorch {
            try! captureDevice.lockForConfiguration()
            if isTorchOn == false {
                captureDevice.torchMode = .on
                isTorchOn = true
            } else {
                captureDevice.torchMode = .off
                isTorchOn = false
            }
            captureDevice.unlockForConfiguration()
        }
    }
    
    func getZoomFactor() -> Float {
        return self.zoomFactor
    }
    
    func setZoomFactor(zoomFactor: Float) {
        try! captureDevice.lockForConfiguration()
        captureDevice.videoZoomFactor = CGFloat(floatToZoom(zoomValue: zoomFactor).rawValue)
        self.zoomFactor = zoomFactor
        captureDevice.unlockForConfiguration()
    }
    
    func getCameraLensFacing() -> Int? {
        switch cameraPosition {
        case .front:
            return 0
        case .back:
            return 1
        default:
            return nil
        }
    }
    
    func setCameraLensFacing(position: Int) {
        switch position {
        case 0:
            cameraPosition = .front
        case 1:
            cameraPosition = .back
        default:
            cameraPosition = .back
        }
        reloadCamera()
    }
    
    func reloadCamera() {
        captureSession?.stopRunning()
        captureSession?.removeInput(self.input)
        captureSession?.removeOutput(self.output)
        initCamera()
        captureSession?.startRunning()
    }
    
    func floatToZoom(zoomValue: Float) -> Zoom {
        switch zoomValue {
        case 1.0, 1:
            return Zoom.zoom1x
        case 2.0, 2:
            return Zoom.zoom2x
        case 4.0, 4:
            return Zoom.zoom4x
        default:
            return Zoom.zoom2x
        }
    }
    
}

extension QrReader : FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(pixelBuffer == nil){
            return nil
        }
        return  .passRetained(pixelBuffer!)
    }
}

extension QrReader: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // runs on dispatch queue
        
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        textureRegistry.textureFrameAvailable(self.textureId)
        
        guard !isProcessing.swap(true) else {
            return
        }
        
        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation(
            deviceOrientation: UIDevice.current.orientation,
            defaultOrientation: .portrait
        )
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            self.barcodeDetector.process(image) { features, error in
                self.isProcessing.value = false
                
                guard error == nil else {
                    if #available(iOS 10.0, *) {
                        os_log("Error decoding barcode %@", error!.localizedDescription)
                    } else {
                        // Fallback on earlier versions
                        NSLog("Error decoding barcode %@", error!.localizedDescription)
                    }
                    return
                }
                
                guard let features = features, !features.isEmpty else {
                    return
                }
                var barcodes = [[String: Any]]()
                
                for feature in features {
                    var barcodeMap = [String: Any]()
                    
                    barcodeMap["rawValue"] = feature.rawValue
                    barcodeMap["left"] = feature.frame.origin.x
                    barcodeMap["top"] = feature.frame.origin.y
                    barcodeMap["width"] = feature.frame.width
                    barcodeMap["height"] = feature.frame.height
                    
                    barcodes.append(barcodeMap)
                }
                self.qrCallback(barcodes)
            }
        }
    }
    
    func imageOrientation(
        deviceOrientation: UIDeviceOrientation,
        defaultOrientation: UIDeviceOrientation
    ) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return cameraPosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return cameraPosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return cameraPosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return cameraPosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            return imageOrientation(deviceOrientation: defaultOrientation, defaultOrientation: .portrait)
        }
    }
}

enum Zoom: Float {
    case zoom1x = 1.0
    case zoom2x = 2.0
    case zoom4x = 4.0
}
