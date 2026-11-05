import Foundation
import Network

/// 极简本地 HTTP 服务，只为 AVPlayer 提供可访问的 m3u8 索引。
/// 分片地址仍直接指向车机，不代理视频数据，避免占用带宽和内存。
final class LocalPlaylistServer {
    private let queue = DispatchQueue(label: "iro.playlist.server")
    private let lock = NSLock()
    private var listener: NWListener?
    private var body = ""
    private(set) var port: UInt16 = 0

    func start() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(using: parameters, on: .any)
            let ready = DispatchSemaphore(value: 0)

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    ready.signal()
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.start(queue: queue)
            self.listener = listener

            _ = ready.wait(timeout: .now() + 2)
            port = listener.port?.rawValue ?? 0
        } catch {
            port = 0
        }
    }

    func update(_ playlist: String) {
        lock.lock()
        body = playlist
        lock.unlock()
    }

    func playlistURL(version: Int) -> URL? {
        guard port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(port)/playlist.m3u8?v=\(version)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = 0
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let wantsPlaylist = request.contains("/playlist.m3u8")
            let isHead = request.hasPrefix("HEAD")

            self.lock.lock()
            let playlist = self.body
            self.lock.unlock()

            let response: String
            if wantsPlaylist {
                response = "HTTP/1.1 200 OK\r\n"
                    + "Content-Type: application/vnd.apple.mpegurl\r\n"
                    + "Content-Length: \(playlist.utf8.count)\r\n"
                    + "Cache-Control: no-store\r\n"
                    + "Connection: close\r\n\r\n"
                    + (isHead ? "" : playlist)
            } else {
                response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            }

            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

/// 把若干 ts 片段拼成 HLS 索引。每段是独立录像，时间戳会重置，所以要标 DISCONTINUITY。
enum PlaylistBuilder {
    static func build(items: [MediaItem], from index: Int) -> String {
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:3",
            "#EXT-X-TARGETDURATION:60",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD"
        ]

        for (offset, item) in items[index...].enumerated() {
            if offset > 0 {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            lines.append("#EXTINF:60.0,")
            lines.append(item.url.absoluteString)
        }

        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n")
    }
}
