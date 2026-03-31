import Foundation
import SwiftUI
import Vision

// MARK: - OCR Result

struct OCRResult {
    var recognizedText: String
    var confidence: Float
}

// MARK: - OCRViewModel

@MainActor
@Observable
final class OCRViewModel {

    var selectedImage: UIImage?
    var recognizedText: String = ""
    var isProcessing: Bool = false
    var selectionRect: CGRect = .zero
    var errorMessage: String?

    // MARK: - OCR

    func recognizeText(in image: UIImage, rect: CGRect) async {
        isProcessing = true
        errorMessage = nil

        guard let cgImage = image.cgImage else {
            errorMessage = "画像の読み込みに失敗しました"
            isProcessing = false
            return
        }

        // rect は image座標系の正規化された矩形
        let croppedCGImage: CGImage
        if rect != .zero {
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let cropRect = CGRect(
                x: rect.origin.x * imageSize.width,
                y: rect.origin.y * imageSize.height,
                width: rect.size.width * imageSize.width,
                height: rect.size.height * imageSize.height
            )
            croppedCGImage = cgImage.cropping(to: cropRect) ?? cgImage
        } else {
            croppedCGImage = cgImage
        }

        let text = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(returning: "エラー: \(error.localizedDescription)")
                    return
                }
                let results = request.results as? [VNRecognizedTextObservation] ?? []
                let text = results.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLanguages = ["ja", "en"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: croppedCGImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "エラー: \(error.localizedDescription)")
            }
        }

        recognizedText = text
        isProcessing = false
    }

    func reset() {
        selectedImage = nil
        recognizedText = ""
        selectionRect = .zero
        errorMessage = nil
    }
}
