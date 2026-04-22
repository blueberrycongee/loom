import CoreML
import Foundation
import Vision
import LoomCore

/// Extracts a CLIP embedding from a bundled MobileCLIP CoreML model.
///
/// MobileCLIP is Apple's on-device-optimised variant of CLIP. Its image
/// encoder produces a 512-dim L2-normalised embedding that captures
/// semantic content — "cat on couch" clusters separately from "cat on
/// grass" — richer than Vision's screener-grade feature-print.
///
/// **Model provisioning**: place a compiled ``MobileCLIP.mlmodelc``
/// inside ``Sources/LoomIndex/Resources/``. Convert from PyTorch via:
///
///     import coremltools as ct
///     model = ct.convert(clip_image_encoder, ...)
///     model.save("MobileCLIP.mlpackage")
///
/// then compile with `xcrun coremlcompiler compile MobileCLIP.mlpackage .`
///
/// If the model file is absent the extractor returns ``nil`` for every
/// photo — the clusterer seamlessly falls back to VNFeaturePrint, so the
/// app is fully functional without the model bundled.
enum CLIPFeatures {

    private static let modelVersion = 1000

    /// Lazily loaded CoreML model. `nil` if the resource is missing.
    private static let coreMLModel: MLModel? = {
        guard let url = Bundle.module.url(
            forResource: "MobileCLIP",
            withExtension: "mlmodelc"
        ) else {
            #if DEBUG
            print("[CLIPFeatures] MobileCLIP.mlmodelc not found in bundle — CLIP extraction disabled.")
            #endif
            return nil
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try? MLModel(contentsOf: url, configuration: config)
    }()

    /// The VNCoreMLModel wraps the raw MLModel for use with the Vision
    /// pipeline, which handles image resizing and pixel-format conversion
    /// automatically based on the model's input description.
    private static let vnModel: VNCoreMLModel? = {
        guard let ml = coreMLModel else { return nil }
        return try? VNCoreMLModel(for: ml)
    }()

    /// Extract a CLIP embedding. Returns ``nil`` if the model is not
    /// bundled, the image can't be read, or inference fails.
    static func extract(from url: URL) -> FeaturePrint? {
        guard let vnModel else { return nil }

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(url: url, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results as? [VNCoreMLFeatureValueObservation],
              let multiArray = results.first?.featureValue.multiArrayValue
        else { return nil }

        let bytes = multiArrayToData(multiArray)
        guard !bytes.isEmpty else { return nil }
        return FeaturePrint(version: modelVersion, bytes: bytes)
    }

    /// Copy an MLMultiArray of Float32 into a contiguous Data blob,
    /// matching the format FeaturePrint expects for distance computation.
    private static func multiArrayToData(_ array: MLMultiArray) -> Data {
        let count = array.count
        guard count > 0 else { return Data() }
        var floats = [Float](repeating: 0, count: count)
        let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count { floats[i] = ptr[i] }

        // L2-normalise so distance() behaves identically to VN prints.
        var norm: Float = 0
        for f in floats { norm += f * f }
        norm = norm.squareRoot()
        if norm > 0 {
            for i in 0..<count { floats[i] /= norm }
        }

        return floats.withUnsafeBytes { Data($0) }
    }
}
