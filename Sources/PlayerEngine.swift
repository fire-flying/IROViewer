import AVFoundation
import Combine

@MainActor
final class PlayerEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var errorText: String?

    let player = AVPlayer()

    private var items: [MediaItem] = []
    private var statusObservation: NSKeyValueObservation?

    nonisolated init() {}

    func start(items: [MediaItem], at index: Int) {
        self.items = items
        totalSegments = items.count
        load(from: index)
    }

    /// 从指定片段开始重新生成播放列表，实现“从这一段往下连播”
    func load(from index: Int) {
        guard !items.isEmpty else {
            errorText = "没有可播放的文件"
            return
        }

        let safeIndex = max(0, min(index, items.count - 1))

        do {
            let playlistURL = try HLSPlaylist.write(items: items, startIndex: safeIndex)
            let item = AVPlayerItem(url: playlistURL)

            statusObservation?.invalidate()
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let status = item.status
                let message = item.error?.localizedDescription
                Task { @MainActor in
                    guard let self else { return }
                    if status == .failed {
                        self.errorText = message ?? "播放失败，请确认仍连接着车机 WiFi"
                    }
                }
            }

            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            errorText = nil
            currentSegment = safeIndex + 1
        } catch {
            errorText = error.localizedDescription
        }
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
    }
}
