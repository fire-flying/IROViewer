import Foundation

/// 车机上的一个媒体文件
struct MediaItem: Identifiable, Hashable {
    /// 相对路径，例如 /EMMC/Normal/F/20261104131514.ts
    let name: String
    let size: Int64
    let timeText: String

    var id: String { name }

    var fileName: String {
        (name as NSString).lastPathComponent
    }

    var url: URL {
        URL(string: CameraClient.baseURL + name)!
    }

    /// 文件名即 yyyyMMddHHmmss，字符串排序等价于时间排序
    var sortKey: String {
        String(fileName.prefix(14))
    }

    var displayTime: String {
        guard !timeText.isEmpty else { return fileName }
        return timeText
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var isVideo: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ["ts", "mp4", "mov"].contains(ext)
    }
}

/// 一次驾驶形成的连续录像，由若干相邻片段组成
struct Trip: Identifiable, Hashable {
    let id: String
    let items: [MediaItem]

    var first: MediaItem { items[0] }

    var startTime: String { items.first?.displayTime ?? "" }
    var endTime: String { items.last?.displayTime ?? "" }

    /// 2026-11-05
    var dateText: String { String(startTime.prefix(10)) }

    /// 19:21:03 – 19:23:03
    var timeRange: String {
        "\(String(startTime.suffix(8))) – \(String(endTime.suffix(8)))"
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// 按时间间隔把片段切成“行程”：相邻两段间隔超过 120 秒就认为是另一次驾驶
enum TripBuilder {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static func build(from items: [MediaItem]) -> [Trip] {
        let videos = items
            .filter { $0.isVideo }
            .sorted { $0.sortKey < $1.sortKey }

        guard !videos.isEmpty else { return [] }

        var groups: [[MediaItem]] = []
        var current: [MediaItem] = []

        for item in videos {
            if let last = current.last,
               let lastDate = formatter.date(from: last.sortKey),
               let date = formatter.date(from: item.sortKey),
               date.timeIntervalSince(lastDate) > 120 {
                groups.append(current)
                current = []
            }
            current.append(item)
        }

        if !current.isEmpty {
            groups.append(current)
        }

        let trips = groups.map { Trip(id: $0[0].sortKey, items: $0) }
        return Array(trips.reversed())
    }
}
