import AVFoundation
import SwiftUI

struct PlaybackView: View {
    let items: [MediaItem]
    let selected: MediaItem

    @StateObject private var engine = PlayerEngine()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerLayerView(player: engine.player).ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Text("\(engine.currentSegment)/\(engine.totalSegments)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()

                Spacer()

                if let errorText = engine.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                } else {
                    HStack(spacing: 44) {
                        Button {
                            engine.previous()
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.title2)
                                .opacity(engine.currentSegment > 1 ? 1 : 0.3)
                        }

                        Button {
                            engine.toggle()
                        } label: {
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                        }

                        Button {
                            engine.next()
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.title2)
                                .opacity(engine.currentSegment < engine.totalSegments ? 1 : 0.3)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 44)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            engine.start(items: items, selected: selected)
        }
        .onDisappear {
            engine.stop()
        }
    }
}

/// 照片不是视频，单独显示，不走播放器
struct PhotoPreviewView: View {
    let item: MediaItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: item.url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .statusBarHidden()
    }
}

private final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}
