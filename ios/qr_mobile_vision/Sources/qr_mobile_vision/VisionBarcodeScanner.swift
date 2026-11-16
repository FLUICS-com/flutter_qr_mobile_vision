import Foundation
import ImageIO
import Vision

struct VisionBarcodeScanner {
    private static let formats: [String: [VNBarcodeSymbology]] = [
        "AZTEC": [.aztec],
        "CODE_128": [.code128],
        "CODE_39": [.code39],
        "CODE_93": [.code93],
        "CODABAR": [.codabar],
        "DATA_MATRIX": [.dataMatrix],
        "EAN_13": [.ean13],
        "EAN_8": [.ean8],
        "ITF": [.i2of5, .itf14],
        "PDF417": [.pdf417],
        "QR_CODE": [.qr],
        "UPC_A": [.ean13],
        "UPC_E": [.upce]
    ]

    private let request = VNDetectBarcodesRequest()
    private let hasSupportedFormats: Bool
    private let includesEAN13: Bool
    private let includesUPCA: Bool

    init(formats: [String]) throws {
#if targetEnvironment(simulator)
        // Revision 2 with CPU compute preserves Codabar on the iOS 26.5 Simulator.
        request.revision = VNDetectBarcodesRequestRevision2
        request.usesCPUOnly = true
#endif
        let all = formats.contains("ALL_FORMATS")
        includesEAN13 = all || formats.contains("EAN_13")
        includesUPCA = all || formats.contains("UPC_A")

        let supported = Set(try request.supportedSymbologies())
        let requested = all ? Self.formats.values.flatMap { $0 } : formats.flatMap { Self.formats[$0] ?? [] }
        let activeFormats = supported.intersection(requested)
        hasSupportedFormats = !activeFormats.isEmpty
        if hasSupportedFormats {
            request.symbologies = Array(activeFormats)
        }
    }

    func recognize(
        _ handler: VNImageRequestHandler,
        frameSize: CGSize,
        orientation: CGImagePropertyOrientation
    ) throws -> [[String: Any]] {
        guard hasSupportedFormats else { return [] }
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            var value = observation.payloadStringValue
            if observation.symbology == .ean13, let digits = value {
                // Vision reports UPC-A as EAN-13 with a leading zero.
                if includesUPCA && digits.count == 13 && digits.hasPrefix("0") {
                    value = String(digits.dropFirst())
                } else if !includesEAN13 {
                    return nil
                }
            }

            let box = Self.previewBounds(observation.boundingBox, frameSize: frameSize, orientation: orientation)
            var result: [String: Any] = [
                "left": box.minX, "top": box.minY, "width": box.width, "height": box.height
            ]
            result["rawValue"] = value
            return result
        }
    }

    // The painter shares the raw texture's coordinate space. Undo Vision's
    // image orientation and use a top-left origin before Flutter rotates both.
    private static func previewBounds(
        _ bounds: CGRect,
        frameSize: CGSize,
        orientation: CGImagePropertyOrientation
    ) -> CGRect {
        let oriented = CGRect(x: bounds.minX, y: 1 - bounds.maxY, width: bounds.width, height: bounds.height)
        var raw: CGRect
        switch orientation {
        case .right, .rightMirrored:
            raw = CGRect(x: oriented.minY, y: 1 - oriented.maxX, width: oriented.height, height: oriented.width)
        case .left, .leftMirrored:
            raw = CGRect(x: 1 - oriented.maxY, y: oriented.minX, width: oriented.height, height: oriented.width)
        case .down, .downMirrored:
            raw = CGRect(x: 1 - oriented.maxX, y: 1 - oriented.maxY, width: oriented.width, height: oriented.height)
        default:
            raw = oriented
        }
        switch orientation {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            raw.origin.x = 1 - raw.maxX
        default:
            break
        }
        return CGRect(
            x: raw.minX * frameSize.width,
            y: raw.minY * frameSize.height,
            width: raw.width * frameSize.width,
            height: raw.height * frameSize.height
        )
    }
}
