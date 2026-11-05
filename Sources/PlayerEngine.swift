import AVFoundation
import Combine

/// AVFoundation 不支持直接播放裸 ts 文件，只认 HLS。
/// 所以用本地 HTTP 服务提供 m3u8 索引，分片仍直连车机。
@MainActor
final class PlayerEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var errorText: String?

    let player = AVPlayer()

    private let server = LocalPlaylistServer()
    private var items: [MediaItem] = []
    private var statusObservation: NSKeyValueObservation?
    private var version = 0

    nonisolated init() {}

    func start(items: [MediaItem], selected: MediaItem) {
        let videos = items.filter { $0.isVideo }
        self.items = videos
        totalSegments = videos.count
        server.start()

        let index = videos.firstIndex(of: selected) ?? 0
        load(from: index)
    }

    /// 从指定片段重建索引，AVPlayer 会依次播完后面的所有段
    func load(from index: Int) {
        guard !items.isEmpty else {
            errorText = "没有可播放的视频"
            return
        }

        guard server.port > 0 else {
            errorText = "本地播放服务启动失败"
            return
        }

        let safeIndex = max(0, min(index, items.count - 1))
        version += 1
        server.update(PlaylistBuilder.build(items: items, from: safeIndex))

        guard let playlistURL = server.playlistURL(version: version) else {
            errorText = "无法生成播放地址"
            return
        }

        let item = AVPlayerItem(url: playlistURL)

        statusObservation?.invalidate()
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription
            Task { @MainActor in
                self?.errorText = message ?? "播放失败，可能已被车机覆盖"
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        errorText = nil
        currentSegment = safeIndex + 1
    }

    func toggle() {
        if player.rate > 0 {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func previous() {
        guard currentSegment > 1 else { return }
        load(from: currentSegment - 2)
    }

    func next() {
        guard currentSegment < totalSegments else { return }
        load(from: currentSegment)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation?.invalidate()
        statusObservation = nil
        server.stop()
    }
}
