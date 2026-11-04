import Foundation

/// 把多段 ts 组织成一个 HLS 播放列表。
/// AVPlayer 不直接支持裸 MPEG-TS 文件，但支持 HLS，所以用本地 m3u8 串起远程片段。
enum HLSPlaylist {
    static func write(items: [MediaItem], startIndex: Int) throws -> URL {
        guard !items.isEmpty else { throw PlaylistError.empty }

        let start = max(0, min(startIndex, items.count - 1))
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:3",
            "#EXT-X-TARGETDURATION:60",
            "#EXT-X-PLAYLIST-TYPE:VOD"
        ]

        for item in items[start...] {
            lines.append("#EXTINF:60.0,")
            lines.append(item.url.absoluteString)
        }
        lines.append("#EXT-X-ENDLIST")

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = directory.appendingPathComponent("iro-playlist.m3u8")
        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    enum PlaylistError: LocalizedError {
        case empty

        var errorDescription: String? {
            "没有可播放的文件"
        }
    }
}
