import SwiftUI
import UIKit
import WebKit

struct LocalStaticImageView: View {
    let url: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.white.opacity(0.5))
                }
        }
    }
}

struct AnimatedMediaPreview: View {
    let payload: MediaSendPayload

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))

            switch payload.item.kind {
            case .gif:
                GIFWebView(url: payload.fileURL)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            case .image:
                LocalStaticImageView(url: payload.fileURL)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

private struct GIFWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <html>
        <head>
          <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
          <style>
            html, body {
              margin: 0;
              width: 100%;
              height: 100%;
              background: transparent;
            }
            body {
              display: flex;
              align-items: center;
              justify-content: center;
            }
            img {
              width: 100%;
              height: 100%;
              object-fit: contain;
            }
          </style>
        </head>
        <body>
          <img src="\(url.lastPathComponent)" />
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}
