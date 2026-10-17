import CoreGraphics
import Foundation

/// Geometry in the destination layer's coordinates, independent of video
/// scaling/spanning and informational overlay visibility.
enum NotchMaskGeometry {
    /// Companion measures this on screen-parameter changes. The extension's
    /// NSScreen cache can otherwise retain an old resolution or safe area.
    struct Screen: Codable, Equatable, Sendable {
        var size: CGSize
        var topInset: CGFloat
        var menuBarHeight: CGFloat

        func maskFrame(destinationSize: CGSize, contentsScale: CGFloat,
                       isGeometryFlipped: Bool = false) -> CGRect? {
            NotchMaskGeometry.frame(screenSize: size, topInset: topInset,
                                   menuBarHeight: menuBarHeight, destinationSize: destinationSize,
                                   contentsScale: contentsScale, isGeometryFlipped: isGeometryFlipped)
        }
    }

    static func frame(screenSize: CGSize, topInset: CGFloat, menuBarHeight: CGFloat = 0,
                      destinationSize: CGSize,
                      contentsScale: CGFloat, isGeometryFlipped: Bool = false) -> CGRect? {
        guard screenSize.width.isFinite, screenSize.width > 0,
              screenSize.height.isFinite, screenSize.height > 0,
              topInset.isFinite, topInset > 0, topInset < screenSize.height,
              menuBarHeight.isFinite, menuBarHeight >= 0, menuBarHeight < screenSize.height,
              destinationSize.width.isFinite, destinationSize.width > 0,
              destinationSize.height.isFinite, destinationSize.height > 0,
              contentsScale.isFinite, contentsScale > 0 else { return nil }

        // Destinations can be scaled picker previews. NSScreen insets are
        // points, not pixels; round up to avoid a bright subpixel seam.
        // The menu bar can extend below the camera safe area (33 vs
        // 32 pt on a notched MacBook). Cover its entire height so the
        // wallpaper cannot leak through a narrow seam below the notch.
        let bandHeight = max(topInset, menuBarHeight)
        let scaledHeight = (bandHeight / screenSize.height) * destinationSize.height
        let pixels = scaledHeight * contentsScale
        guard pixels.isFinite else { return nil }
        let height = min(destinationSize.height, ceil(pixels) / contentsScale)
        return CGRect(x: 0, y: isGeometryFlipped ? 0 : destinationSize.height - height,
                      width: destinationSize.width, height: height)
    }
}
