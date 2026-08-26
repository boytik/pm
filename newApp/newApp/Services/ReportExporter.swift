import CoreGraphics
import SwiftUI
import UIKit

enum ReportExporter {
    enum ExportError: Error {
        case renderFailed
        case writeFailed
    }

    @MainActor
    static func model(from store: AppStore) -> TrainingRecordView.Model {
        let alphabet = store.activeAlphabet
        let levels = store.progressMap().mapValues(\.level)

        let modeRows: [(title: String, percent: Int)] = TrainingMode.practiceModes
            .compactMap { mode in
                guard let accuracy = store.stats.accuracyByMode[mode],
                      accuracy.sampleSize >= 5 else { return nil }
                return (mode.title, Int((accuracy.allTime * 100).rounded()))
            }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return TrainingRecordView.Model(
            callsign: store.profile.callsign,
            name: store.profile.name,
            rank: store.profile.rank.title,
            xp: store.profile.xp,
            masteryPercent: Int((store.mastery() * 100).rounded()),
            accuracyPercent: Int((store.stats.overallAccuracy * 100).rounded()),
            streakDays: store.profile.streakDays,
            sessions: store.state.counters.totalSessions,
            practiceMinutes: store.stats.totalPracticeMinutes,
            alphabetName: alphabet.displayName,
            provenance: alphabet.provenance,
            entries: alphabet.trainable,
            levels: levels,
            modeRows: modeRows,
            achievementsUnlocked: store.stats.achievementsUnlocked,
            achievementsTotal: store.stats.achievementsTotal,
            dateText: formatter.string(from: Date()),
            avatarProfile: store.profile,
            avatarPhoto: AvatarStore.shared.image
        )
    }

    @MainActor
    static func exportPDF(model: TrainingRecordView.Model) throws -> URL {
        let view = TrainingRecordView(model: model)
        let renderer = ImageRenderer(content: view)

        renderer.scale = 1

        let pageSize = TrainingRecordView.pageSize
        let box = CGRect(origin: .zero, size: pageSize)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.renderFailed
        }

        var mediaBox = box
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderFailed
        }

        var didRender = false
        renderer.render { _, renderInContext in
            context.beginPDFPage(nil)

            renderInContext(context)
            context.endPDFPage()
            didRender = true
        }
        context.closePDF()

        guard didRender, data.length > 0 else { throw ExportError.renderFailed }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: model))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return url
    }

    private static func fileName(for model: TrainingRecordView.Model) -> String {
        let who = model.callsign.isEmpty ? "Training Record" : model.callsign
        let safe = who
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
        return "Alpha Academy — \(safe).pdf"
    }
}
