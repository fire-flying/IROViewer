import SwiftUI

struct ContentView: View {
    @State private var category: CameraClient.Category = .normal
    @State private var items: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var destination: Destination?

    private let client = CameraClient()

    /// 行程列表按日期分组，最新的日期和行程在最前
    private var tripGroups: [(date: String, trips: [Trip])] {
        var groups: [(date: String, trips: [Trip])] = []
        for trip in TripBuilder.build(from: items) {
            let date = trip.dateText
            if let index = groups.firstIndex(where: { $0.date == date }) {
                groups[index].trips.append(trip)
            } else {
                groups.append((date, [trip]))
            }
        }
        return groups
    }

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

                if isLoading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在读取车机文件列表…")
                        }
                    }
                } else if items.isEmpty {
                    Section {
                        Text("没有找到文件")
                            .foregroundStyle(.secondary)
                    }
                } else if category == .photo {
                    Section("照片") {
                        ForEach(items) { item in
                            Button {
                                destination = .photo(item)
                            } label: {
                                photoRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    ForEach(tripGroups, id: \.date) { group in
                        Section(group.date) {
                            ForEach(group.trips) { trip in
                                Button {
                                    destination = .trip(trip)
                                } label: {
                                    tripRow(trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
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
            .fullScreenCover(item: $destination) { target in
                switch target {
                case .trip(let trip):
                    PlaybackView(items: trip.items, selected: trip.first)
                case .photo(let item):
                    PhotoPreviewView(item: item)
                }
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.timeRange)
                    .font(.body.monospacedDigit())
                Text("\(trip.items.count) 段 · \(trip.totalSizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }

    private func photoRow(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.fill")
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

enum Destination: Identifiable {
    case trip(Trip)
    case photo(MediaItem)

    var id: String {
        switch self {
        case .trip(let trip): return "trip-" + trip.id
        case .photo(let item): return "photo-" + item.id
        }
    }
}
