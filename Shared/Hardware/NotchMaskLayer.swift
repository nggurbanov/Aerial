import QuartzCore

/// A static layer: no timer, image rendering, or per-video work.
@MainActor
enum NotchMaskLayer {
    static func update(existing: CALayer?, rootLayer: CALayer,
                       frame: CGRect?, contentsScale: CGFloat) -> CALayer? {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let frame else {
            existing?.removeFromSuperlayer()
            return nil
        }
        let layer = existing ?? CALayer()
        layer.name = "Aerial notch mask"
        layer.backgroundColor = CGColor(gray: 0, alpha: 1)
        layer.isOpaque = true
        layer.zPosition = 20_000 // above video transitions, overlays and diagnostics
        layer.frame = frame
        layer.contentsScale = contentsScale
        if layer.superlayer !== rootLayer { rootLayer.addSublayer(layer) }
        return layer
    }
}
