import AVFoundation
import Flutter
import UIKit
import Vision
import os.log

final class QrReader: NSObject {
    private let textureRegistry: FlutterTextureRegistry
    private let scanner: VisionBarcodeScanner
    private let qrCallback: ([[String: Any]]) -> Void
    private let captureQueue = DispatchQueue(label: "qr_mobile_vision.capture")
    private let recognitionQueue = DispatchQueue(label: "qr_mobile_vision.recognition", qos: .userInitiated)
    private let isProcessing = Atomic(false)
    private let pixelBuffer = Atomic<CVPixelBuffer?>(nil)

    private var captureDevice: AVCaptureDevice
    private var captureSession: AVCaptureSession
    private var output: AVCaptureVideoDataOutput
    private(set) var textureId: Int64?
    private(set) var zoomFactor: Float

    var previewSize: CMVideoDimensions {
        CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
    }

    init(
        zoomFactor: Float,
        cameraPosition: Int,
        textureRegistry: FlutterTextureRegistry,
        formats: [String],
        qrCallback: @escaping ([[String: Any]]) -> Void
    ) throws {
        let camera = try Self.makeCamera(position: cameraPosition == 1 ? .back : .front)
        captureDevice = camera.device
        captureSession = camera.session
        output = camera.output
        scanner = try VisionBarcodeScanner(formats: formats)
        self.textureRegistry = textureRegistry
        self.qrCallback = qrCallback
        self.zoomFactor = zoomFactor
        super.init()
        try setZoomFactor(zoomFactor: zoomFactor)
    }

    private enum CameraError: Error {
        case unavailable
        case invalidConfiguration
    }

    private static func makeCamera(position: AVCaptureDevice.Position) throws
        -> (device: AVCaptureDevice, session: AVCaptureSession, output: AVCaptureVideoDataOutput) {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)
        let session = AVCaptureSession()
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CameraError.invalidConfiguration
        }
        session.addInput(input)
        session.addOutput(output)
        return (camera, session, output)
    }

    func start() -> Int64 {
        let id = textureRegistry.register(self)
        textureId = id
        startCapture()
        return id
    }

    func stop() {
        guard let id = textureId else { return }
        stopCapture()
        textureId = nil
        textureRegistry.unregisterTexture(id)
    }

    private func startCapture() {
        output.setSampleBufferDelegate(self, queue: captureQueue)
        captureSession.startRunning()
    }

    private func stopCapture() {
        output.setSampleBufferDelegate(nil, queue: nil)
        captureSession.stopRunning()
        // Drain frame delivery before clearing the buffer or unregistering the texture.
        captureQueue.sync { pixelBuffer.value = nil }
    }

    func toggleTorch() throws {
        guard captureDevice.hasTorch else { return }
        try captureDevice.lockForConfiguration()
        defer { captureDevice.unlockForConfiguration() }
        let newMode: AVCaptureDevice.TorchMode = captureDevice.torchMode == .on ? .off : .on
        if captureDevice.isTorchModeSupported(newMode) {
            captureDevice.torchMode = newMode
        }
    }

    func setZoomFactor(zoomFactor: Float) throws {
        try Self.configureZoom(on: captureDevice, zoomFactor: zoomFactor)
        self.zoomFactor = zoomFactor
    }

    private static func configureZoom(on device: AVCaptureDevice, zoomFactor: Float) throws {
        let target: CGFloat = [1, 2, 4].contains(zoomFactor) ? CGFloat(zoomFactor) : 2
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor = min(max(target, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
    }

    func getCameraLensFacing() -> Int? {
        switch captureDevice.position {
        case .front: return 0
        case .back: return 1
        default: return nil
        }
    }

    func setCameraLensFacing(position: Int) throws {
        let camera = try Self.makeCamera(position: position == 0 ? .front : .back)
        try Self.configureZoom(on: camera.device, zoomFactor: zoomFactor)
        stopCapture()
        captureDevice = camera.device
        captureSession = camera.session
        output = camera.output
        startCapture()
    }

    private static func imageOrientation(
        _ orientation: UIDeviceOrientation, mirrored: Bool
    ) -> CGImagePropertyOrientation {
        switch orientation {
        case .landscapeLeft: return mirrored ? .upMirrored : .up
        case .landscapeRight: return mirrored ? .downMirrored : .down
        case .portraitUpsideDown: return mirrored ? .leftMirrored : .left
        default: return mirrored ? .rightMirrored : .right
        }
    }
}

extension QrReader: FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBuffer.value.map(Unmanaged.passRetained)
    }
}

extension QrReader: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer), let id = textureId else { return }
        pixelBuffer.value = frame
        textureRegistry.textureFrameAvailable(id)

        guard !isProcessing.swap(true) else { return }
        let mirrored = connection.isVideoMirrored
        DispatchQueue.main.async {
            guard self.textureId != nil, self.output === output else {
                self.isProcessing.value = false
                return
            }
            // Flutter draws barcode bounds in the same space as the texture.
            let dimensions = self.previewSize
            let textureSize = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            let orientation = Self.imageOrientation(UIDevice.current.orientation, mirrored: mirrored)
            self.recognitionQueue.async {
                let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: orientation)
                do {
                    let barcodes = try self.scanner.recognize(handler, frameSize: textureSize, orientation: orientation)
                    DispatchQueue.main.async {
                        if self.textureId != nil, self.output === output {
                            self.qrCallback(barcodes)
                        }
                        self.isProcessing.value = false
                    }
                } catch {
                    os_log("Error decoding barcode: %@", error.localizedDescription)
                    self.isProcessing.value = false
                }
            }
        }
    }
}
