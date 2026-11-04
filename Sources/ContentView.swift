import SwiftUI

struct ContentView: View {
    @State private var category: CameraClient.Category = .normal
    @State private var items: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var playIndex: Int = 0
    @State private var showPlayer = false

    private let client = CameraClient()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("类型", selection: $category) {
                        ForEach(CameraClient.Category.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("请确认手机已连接记录仪的 WiFi 热点。连上后，用本机浏览器打开 http://192.168.1.1 应能访问。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在读取车机文件列表…")
                        }
                    } else if items.isEmpty {
                        Text("没有找到文件")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            Button {
                                playIndex = index
                                showPlayer = true
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(items.isEmpty ? "文件" : "共 \(items.count) 段 · 点任意一段开始连播")
                }
            }
            .navigationTitle("IRO 记录仪")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: category) { _ in
                Task { await load() }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlaybackView(items: items, startIndex: playIndex)
            }
        }
    }

    private func row(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.name.lowercased().hasSuffix(".ts") ? "video.fill" : "photo.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTime)
                    .font(.body.monospacedDigit())
                Text(item.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.sizeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let result = try await client.fetchList(category: category)
            items = result.items
            if items.isEmpty && result.amount > 0 {
                errorText = "车机报告 \(result.amount) 个文件，但没有解析出列表"
            }
        } catch {
            items = []
            errorText = error.localizedDescription
        }
    }
}
