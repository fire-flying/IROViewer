import AVFoundation
import Combine
import MobileVLCKit

/// 用 VLCKit 播放。AVFoundation 不认车机的裸 TS 封装，VLC 原生支持，
/// 且能在同一播放器里顺序连播多段。
final class PlayerEngine: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var errorText: String?

    let mediaPlayer = VLCMediaPlayer()

    private var items: [MediaItem] = []
    private var currentIndex = 0

    override init() {
        super.init()
        mediaPlayer.delegate = self
    }

    func attach(drawable view: UIView) {
        mediaPlayer.drawable = view
    }

    func start(items: [MediaItem], selected: MediaItem) {
        configureAudioSession()

        let videos = items.filter { $0.isVideo }
        self.items = videos
        totalSegments = videos.count
        currentIndex = videos.firstIndex(of: selected) ?? 0
        playCurrent()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private func playCurrent() {
        guard currentIndex >= 0, currentIndex < items.count else { return }

        let media = VLCMedia(url: items[currentIndex].url)
        media.addOptions([
            "network-caching": 1500,
            "clock-jitter": 0,
            "clock-synchro": 0
        ])

        mediaPlayer.media = media
        mediaPlayer.play()

        currentSegment = currentIndex + 1
        isPlaying = true
        errorText = nil
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        let state = mediaPlayer.state

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch state {
            case .playing:
                self.isPlaying = true

            case .paused, .stopped:
                self.isPlaying = false

            case .ended:
                self.advance()

            case .error:
                if self.currentIndex + 1 < self.items.count {
                    self.errorText = "第 \(self.currentIndex + 1) 段无法播放，已跳到下一段"
                    self.currentIndex += 1
                    self.playCurrent()
                } else if self.items.isEmpty == false {
                    self.errorText = "最后一段无法播放，可能已被车机覆盖"
                    self.isPlaying = false
                }

            default:
                break
            }
        }
    }

    private func advance() {
        if currentIndex + 1 < items.count {
            currentIndex += 1
            playCurrent()
        } else {
            isPlaying = false
        }
    }

    func toggle() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            isPlaying = false
        } else {
            mediaPlayer.play()
            isPlaying = true
        }
    }

    func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        playCurrent()
    }

    func next() {
        guard currentIndex + 1 < items.count else { return }
        currentIndex += 1
        playCurrent()
    }

    func stop() {
        mediaPlayer.stop()
        mediaPlayer.drawable = nil
    }
}
