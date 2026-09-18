import UIKit

/// §12.3.
@MainActor
enum ShareService {
    static func present(items: [Any], completion: @escaping (Bool) -> Void) {
        guard let presenter = topMostViewController() else {
            completion(false)
            return
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = presenter.view
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        presenter.present(activityVC, animated: true)
    }

    /// The key window of the foreground-active `UIWindowScene`, then walked
    /// down through `presentedViewController` (§12.3).
    private static func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
