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
}
