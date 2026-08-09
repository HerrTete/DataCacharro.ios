import SwiftUI
import WebKit

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct WebPreviewView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var pageTitle: String = ""
    @State private var showingEdit = false

    private var url: URL { item.url! }

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(url: url, isLoading: $isLoading, pageTitle: $pageTitle)
                    .ignoresSafeArea(edges: .bottom)
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(pageTitle.isEmpty ? url.host() ?? "" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("webPreviewCloseButton")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingEdit = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityIdentifier("webPreviewEditButton")

                    Button {
                        SharePresenter.present(items: [url])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("webPreviewShareButton")

                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityIdentifier("webPreviewSafariButton")
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditItemView(item: item)
                    .environmentObject(storage)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, pageTitle: $pageTitle)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String

        init(isLoading: Binding<Bool>, pageTitle: Binding<String>) {
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            pageTitle = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
