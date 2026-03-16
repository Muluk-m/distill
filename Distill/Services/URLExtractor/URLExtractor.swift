import Foundation
import AVFoundation

@MainActor
final class URLExtractor: ObservableObject {
    @Published var isExtracting = false
    @Published var statusMessage = ""

    /// Download audio from a URL and return a local file URL
    func extractAudio(from urlString: String) async throws -> (localURL: URL, title: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ExtractorError.invalidURL
        }

        isExtracting = true
        defer { isExtracting = false }

        let platform = detectPlatform(url)
        statusMessage = "正在解析 \(platform.displayName) 链接..."

        switch platform {
        case .directMedia:
            return try await downloadDirect(url: url)
        case .bilibili:
            return try await extractBilibili(url: url)
        case .youtube:
            return try await extractYouTube(url: url)
        case .xiaoyuzhou:
            return try await extractXiaoyuzhou(url: url)
        case .generic:
            return try await extractGeneric(url: url)
        }
    }

    // MARK: - Platform Detection

    enum Platform {
        case bilibili, youtube, xiaoyuzhou, directMedia, generic

        var displayName: String {
            switch self {
            case .bilibili: return "B站"
            case .youtube: return "YouTube"
            case .xiaoyuzhou: return "小宇宙"
            case .directMedia: return "媒体文件"
            case .generic: return "网页"
            }
        }
    }

    private func detectPlatform(_ url: URL) -> Platform {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host.contains("bilibili.com") || host.contains("b23.tv") {
            return .bilibili
        } else if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youtube
        } else if host.contains("xiaoyuzhoufm.com") {
            return .xiaoyuzhou
        } else if ["mp3", "m4a", "wav", "mp4", "mov", "aac", "ogg", "flac"].contains(url.pathExtension.lowercased()) {
            return .directMedia
        }
        return .generic
    }

    // MARK: - Direct Media Download

    private func downloadDirect(url: URL) async throws -> (URL, String) {
        statusMessage = "正在下载音频..."
        let localURL = try await downloadFile(from: url)
        let title = url.lastPathComponent
        return (localURL, title)
    }

    // MARK: - Bilibili

    private func extractBilibili(url: URL) async throws -> (URL, String) {
        statusMessage = "正在解析 B站视频..."

        // Resolve short links (b23.tv)
        let resolvedURL = try await resolveRedirects(url)

        // Extract BV id
        guard let bvid = extractBVID(from: resolvedURL) else {
            throw ExtractorError.parseError("无法解析 B站视频 ID")
        }

        // Get video info via API
        let infoURL = URL(string: "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)")!
        let (infoData, _) = try await URLSession.shared.data(from: infoURL)
        let infoJSON = try JSONSerialization.jsonObject(with: infoData) as? [String: Any]
        let data = infoJSON?["data"] as? [String: Any]
        let title = data?["title"] as? String ?? "B站视频"
        let cid = data?["cid"] as? Int ?? 0

        // Get playback URL
        let playURL = URL(string: "https://api.bilibili.com/x/player/playurl?bvid=\(bvid)&cid=\(cid)&fnval=16")!
        let (playData, _) = try await URLSession.shared.data(from: playURL)
        let playJSON = try JSONSerialization.jsonObject(with: playData) as? [String: Any]
        let playDataObj = playJSON?["data"] as? [String: Any]
        let dash = playDataObj?["dash"] as? [String: Any]
        let audioList = dash?["audio"] as? [[String: Any]]

        guard let audioURL = audioList?.first?["baseUrl"] as? String,
              let audioFileURL = URL(string: audioURL) else {
            throw ExtractorError.parseError("无法获取 B站音频流")
        }

        statusMessage = "正在下载音频..."
        var request = URLRequest(url: audioFileURL)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (localURL, _) = try await URLSession.shared.download(for: request)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try FileManager.default.moveItem(at: localURL, to: dest)

        return (dest, title)
    }

    private func extractBVID(from url: URL) -> String? {
        let path = url.path
        if let range = path.range(of: "BV[a-zA-Z0-9]+", options: .regularExpression) {
            return String(path[range])
        }
        return nil
    }

    // MARK: - YouTube (via Invidious)

    private func extractYouTube(url: URL) async throws -> (URL, String) {
        statusMessage = "正在解析 YouTube 视频..."

        guard let videoID = extractYouTubeID(from: url) else {
            throw ExtractorError.parseError("无法解析 YouTube 视频 ID")
        }

        // Use Invidious public API
        let instances = [
            "https://inv.nadeko.net",
            "https://invidious.fdn.fr",
            "https://vid.puffyan.us"
        ]

        for instance in instances {
            guard let apiURL = URL(string: "\(instance)/api/v1/videos/\(videoID)") else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: apiURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let title = json?["title"] as? String ?? "YouTube 视频"
                let adaptiveFormats = json?["adaptiveFormats"] as? [[String: Any]] ?? []

                // Find audio-only format
                let audioFormat = adaptiveFormats.first { format in
                    let mimeType = format["type"] as? String ?? ""
                    return mimeType.starts(with: "audio/")
                }

                guard let audioURLString = audioFormat?["url"] as? String,
                      let audioURL = URL(string: audioURLString) else {
                    continue
                }

                statusMessage = "正在下载音频..."
                let localURL = try await downloadFile(from: audioURL)
                return (localURL, title)
            } catch {
                continue
            }
        }

        throw ExtractorError.parseError("YouTube 解析失败，请检查链接或网络")
    }

    private func extractYouTubeID(from url: URL) -> String? {
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.last
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value
    }

    // MARK: - 小宇宙 Podcast

    private func extractXiaoyuzhou(url: URL) async throws -> (URL, String) {
        statusMessage = "正在解析小宇宙播客..."

        // Extract episode ID from URL like xiaoyuzhoufm.com/episode/xxx
        let pathComponents = url.pathComponents
        guard let episodeIndex = pathComponents.firstIndex(of: "episode"),
              episodeIndex + 1 < pathComponents.count else {
            throw ExtractorError.parseError("无法解析小宇宙链接")
        }
        let episodeID = pathComponents[episodeIndex + 1]

        // Fetch episode page to extract audio URL from meta tags
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        // Extract audio URL from og:audio meta tag
        guard let audioURL = extractMetaContent(html: html, property: "og:audio"),
              let audioFileURL = URL(string: audioURL) else {
            throw ExtractorError.parseError("无法获取小宇宙音频地址")
        }

        let title = extractMetaContent(html: html, property: "og:title") ?? "小宇宙播客 \(episodeID)"

        statusMessage = "正在下载音频..."
        let localURL = try await downloadFile(from: audioFileURL)
        return (localURL, title)
    }

    // MARK: - Generic (try to find audio/video in page)

    private func extractGeneric(url: URL) async throws -> (URL, String) {
        statusMessage = "正在尝试解析页面..."

        // First try treating the URL as direct media
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: request)

        if let mimeType = (response as? HTTPURLResponse)?.mimeType,
           mimeType.starts(with: "audio/") || mimeType.starts(with: "video/") {
            let localURL = try await downloadFile(from: url)
            return (localURL, url.lastPathComponent)
        }

        // Try fetching the page and looking for og:audio / og:video meta
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        let title = extractMetaContent(html: html, property: "og:title") ?? url.host ?? "未知来源"

        // Look for audio in meta tags
        if let audioURL = extractMetaContent(html: html, property: "og:audio"),
           let audioFileURL = URL(string: audioURL) {
            statusMessage = "正在下载音频..."
            let localURL = try await downloadFile(from: audioFileURL)
            return (localURL, title)
        }

        // Look for video in meta tags
        if let videoURL = extractMetaContent(html: html, property: "og:video"),
           let videoFileURL = URL(string: videoURL) {
            statusMessage = "正在下载视频..."
            let localURL = try await downloadFile(from: videoFileURL)
            return (localURL, title)
        }

        throw ExtractorError.parseError("无法从该链接提取音视频内容")
    }

    // MARK: - Helpers

    private func downloadFile(from url: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private func resolveRedirects(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)
        return response.url ?? url
    }

    private func extractMetaContent(html: String, property: String) -> String? {
        // Match <meta property="og:xxx" content="..."> or <meta name="og:xxx" content="...">
        let pattern = "<meta[^>]*(?:property|name)=[\"']\(property)[\"'][^>]*content=[\"']([^\"']+)[\"']"
        let altPattern = "<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*(?:property|name)=[\"']\(property)[\"']"

        for p in [pattern, altPattern] {
            if let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    // MARK: - Errors

    enum ExtractorError: LocalizedError {
        case invalidURL
        case parseError(String)
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的链接"
            case .parseError(let msg): return msg
            case .downloadFailed: return "下载失败"
            }
        }
    }
}
