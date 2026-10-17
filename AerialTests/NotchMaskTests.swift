import Testing
import Foundation
import CoreGraphics
import QuartzCore
@testable import Aerial

@Suite("Notch mask")
struct NotchMaskTests {
    private let screen = CGSize(width: 1512, height: 982)

    @Test("Notched display gets a full-width top strip in points")
    func notchedDisplay() {
        let rect = NotchMaskGeometry.frame(screenSize: screen, topInset: 32,
                                          destinationSize: screen, contentsScale: 2)
        #expect(rect == CGRect(x: 0, y: 950, width: 1512, height: 32))
    }

    @Test("Strip reaches the menu-bar boundary when it extends below the notch")
    func fullMenuBarHeight() {
        let macBook = CGSize(width: 1470, height: 956)
        #expect(NotchMaskGeometry.frame(screenSize: macBook, topInset: 32, menuBarHeight: 33,
                                       destinationSize: macBook, contentsScale: 2)
                == CGRect(x: 0, y: 923, width: 1470, height: 33))
    }

    @Test("Menu-bar height alone never masks a display without a notch")
    func unnotchedMenuBar() {
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 0, menuBarHeight: 24,
                                       destinationSize: screen, contentsScale: 2) == nil)
    }

    @Test("Hidden menu bar still covers the physical notch")
    func hiddenMenuBar() {
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 32, menuBarHeight: 0,
                                       destinationSize: screen, contentsScale: 2)?.height == 32)
    }

    @Test("Displays without a notch are unchanged")
    func noNotch() {
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 0,
                                       destinationSize: screen, contentsScale: 2) == nil)
    }

    @Test("Preview geometry scales with the destination and rounds out to pixels")
    func scaledPreview() throws {
        let rect = try #require(NotchMaskGeometry.frame(
            screenSize: screen, topInset: 32,
            destinationSize: CGSize(width: 378, height: 245.5), contentsScale: 2))
        #expect(rect == CGRect(x: 0, y: 237.5, width: 378, height: 8))
        let fractional = try #require(NotchMaskGeometry.frame(
            screenSize: screen, topInset: 32,
            destinationSize: CGSize(width: 400, height: 260), contentsScale: 2))
        #expect(fractional.height == 8.5)
        #expect(fractional.maxY == 260)
    }

    @Test("Flipped layer coordinates still place the strip at the top")
    func flippedCoordinates() {
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 32,
                                       destinationSize: screen, contentsScale: 2,
                                       isGeometryFlipped: true)?.minY == 0)
    }

    @Test("Invalid display geometry produces no mask", arguments: [CGFloat.nan, .infinity, -.infinity, -1, 0])
    func invalidGeometry(value: CGFloat) {
        #expect(NotchMaskGeometry.frame(screenSize: CGSize(width: value, height: 982), topInset: 32,
                                       destinationSize: screen, contentsScale: 2) == nil)
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: value,
                                       destinationSize: screen, contentsScale: 2) == nil)
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 32,
                                       destinationSize: CGSize(width: 1512, height: value), contentsScale: 2) == nil)
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 32,
                                       destinationSize: screen, contentsScale: value) == nil)
    }

    @Test("An inset covering the whole display is rejected")
    func invalidInset() {
        #expect(NotchMaskGeometry.frame(screenSize: screen, topInset: 982,
                                       destinationSize: screen, contentsScale: 2) == nil)
    }

    @Test("Notch geometry follows display scale and preview size",
          arguments: [CGSize(width: 1280, height: 832), CGSize(width: 1470, height: 956),
                      CGSize(width: 1512, height: 982), CGSize(width: 1728, height: 1117),
                      CGSize(width: 1800, height: 1169), CGSize(width: 2056, height: 1329)])
    func displayModes(size: CGSize) throws {
        for scale: CGFloat in [1, 1.5, 2, 3] {
            for ratio: CGFloat in [0.1, 0.25, 1] {
                let destination = CGSize(width: size.width * ratio, height: size.height * ratio)
                let rect = try #require(NotchMaskGeometry.frame(
                    screenSize: size, topInset: 32, menuBarHeight: 33,
                    destinationSize: destination, contentsScale: scale))
                #expect(rect.width == destination.width)
                #expect(abs(rect.maxY - destination.height) < 1e-9)
                #expect(rect.height >= 33 * ratio - 1e-9)
                #expect(rect.height < 33 * ratio + 1 / scale + 1e-9)
            }
        }
    }

    @Test("Mask geometry stays inside the destination and covers the safe area")
    func geometryProperties() throws {
        try forAll(iterations: 1_000, seed: 0xA3E1A1) { rng, _ in
            let size = CGSize(width: rng.double(640...8192), height: rng.double(400...4320))
            let inset = CGFloat(rng.double(16...80))
            let menu = CGFloat(rng.double(0...90))
            let destination = CGSize(width: rng.double(32...8192), height: rng.double(32...4320))
            let scale = CGFloat(rng.double(1...4))
            let flipped = rng.bool()
            let rect = try #require(NotchMaskGeometry.frame(
                screenSize: size, topInset: inset, menuBarHeight: menu,
                destinationSize: destination, contentsScale: scale, isGeometryFlipped: flipped))
            let expected = max(inset, menu) / size.height * destination.height
            #expect(rect.minX == 0 && rect.width == destination.width, "\(rng.trail)")
            #expect(rect.minY >= 0 && rect.maxY <= destination.height + 1e-9, "\(rng.trail)")
            #expect(rect.height >= expected - 1e-9, "\(rng.trail)")
            #expect(rect.height < expected + 1 / scale + 1e-9, "\(rng.trail)")
            #expect(flipped ? rect.minY == 0 : abs(rect.maxY - destination.height) < 1e-9, "\(rng.trail)")
        }
    }

    @Test("Invalid dimensions and menu-bar measurements never reach a layer")
    func invalidDimensions() {
        for value: CGFloat in [.nan, .infinity, -.infinity, -1, 0] {
            #expect(NotchMaskGeometry.frame(
                screenSize: CGSize(width: 1512, height: value), topInset: 32,
                destinationSize: screen, contentsScale: 2) == nil)
            #expect(NotchMaskGeometry.frame(
                screenSize: screen, topInset: 32,
                destinationSize: CGSize(width: value, height: 982), contentsScale: 2) == nil)
        }
        for value: CGFloat in [.nan, .infinity, -.infinity, -1, 982, 2000] {
            #expect(NotchMaskGeometry.frame(
                screenSize: screen, topInset: 32, menuBarHeight: value,
                destinationSize: screen, contentsScale: 2) == nil)
        }
        #expect(NotchMaskGeometry.frame(
            screenSize: screen, topInset: 32,
            destinationSize: CGSize(width: 1512, height: CGFloat.greatestFiniteMagnitude),
            contentsScale: .greatestFiniteMagnitude) == nil)
    }

    @Test("Screen relay round-trips mixed displays and updates resolution without stale geometry")
    func screenRelay() throws {
        var state = WallpaperControlState()
        state.notchMaskScreens = [
            "laptop": .init(size: screen, topInset: 32, menuBarHeight: 33),
            "external": .init(size: CGSize(width: 2560, height: 1440), topInset: 0, menuBarHeight: 24)
        ]
        var decoded = try JSONDecoder().decode(WallpaperControlState.self,
                                               from: JSONEncoder().encode(state))
        #expect(decoded.notchMaskScreens == state.notchMaskScreens)
        #expect(decoded.notchMaskScreens["external"]?.maskFrame(destinationSize: screen, contentsScale: 2) == nil)
        // Companion can publish a new logical resolution while the extension's
        // NSScreen object still reports the previous one.
        decoded.notchMaskScreens["laptop"] = .init(size: CGSize(width: 1800, height: 1169),
                                                  topInset: 38, menuBarHeight: 39)
        #expect(decoded.notchMaskScreens["laptop"]?.maskFrame(
            destinationSize: CGSize(width: 1800, height: 1169), contentsScale: 2)?.height == 39)
        let legacy = try JSONDecoder().decode(WallpaperControlState.self, from: Data("{}".utf8))
        #expect(legacy.notchMaskScreens.isEmpty)
    }

    @Test("Legacy settings without hideNotch retain existing display preferences")
    func legacySettings() throws {
        var original = ScreensaverSettings.default
        original.displays.intViewingMode = 2
        original.displays.horizontalMargin = 5
        original.displaysDesktop.intAspectMode = 1
        let data = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["displays", "displaysDesktop"] {
            var display = try #require(json[key] as? [String: Any])
            display.removeValue(forKey: "hideNotch")
            json[key] = display
        }
        let decoded = try JSONDecoder().decode(ScreensaverSettings.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.displays.hideNotch)
        #expect(!decoded.displaysDesktop.hideNotch)
        #expect(decoded.displays.intViewingMode == 2)
        #expect(decoded.displays.horizontalMargin == 5)
        #expect(decoded.displaysDesktop.intAspectMode == 1)
    }

    @Test("Enabled notch setting survives a full settings round trip")
    func enabledRoundTrip() throws {
        var settings = ScreensaverSettings.default
        settings.displays.hideNotch = true
        let decoded = try JSONDecoder().decode(ScreensaverSettings.self,
                                               from: JSONEncoder().encode(settings))
        #expect(decoded.displays.hideNotch)
    }

    @Test("Mask stays above content and is reused, resized and removed")
    @MainActor
    func layerLifecycle() throws {
        let root = CALayer()
        root.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        root.backgroundColor = CGColor(gray: 1, alpha: 1)
        let overlay = CALayer()
        overlay.frame = root.bounds
        overlay.backgroundColor = CGColor(gray: 1, alpha: 1)
        root.addSublayer(overlay)
        let frame = CGRect(x: 0, y: 90, width: 100, height: 10)
        let mask = try #require(NotchMaskLayer.update(existing: nil, rootLayer: root,
                                                     frame: frame, contentsScale: 2))
        #expect(mask.frame == frame)
        #expect(mask.superlayer === root)
        #expect(mask.zPosition > overlay.zPosition)
        #expect(mask.backgroundColor == CGColor(gray: 0, alpha: 1))
        let context = try #require(CGContext(data: nil, width: 100, height: 100,
                                            bitsPerComponent: 8, bytesPerRow: 400,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        root.render(in: context)
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        var black = 0
        var white = 0
        for index in 0..<10_000 {
            let offset = index * 4
            if pixels[offset] == 0 && pixels[offset + 1] == 0 && pixels[offset + 2] == 0 {
                black += 1
            } else if pixels[offset] == 255 && pixels[offset + 1] == 255 && pixels[offset + 2] == 255 {
                white += 1
            }
        }
        #expect(black == 1_000)
        #expect(white == 9_000)
        // CALayer.render(in:) flattens sublayers in tree order, so test
        // late-overlay compositor stacking through zPosition separately.
        let laterOverlay = CALayer()
        laterOverlay.frame = root.bounds
        laterOverlay.backgroundColor = overlay.backgroundColor
        root.addSublayer(laterOverlay)
        #expect(mask.zPosition > laterOverlay.zPosition)
        let resized = CGRect(x: 0, y: 180, width: 200, height: 20)
        #expect(NotchMaskLayer.update(existing: mask, rootLayer: root,
                                     frame: resized, contentsScale: 1) === mask)
        #expect(mask.frame == resized)
        #expect(mask.contentsScale == 1)
        #expect(mask.animationKeys()?.isEmpty ?? true)
        #expect(root.sublayers?.count == 3)
        #expect(NotchMaskLayer.update(existing: mask, rootLayer: root,
                                     frame: nil, contentsScale: 1) == nil)
        #expect(mask.superlayer == nil)
        #expect(root.sublayers?.count == 2)
        let newRoot = CALayer()
        #expect(NotchMaskLayer.update(existing: mask, rootLayer: newRoot,
                                     frame: resized, contentsScale: 2) === mask)
        #expect(mask.superlayer === newRoot)
        #expect(newRoot.sublayers?.count == 1)
    }

}
