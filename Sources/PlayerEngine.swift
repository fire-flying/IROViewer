import AVFoundation
import Combine

/// 用 AVQueuePlayer 把多段 ts 依次排队，实现连续播放。
/// 直接给每段一个 http .ts 地址，AVFoundation 原生支持 MPEG-TS，不经过 m3u8。
@MainActor
final class PlayerEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var errorText: String?

    let player = AVQueuePlayer()

    private var items: [MediaItem] = []
    private var currentObservation: NSKeyValueObservation?
    private var statusObservations: [NSKeyValueObservation] = []

    nonisolated init() {}

    func start(items: [MediaItem], at index: Int) {
        self.items = items
        totalSegments = items.count
        load(from: index)
    }

    /// 从指定片段重建队列，后续片段自动接上，直到最后一段播完
    func load(from index: Int) {
        guard !items.isEmpty else {
            errorText = "没有可播放的文件"
            return
        }

        let safeIndex = max(0, min(index, items.count - 1))

        player.pause()
        player.removeAllItems()
        statusObservations.forEach { $0.invalidate() }
        statusObservations.removeAll()

        for i in safeIndex..<items.count {
            let playerItem = AVPlayerItem(url: items[i].url)
            observe(playerItem)
            player.insert(playerItem, after: nil)
        }

        installCurrentItemObserver()

        player.play()
        isPlaying = true
        errorText = nil
        currentSegment = safeIndex + 1
    }

    private func observe(_ playerItem: AVPlayerItem) {
        let observation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription
            Task { @MainActor in
                self?.errorText = message ?? "这一段播放失败，可能已被车机覆盖"
            }
        }
        statusObservations.append(observation)
    }

    private func installCurrentItemObserver() {
        currentObservation?.invalidate()
        currentObservation = player.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let current = player.currentItem else {
                    self.isPlaying = false
                    return
                }
                if let url = (current.asset as? AVURLAsset)?.url,
                   let index = self.items.firstIndex(where: { $0.url == url }) {
                    self.currentSegment = index + 1
                }
            }
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
        player.removeAllItems()
        currentObservation?.invalidate()
        currentObservation = nil
        statusObservations.forEach { $0.invalidate() }
        statusObservations.removeAll()
    }
}
