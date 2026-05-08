import Foundation
import Vision

public struct VisionOCREngine: OCREngine {
    public init() {}

    public func recognize(cgImage: CGImage) async throws -> [RecognizedText] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[RecognizedText], Error>) in
            let req = VNRecognizeTextRequest { req, err in
                if let err = err {
                    cont.resume(throwing: OCRError.engineFailure(err.localizedDescription))
                    return
                }
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                let boxes: [RecognizedText] = obs.compactMap { o in
                    guard let cand = o.topCandidates(1).first, !cand.string.isEmpty else { return nil }
                    return RecognizedText(rect: o.boundingBox, text: cand.string)
                }
                cont.resume(returning: boxes)
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            // Vision (as of macOS 14) supports: en, fr, it, de, es, pt-BR, zh-Hans/Hant,
            // yue, ko, ja, ru, uk, th, vi, ar. No Indic scripts. We let it auto-detect for
            // the European/CJK set; Indic-script PDFs should use Gemini mode (toggle in UI).
            req.automaticallyDetectsLanguage = true

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])
            } catch {
                cont.resume(throwing: OCRError.engineFailure(error.localizedDescription))
            }
        }
    }
}
