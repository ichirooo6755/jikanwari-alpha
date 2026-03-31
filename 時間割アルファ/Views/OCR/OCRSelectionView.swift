import SwiftUI

// MARK: - OCRSelectionView
// ユーザーが画像上で矩形を描いて選択した領域をOCRにかける

struct OCRSelectionView: View {
    let image: UIImage
    var ocrVM: OCRViewModel
    var onRecognized: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var imageFrame: CGRect = .zero

    private var selectionRect: CGRect {
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("テキストを認識したい範囲をドラッグして選択してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()

                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                            .background(
                                GeometryReader { imgGeo in
                                    Color.clear.onAppear {
                                        imageFrame = imgGeo.frame(in: .local)
                                    }
                                }
                            )

                        // 選択矩形オーバーレイ
                        if isDragging || selectionRect.width > 10 {
                            Rectangle()
                                .stroke(Color.blue, lineWidth: 2)
                                .background(Color.blue.opacity(0.15))
                                .frame(width: selectionRect.width, height: selectionRect.height)
                                .position(x: selectionRect.midX, y: selectionRect.midY)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if !isDragging {
                                    startPoint = value.startLocation
                                    isDragging = true
                                }
                                currentPoint = value.location
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }

                // OCR実行ボタン
                HStack(spacing: 12) {
                    Button("全体を認識") {
                        runOCR(rect: .zero)
                    }
                    .buttonStyle(.bordered)

                    Button("選択範囲を認識") {
                        let normalizedRect = normalizeRect(selectionRect, in: imageFrame)
                        runOCR(rect: normalizedRect)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectionRect.width < 10 || selectionRect.height < 10)
                }
                .padding()
            }
            .navigationTitle("範囲を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func normalizeRect(_ rect: CGRect, in frame: CGRect) -> CGRect {
        guard frame.width > 0, frame.height > 0 else { return .zero }
        let x = (rect.origin.x - frame.origin.x) / frame.width
        let y = (rect.origin.y - frame.origin.y) / frame.height
        let w = rect.width / frame.width
        let h = rect.height / frame.height
        return CGRect(x: max(0, x), y: max(0, y), width: min(1, w), height: min(1, h))
    }

    private func runOCR(rect: CGRect) {
        Task { @MainActor in
            await ocrVM.recognizeText(in: image, rect: rect)
            onRecognized(ocrVM.recognizedText)
            dismiss()
        }
    }
}
