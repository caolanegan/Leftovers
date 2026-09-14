import Testing
import UIKit
@testable import MealPlanner

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
}
