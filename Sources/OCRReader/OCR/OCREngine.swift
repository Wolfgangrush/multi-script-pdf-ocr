import Foundation
import CoreGraphics

public struct RecognizedText: Sendable {
    public var rect: CGRect
    public var text: String
    public init(rect: CGRect, text: String) {
        self.rect = rect; self.text = text
    }
}

public enum OCRError: Error, LocalizedError {
    case engineFailure(String)
    case cancelled
    case toolMissing(String)
    public var errorDescription: String? {
        switch self {
        case .engineFailure(let s): return "OCR engine: \(s)"
        case .cancelled: return "Cancelled."
        case .toolMissing(let s): return "Required tool missing: \(s)"
        }
    }
}

public protocol OCREngine: Sendable {
    func recognize(cgImage: CGImage) async throws -> [RecognizedText]
}

/// Languages the user can pick. Order matters — this is the picker order.
/// `engine` decides which OCREngine handles the language.
public enum OCRLanguage: String, CaseIterable, Identifiable, Sendable {
    case english          // Apple Vision (fast, on-device, native)
    case hindi            // Tesseract: hin
    case marathi          // Tesseract: mar
    case tamil            // Tesseract: tam
    case telugu           // Tesseract: tel
    case kannada          // Tesseract: kan
    case malayalam        // Tesseract: mal
    case gujarati         // Tesseract: guj
    case punjabi          // Tesseract: pan
    case bengali          // Tesseract: ben
    case oriya            // Tesseract: ori
    case urdu             // Tesseract: urd
    case sanskrit         // Tesseract: san
    case hindiPlusEnglish // Tesseract: hin+eng (mixed-script docs)
    case marathiPlusEnglish // Tesseract: mar+eng

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english:           return "English (Apple Vision · fast)"
        case .hindi:             return "हिन्दी / Hindi"
        case .marathi:           return "मराठी / Marathi"
        case .tamil:             return "தமிழ் / Tamil"
        case .telugu:            return "తెలుగు / Telugu"
        case .kannada:           return "ಕನ್ನಡ / Kannada"
        case .malayalam:         return "മലയാളം / Malayalam"
        case .gujarati:          return "ગુજરાતી / Gujarati"
        case .punjabi:           return "ਪੰਜਾਬੀ / Punjabi"
        case .bengali:           return "বাংলা / Bengali"
        case .oriya:             return "ଓଡ଼ିଆ / Oriya"
        case .urdu:              return "اردو / Urdu"
        case .sanskrit:          return "संस्कृतम् / Sanskrit"
        case .hindiPlusEnglish:  return "हिन्दी + English (mixed)"
        case .marathiPlusEnglish: return "मराठी + English (mixed)"
        }
    }

    /// Tesseract `-l` argument. nil for engines that don't need it.
    public var tesseractCode: String? {
        switch self {
        case .english:           return nil
        case .hindi:             return "hin"
        case .marathi:           return "mar"
        case .tamil:             return "tam"
        case .telugu:            return "tel"
        case .kannada:           return "kan"
        case .malayalam:         return "mal"
        case .gujarati:          return "guj"
        case .punjabi:           return "pan"
        case .bengali:           return "ben"
        case .oriya:             return "ori"
        case .urdu:              return "urd"
        case .sanskrit:          return "san"
        case .hindiPlusEnglish:  return "hin+eng"
        case .marathiPlusEnglish: return "mar+eng"
        }
    }

    public var usesVision: Bool { self == .english }
}
