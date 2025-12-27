import Foundation

struct TonChainNFT: Decodable, Hashable {
    struct Owner: Decodable, Hashable {
        let address: String?
    }

    struct Metadata: Decodable, Hashable {
        let name: String?
        let description: String?
        let image: String?
        let contentUrl: String?
    }

    let address: String
    let owner: Owner?
    let metadata: Metadata?
}

private struct TonNftsEnvelope: Decodable {
    let nftItems: [TonChainNFT]?

    private enum CodingKeys: String, CodingKey {
        case nftItems = "nft_items"
    }
}

enum TonLinks {
    static func tonViewerURL(for address: String) -> URL? {
        URL(string: "https://tonviewer.com/\(address)")
    }

    static func transferURL(for address: String) -> URL? {
        URL(string: "ton://transfer/\(address)?amount=0")
    }

    static func normalizedImageURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("ipfs://") {
            let path = String(trimmed.dropFirst(7))
            return URL(string: "https://ipfs.io/ipfs/\(path)")
        }
        return URL(string: trimmed)
    }
}

actor TonAssetService {
    static let shared = TonAssetService()

    private let session: URLSession
    private let apiKey: String?
    private let collectionAddress: String?
    private let endpoint: URL

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        let info = bundle.infoDictionary ?? [:]
        self.apiKey = info["TONAPIKey"] as? String
        let configuredCollection = (info["TONCollectionAddress"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.collectionAddress = (configuredCollection?.isEmpty ?? true) ? nil : configuredCollection
        let endpointString = (info["TONAPIEndpoint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.endpoint = URL(string: endpointString ?? "https://tonapi.io/v2") ?? URL(string: "https://tonapi.io/v2")!
    }

    static func normalizeAddress(_ address: String?) -> String? {
        // TON addresses are case-sensitive; keep as-is except trimming spaces.
        address?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchOwnedNFTs(ownerAddress: String) async throws -> [TonChainNFT] {
        guard let collectionAddress, !collectionAddress.isEmpty else {
            throw TonAssetServiceError.configurationMissing
        }
        let base = endpoint
            .appendingPathComponent("accounts")
            .appendingPathComponent(ownerAddress)
            .appendingPathComponent("nfts")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "collection", value: collectionAddress)]
        guard let url = components?.url else {
            throw TonAssetServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TonAssetServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(TonNftsEnvelope.self, from: data)
        return envelope.nftItems ?? []
    }

    enum TonAssetServiceError: Error, LocalizedError {
        case configurationMissing
        case invalidRequest
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .configurationMissing:
                return "TON конфигурация отсутствует."
            case .invalidRequest:
                return "Некорректный запрос к TON API."
            case .invalidResponse:
                return "TON API вернуло ошибку."
            }
        }
    }
}
