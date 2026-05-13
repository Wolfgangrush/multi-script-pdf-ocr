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

            // CRITICAL: pin to English. Vision supports en/fr/it/de/es/pt-BR/zh/yue/ko/
            // ja/ru/uk/th/vi/ar but NOT any Indic script. With auto-detection on, any
            // Devanagari/Tamil/etc. on the page is fitted to the closest visually-similar
            // supported script — typically Thai (matra strokes look alike) — producing
            // garbage like "สาย / ดิ / อะ" instead of returning nothing. Pinning to en-US
            // means non-Latin glyphs are skipped cleanly, and English text is recognised
            // without the language ambiguity that contaminates mixed-script pages.
            //
            // For documents with actual Devanagari, the user should pick a Tesseract
            // language from the picker. "मराठी + English (mixed)" (mar+eng) handles
            // mixed Devanagari/Latin pages.
            req.recognitionLanguages = ["en-US"]
            req.automaticallyDetectsLanguage = false

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])
            } catch {
                cont.resume(throwing: OCRError.engineFailure(error.localizedDescription))
            }
        }
    }
}
