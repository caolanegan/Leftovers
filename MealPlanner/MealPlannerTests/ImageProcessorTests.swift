import Testing
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Leftovers

@MainActor
struct ImageProcessorTests {
    @Test
    func resizesPhotoAndCropsThumbnail() async throws {
        let data = try #require(Self.makeImageData(width: 4000, height: 3000))
        let prepared = try await ImageProcessor.prepare(data)

        let photo = try #require(UIImage(data: prepared.photo))
        #expect(photo.size.width == 1600)
        #expect(photo.size.height == 1200)

        let thumbnail = try #require(UIImage(data: prepared.thumbnail))
        #expect(thumbnail.size.width == 300)
        #expect(thumbnail.size.height == 300)
    }

    @Test
    func leavesSmallImagesUnscaled() async throws {
        let data = try #require(Self.makeImageData(width: 800, height: 600))
        let prepared = try await ImageProcessor.prepare(data)

        let photo = try #require(UIImage(data: prepared.photo))
        #expect(photo.size.width == 800)
        #expect(photo.size.height == 600)
    }

    @Test
    func fixesExifOrientationForARotatedImage() async throws {
        // Pixel data is stored landscape (400×300) but tagged EXIF orientation 6 (.right),
        // meaning the image must be rotated 90° to display correctly — i.e. portrait.
        let data = try #require(Self.makeExifTaggedImageData(width: 400, height: 300, orientation: .right))
        let prepared = try await ImageProcessor.prepare(data)

        let photo = try #require(UIImage(data: prepared.photo))
        #expect(photo.size.width < photo.size.height)
    }

    @Test
    func throwsOnInvalidData() async {
        let data = Data([0x00, 0x01, 0x02])
        await #expect(throws: AppError.imageProcessingFailed) {
            _ = try await ImageProcessor.prepare(data)
        }
    }

    private static func makeImageData(width: Int, height: Int) -> Data? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1)
    }

    private static func makeExifTaggedImageData(width: Int, height: Int, orientation: CGImagePropertyOrientation) -> Data? {
        guard let data = makeImageData(width: width, height: height),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation.rawValue]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
