import Foundation
import UIKit
import ImageIO

struct PreparedPhoto: Sendable {
    let photo: Data
    let thumbnail: Data
}

enum ImageProcessor {
    private nonisolated static let maxLongEdge: CGFloat = 1600
    private nonisolated static let thumbnailSide: CGFloat = 300

    /// Decodes `data` straight to a downsampled, correctly oriented bitmap via ImageIO — never
    /// holds the full-resolution image (≈190 MB for a 48 MP photo) in memory.
    @concurrent
    nonisolated static func prepare(_ data: Data) async throws -> PreparedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AppError.imageProcessingFailed
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxLongEdge),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AppError.imageProcessingFailed
        }
        return try await prepare(UIImage(cgImage: cgImage))
    }

    /// Prepares an already-decoded image (e.g. straight from the camera) without a Data round-trip.
    @concurrent
    nonisolated static func prepare(_ image: UIImage) async throws -> PreparedPhoto {
        let resizedImage = resized(image, maxLongEdge: maxLongEdge)
        guard let photoData = resizedImage.jpegData(compressionQuality: 0.8),
              let thumbnailData = croppedSquare(resizedImage, side: thumbnailSide).jpegData(compressionQuality: 0.7)
        else { throw AppError.imageProcessingFailed }

        return PreparedPhoto(photo: photoData, thumbnail: thumbnailData)
    }

    /// Redraws `image` scaled so its long edge is at most `maxLongEdge`, fixing orientation in the process.
    private nonisolated static func resized(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        let scale = min(1, maxLongEdge / longEdge)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Redraws `image` cropped to a centred square and scaled to `side` × `side`, fixing orientation in the process.
    private nonisolated static func croppedSquare(_ image: UIImage, side: CGFloat) -> UIImage {
        let size = image.size
        let shortEdge = min(size.width, size.height)
        let cropRect = CGRect(
            x: (size.width - shortEdge) / 2,
            y: (size.height - shortEdge) / 2,
            width: shortEdge,
            height: shortEdge
        )
        let targetSize = CGSize(width: side, height: side)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            let drawScale = side / shortEdge
            image.draw(in: CGRect(
                x: -cropRect.minX * drawScale,
                y: -cropRect.minY * drawScale,
                width: size.width * drawScale,
                height: size.height * drawScale
            ))
        }
    }
}
