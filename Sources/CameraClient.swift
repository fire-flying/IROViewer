import Foundation

/// 与车机（MStar 平台）通信的最小客户端
final class CameraClient {
    static let host = "192.168.1.1"
    static let baseURL = "http://\(host)"

    enum Category: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case event = "Event"
        case photo = "Photo"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .normal: return "普通录像"
            case .event: return "紧急录像"
            case .photo: return "照片"
            }
        }
    }

    struct FetchResult {
        let amount: Int
        let items: [MediaItem]
    }

    enum ClientError: LocalizedError {
        case badURL
        case badStatus(Int)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "车机地址无效"
            case .badStatus(let code):
                return "车机返回 HTTP \(code)"
            case .parseFailed:
                return "无法解析车机返回的文件列表"
            }
        }
    }

    /// 读取文件列表。车机返回 XML，amount 为总数，file 节点为每个文件。
    func fetchList(category: Category) async throws -> FetchResult {
        let urlString = "\(CameraClient.baseURL)/cgi-bin/Config.cgi"
            + "?action=dir&property=\(category.rawValue)&format=all&from=0&count=1000&backward="

        guard let url = URL(string: urlString) else { throw ClientError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ClientError.parseFailed }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.badStatus(http.statusCode)
        }

        let parser = ListParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { throw ClientError.parseFailed }

        // 倒序：最新的排在最前
        let items = parser.items.sorted { $0.sortKey > $1.sortKey }
        return FetchResult(amount: parser.amount, items: items)
    }
}

private final class ListParser: NSObject, XMLParserDelegate {
    var amount = 0
    var items: [MediaItem] = []

    private var buffer = ""
    private var insideFile = false
    private var fields: [String: String] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        buffer = ""
        if elementName == "file" {
            insideFile = true
            fields = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideFile {
            if ["name", "size", "time", "attr"].contains(elementName) {
                fields[elementName] = text
            }
            if elementName == "file" {
                if let name = fields["name"], !name.isEmpty {
                    let size = Int64(fields["size"] ?? "") ?? 0
                    items.append(MediaItem(name: name, size: size, timeText: fields["time"] ?? ""))
                }
                insideFile = false
            }
        } else if elementName == "amount" {
            amount = Int(text) ?? 0
        }

        buffer = ""
    }
}
