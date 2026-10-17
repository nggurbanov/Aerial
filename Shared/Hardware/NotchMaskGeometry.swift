import CoreGraphics

/// Geometry in the destination layer's coordinates, independent of video
/// scaling/spanning and informational overlay visibility.
enum NotchMaskGeometry {
    static func frame(screenSize: CGSize, topInset: CGFloat, destinationSize: CGSize,
                      contentsScale: CGFloat, isGeometryFlipped: Bool = false) -> CGRect? {
        guard screenSize.width.isFinite, screenSize.width > 0,
              screenSize.height.isFinite, screenSize.height > 0,
              topInset.isFinite, topInset > 0, topInset < screenSize.height,
              destinationSize.width.isFinite, destinationSize.width > 0,
              destinationSize.height.isFinite, destinationSize.height > 0,
              contentsScale.isFinite, contentsScale > 0 else { return nil }

        // Destinations can be scaled picker previews. NSScreen insets are
        // points, not pixels; round up to avoid a bright subpixel seam.
        let scaledHeight = (topInset / screenSize.height) * destinationSize.height
        let pixels = scaledHeight * contentsScale
        guard pixels.isFinite else { return nil }
        let height = min(destinationSize.height, ceil(pixels) / contentsScale)
        return CGRect(x: 0, y: isGeometryFlipped ? 0 : destinationSize.height - height,
                      width: destinationSize.width, height: height)
    }
}
