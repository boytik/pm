import Foundation

enum PersistenceError: Error {
    case unsupportedSchema(Int)
}

final class PersistenceStore {
    static let shared = PersistenceStore()

    private let fileName = "state.json"
    private let corruptFileName = "state.corrupt.json"
    private let hasLaunchedKey = "com.alphaacademy.hasLaunchedBefore"

    private let directoryURL: URL

    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        #if DEBUG
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        #endif
        return encoder
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        directoryURL = base.appendingPathComponent("AlphaAcademy", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private var fileURL: URL { directoryURL.appendingPathComponent(fileName) }

    func load() -> AppState {
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: hasLaunchedKey)

        guard let data = try? Data(contentsOf: fileURL) else {
            defaults.set(true, forKey: hasLaunchedKey)
            var fresh = AppState.freshInstall()

            if hasLaunchedBefore {
                fresh.profile.hasOnboarded = true
            }
            return fresh
        }

        do {
            return try migrate(data)
        } catch {
            let corruptURL = directoryURL.appendingPathComponent(corruptFileName)
            try? FileManager.default.removeItem(at: corruptURL)
            try? FileManager.default.moveItem(at: fileURL, to: corruptURL)

            var fresh = AppState.freshInstall()
            fresh.profile.hasOnboarded = hasLaunchedBefore
            return fresh
        }
    }

    func save(_ state: AppState) {
        guard let data = try? encoder.encode(state) else { return }

        try? data.write(to: fileURL, options: [.atomic])
        UserDefaults.standard.set(true, forKey: hasLaunchedKey)
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
    }

    private func migrate(_ data: Data) throws -> AppState {
        let version = (try? decoder.decode(SchemaProbe.self, from: data))?.schemaVersion ?? 0

        switch version {
        case AppState.currentSchemaVersion:
            return try decoder.decode(AppState.self, from: data)

        default:
            throw PersistenceError.unsupportedSchema(version)
        }
    }
}
