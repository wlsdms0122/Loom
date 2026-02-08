import Foundation
import WebKit

@MainActor
public final class BundleSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    // MARK: - Property

    private let bundle: Bundle
    private var activeTasks: Set<ObjectIdentifier> = []

    // MARK: - Initializer

    public init(bundle: Bundle) {
        self.bundle = bundle
        super.init()
    }

    // MARK: - Public

    public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(taskID)

        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            activeTasks.remove(taskID)
            return
        }

        // Extract path from loom://app/{path}
        guard url.scheme == "loom", url.host == "app" else {
            urlSchemeTask.didFailWithError(URLError(.unsupportedURL))
            activeTasks.remove(taskID)
            return
        }

        let path = String(url.path.dropFirst()) // Remove leading "/"

        do {
            let (data, mimeType) = try loadBundleResource(path: path)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": "\(data.count)",
                    "Access-Control-Allow-Origin": "*"
                ]
            )!

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }

        activeTasks.remove(taskID)
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks.remove(taskID)
    }

    // MARK: - Private

    private func loadBundleResource(path: String) throws -> (Data, String) {
        let bundleURL = bundle.bundleURL
        let fileURL = bundleURL.appendingPathComponent(path)
        let resolvedURL = fileURL.standardizedFileURL
        let resolvedBundleURL = bundleURL.standardizedFileURL

        // Path traversal protection
        guard resolvedURL.path.hasPrefix(resolvedBundleURL.path) else {
            throw URLError(.fileDoesNotExist)
        }

        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            throw URLError(.fileDoesNotExist)
        }

        let data = try Data(contentsOf: resolvedURL)
        let mimeType = mimeType(for: resolvedURL.pathExtension)

        return (data, mimeType)
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html", "htm":
            return "text/html"
        case "js", "mjs":
            return "text/javascript"
        case "css":
            return "text/css"
        case "json":
            return "application/json"
        case "svg":
            return "image/svg+xml"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        case "ico":
            return "image/x-icon"
        case "map":
            return "application/json"
        default:
            return "application/octet-stream"
        }
    }
}
