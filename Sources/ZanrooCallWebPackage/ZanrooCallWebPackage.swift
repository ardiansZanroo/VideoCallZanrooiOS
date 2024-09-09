import Foundation
import SwiftUI
import WebKit

@available(iOS 13.0, *)
public struct zanrooCallWeb: UIViewRepresentable {
    var id: String
    var environment: Environment
    var onCallStop: (CallResult) -> Void // Closure to execute when the call stops with a message

    // JavaScript to inject into the web view
    private let stopScript = """
    if (window.WebViewApp) {
        // Listener already set up
    } else {
        window.WebViewApp = {};
        window.WebViewApp.stopLoading = function(message) {
            window.webkit.messageHandlers.callStopped.postMessage(message);
        };
    }
    """

    // Enum to represent different environments
    public enum Environment {
        case dev
        case staging
        case production

        var baseUrl: String {
            switch self {
            case .dev:
                return "https://rfe.kyc-zanroodesk.my.id/client?id="
            case .staging:
                return "https://ekyc-fe.videocall.stg.super-id.net/client?id="
            case .production:
                return "https://ekyc-fe.videocall.stg.super-id.net/client?id="
            }
        }
    }

    public init(id: String, environment: Environment, onCallStop: @escaping (CallResult) -> Void) {
        self.id = id
        self.environment = environment
        self.onCallStop = onCallStop
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: zanrooCallWeb

        init(_ parent: zanrooCallWeb) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "callStopped" {
                if let messageBody = message.body as? String, let callResult = CallResult(rawValue: messageBody) {
                    DispatchQueue.main.async {
                        self.parent.onCallStop(callResult) // Call the closure with the message from the web view
                    }
                }
            }
        }
    }

    public func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController.addUserScript(WKUserScript(source: stopScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        webViewConfiguration.allowsInlineMediaPlayback = true
        webViewConfiguration.userContentController.add(context.coordinator, name: "callStopped")

        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let urlString = environment.baseUrl + id // Use the selected environment's base URL
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }

        // Update constraints to make the web view follow the parent size
        DispatchQueue.main.async {
            if let superview = uiView.superview {
                NSLayoutConstraint.activate([
                    uiView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    uiView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    uiView.topAnchor.constraint(equalTo: superview.topAnchor),
                    uiView.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                ])
            }
        }
    }
}

public enum CallResult: String {
    case disconnected
    case success
    case error
    case canceled
}
