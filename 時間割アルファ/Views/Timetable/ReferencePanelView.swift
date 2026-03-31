import SwiftUI
import PhotosUI

// MARK: - ReferencePanelView

struct ReferencePanelView: View {
    @Bindable var viewModel: TimetableViewModel

    enum Tab: String, CaseIterable {
        case pdf    = "PDF"
        case web    = "Web"
        case image  = "画像"

        var icon: String {
            switch self {
            case .pdf:   return "doc.fill"
            case .web:   return "globe"
            case .image: return "photo"
            }
        }
    }

    @State private var selectedTab: Tab = .pdf
    @State private var webURLString: String = "https://www.google.com"
    @State private var webURL: URL? = URL(string: "https://www.google.com")
    @State private var isWebLoading: Bool = false
    @State private var webTitle: String = ""
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var loadedImage: UIImage?
    @State private var pdfURL: URL?
    @State private var showFilePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ハンドルバー
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 4)
                .padding(.vertical, 6)

            // タブ切替
            Picker("参照コンテンツ", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)

            Divider()

            // コンテンツ
            switch selectedTab {
            case .pdf:
                pdfTabView
            case .web:
                webTabView
            case .image:
                imageTabView
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - PDF Tab

    private var pdfTabView: some View {
        VStack {
            if let url = pdfURL {
                PDFViewerRepresentable(url: url)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("PDFを選択")
                        .foregroundStyle(.secondary)
                    Button("ファイルを選択") {
                        showFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf]
        ) { result in
            if case .success(let url) = result {
                pdfURL = url
            }
        }
    }

    // MARK: - Web Tab

    private var webTabView: some View {
        VStack(spacing: 0) {
            // URLバー
            HStack {
                TextField("URLを入力", text: $webURLString)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { loadWebURL() }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    loadWebURL()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            if isWebLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let url = webURL {
                WebViewRepresentable(url: url, isLoading: $isWebLoading, title: $webTitle)
            }
        }
    }

    // MARK: - Image Tab

    private var imageTabView: some View {
        VStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("画像を選択")
                        .foregroundStyle(.secondary)
                    PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 1, matching: .images) {
                        Text("画像を選択")
                    }
                    .buttonStyle(.bordered)
                    .onChange(of: photosPickerItems) { _, items in
                        items.first?.loadTransferable(type: Data.self) { result in
                            if case .success(let data) = result, let data, let img = UIImage(data: data) {
                                DispatchQueue.main.async { loadedImage = img }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadWebURL() {
        var urlString = webURLString
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        webURL = URL(string: urlString)
    }
}
