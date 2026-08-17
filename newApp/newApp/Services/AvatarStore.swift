//
//  AvatarStore.swift
//  Alpha Academy
//
//  The avatar photo lives on disk as a JPEG, not inside the state JSON.
//  Base64 image data in that file would multiply its size and force a full
//  rewrite on every debounced save.
//

import Combine
import SwiftUI
import UIKit

final class AvatarStore: ObservableObject {

    static let shared = AvatarStore()

    /// Published so every avatar on screen updates the moment a new photo
    /// is chosen, without threading the image through the view tree.
    @Published private(set) var image: UIImage?

    /// Photos are downscaled before saving. A full-resolution shot from a
    /// modern camera is ~4 MB and we draw it at 72 pt.
    private let maxDimension: CGFloat = 512
    private let fileName = "avatar.jpg"

    private let directoryURL: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        directoryURL = base.appendingPathComponent("AlphaAcademy", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true
        )
        image = loadFromDisk()
    }

    private var fileURL: URL { directoryURL.appendingPathComponent(fileName) }

    // MARK: - Reading

    private func loadFromDisk() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    var hasPhoto: Bool { image != nil }

    // MARK: - Writing

    /// Returns false when the data could not be decoded, so the caller can
    /// tell the user instead of silently keeping the old avatar.
    @discardableResult
    func save(_ data: Data) -> Bool {
        guard let decoded = UIImage(data: data) else { return false }
        let resized = decoded.downscaled(to: maxDimension)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return false }
        try? jpeg.write(to: fileURL, options: [.atomic])
        image = resized
        return true
    }

    func removePhoto() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
    }
}

private extension UIImage {
    /// Aspect-fit downscale. Returns self when already small enough, so a
    /// modest image is never re-encoded for nothing.
    func downscaled(to maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
