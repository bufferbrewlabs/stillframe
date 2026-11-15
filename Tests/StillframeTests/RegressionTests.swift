import XCTest
import AppKit
import Carbon
@testable import Stillframe

/// Regression coverage for library persistence, file safety, capture arguments,
/// recording size limits and stitching failure modes.
final class RegressionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("StillframeTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func solidImage(width: Int = 120, height: Int = 80) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 255, bitmap.bytesPerRow * height)
        let image = NSImage(size: NSSize(width: width, height: height)); image.addRepresentation(bitmap)
        return image
    }

    /// Rows repeat every `period` pixels, so several vertical shifts match equally well.
    private func stripes(width: Int = 160, height: Int = 320, period: Int = 20, offset: Int = 0) -> CGImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let pixels = bitmap.bitmapData!
        for y in 0..<height { for x in 0..<width {
            let value = UInt8(((y + offset) % period) * 255 / max(1, period - 1))
            let index = y * bitmap.bytesPerRow + x * 4
            pixels[index] = value; pixels[index + 1] = value; pixels[index + 2] = value; pixels[index + 3] = 255
        } }
        return bitmap.cgImage!
    }

    // MARK: Library persistence

    @MainActor func testCorruptHistoryIsKeptAsideAndNotOverwrittenByTheNextCapture() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let corrupt = Data("{ not json".utf8)
        try corrupt.write(to: root.appendingPathComponent("history.json"))

        let store = CaptureStore(root: root)
        let message = try XCTUnwrap(store.error)
        XCTAssertTrue(message.contains("history.corrupt-"), message)
        XCTAssertTrue(store.items.isEmpty)

        XCTAssertTrue(store.add(image: solidImage(), title: "After recovery"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("history.corrupt-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(backups[0])), corrupt)

        let reopened = CaptureStore(root: root)
        XCTAssertNil(reopened.error)
        XCTAssertEqual(reopened.items.map(\.title), ["After recovery"])
    }

    @MainActor func testSettingsAndHistoryLoadFailuresAreBothReported() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("bad".utf8).write(to: root.appendingPathComponent("preferences.json"))
        try Data("bad".utf8).write(to: root.appendingPathComponent("history.json"))
        let message = try XCTUnwrap(CaptureStore(root: root).error)
        XCTAssertTrue(message.contains("Could not load settings"), message)
        XCTAssertTrue(message.contains("Could not load capture history"), message)
    }

    @MainActor func testCaptureWhoseFileWasRemovedExternallyCanStillBeDeleted() throws {
        let store = CaptureStore(root: root)
        XCTAssertTrue(store.add(image: solidImage()))
        let item = try XCTUnwrap(store.selected)
        try FileManager.default.removeItem(at: store.url(for: item))

        store.removeSelected()
        XCTAssertNil(store.error)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(CaptureStore(root: root).items.isEmpty)
    }

    @MainActor func testLibraryFilenamesCannotEscapeTheLibraryFolder() throws {
        XCTAssertEqual(CaptureStore.libraryFilename("ABC.png"), "ABC.png")
        XCTAssertEqual(CaptureStore.libraryFilename("../../etc/passwd"), "passwd")
        for unsafe in ["", ".", "..", "/", "nested/.."] {
            XCTAssertEqual(CaptureStore.libraryFilename(unsafe), ".stillframe-invalid-filename", unsafe)
        }

        let store = CaptureStore(root: root)
        let outside = root.deletingLastPathComponent().appendingPathComponent("stillframe-outside-\(UUID().uuidString).png")
        try Data("keep me".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        let hostile = CaptureItem(title: "Edited by hand", filename: "../\(outside.lastPathComponent)")
        XCTAssertEqual(store.url(for: hostile).deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)

        store.items = [hostile]; store.select(hostile.id)
        store.removeSelected()
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path), "A file outside the library was deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path), "The library folder was deleted")
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor func testRenameTrimsWhitespaceAndIgnoresBlankTitles() throws {
        let store = CaptureStore(root: root)
        XCTAssertTrue(store.add(image: solidImage(), title: "Original"))
        store.rename("  Release notes \n")
        XCTAssertEqual(store.selected?.title, "Release notes")
        store.rename("   ")
        XCTAssertEqual(store.selected?.title, "Release notes")
        XCTAssertEqual(CaptureStore(root: root).items.first?.title, "Release notes")
    }

    @MainActor func testLibrarySearchIsCaseInsensitiveAndFiltersByKind() {
        let store = CaptureStore(root: root)
        XCTAssertTrue(store.add(image: solidImage(), title: "Invoice draft"))
        store.addVideo(root.appendingPathComponent("demo.mp4"))
        XCTAssertEqual(store.visibleItems.count, 2)
        store.filter = "image"; XCTAssertEqual(store.visibleItems.map(\.title), ["Invoice draft"])
        store.filter = "video"; XCTAssertEqual(store.visibleItems.map(\.title), ["Screen recording"])
        store.filter = "all"; store.search = "INVOICE"
        XCTAssertEqual(store.visibleItems.map(\.title), ["Invoice draft"])
        store.search = "missing"; XCTAssertTrue(store.visibleItems.isEmpty)
    }

    @MainActor func testVideoSelectionHasNoRenderedImageOrScrollingSeed() {
        let store = CaptureStore(root: root)
        store.addVideo(root.appendingPathComponent("demo.mp4"))
        XCTAssertEqual(store.selected?.kind, "video")
        XCTAssertNil(store.rendered)
        XCTAssertNil(store.scrollingSeed)
    }

    // MARK: screencapture arguments

    func testScreenCaptureArgumentsForEachMode() {
        let output = URL(fileURLWithPath: "/tmp/out.png")
        let region = CGRect(x: 10.6, y: 20, width: 300, height: 200)
        XCTAssertEqual(ScreenCaptureTool.arguments(mode: .area, region: region, includeCursor: true, windowShadow: false, output: output),
                       ["-x", "-t", "png", "-R10,20,300,200", "/tmp/out.png"])
        XCTAssertEqual(ScreenCaptureTool.arguments(mode: .screen, region: nil, includeCursor: true, windowShadow: true, output: output),
                       ["-x", "-t", "png", "-m", "-C", "/tmp/out.png"])
        XCTAssertEqual(ScreenCaptureTool.arguments(mode: .screen, region: nil, includeCursor: false, windowShadow: true, output: output),
                       ["-x", "-t", "png", "-m", "/tmp/out.png"])
        XCTAssertEqual(ScreenCaptureTool.arguments(mode: .window, region: nil, includeCursor: true, windowShadow: false, output: output),
                       ["-x", "-t", "png", "-i", "-w", "-o", "/tmp/out.png"])
        XCTAssertEqual(ScreenCaptureTool.arguments(mode: .window, region: nil, includeCursor: false, windowShadow: true, output: output),
                       ["-x", "-t", "png", "-i", "-w", "/tmp/out.png"])
        XCTAssertEqual(ScreenCaptureTool.regionCaptureArguments(region, output: output), ["-x", "-R10,20,300,200", "/tmp/out.png"])
        XCTAssertEqual(CaptureMode.allCases.map(\.itemTitle), ["Area capture", "Window capture", "Fullscreen capture"])
    }

    // MARK: Recording configuration

    func testRecordingSizeStaysEvenWithinLimitAndKeepsAspectRatio() {
        let cases: [((Int, Int, Int), (Int, Int))] = [
            ((5120, 2880, 3840), (3840, 2160)),
            ((1920, 1080, 3840), (1920, 1080)),
            ((3024, 1964, 1920), (1662, 1080)),
            ((1001, 601, 3840), (1000, 600)),
            ((3440, 1440, 1920), (1920, 802)),
        ]
        for ((width, height, limit), expected) in cases {
            let size = Recorder.outputSize(displayWidth: width, displayHeight: height, maxWidth: limit)
            XCTAssertEqual(size.width, expected.0, "\(width)x\(height) @ \(limit)")
            XCTAssertEqual(size.height, expected.1, "\(width)x\(height) @ \(limit)")
            XCTAssertEqual(size.width % 2, 0); XCTAssertEqual(size.height % 2, 0)
        }
        let degenerate = Recorder.outputSize(displayWidth: 0, displayHeight: 0, maxWidth: 3840)
        XCTAssertEqual(degenerate.width, 2); XCTAssertEqual(degenerate.height, 2)
        XCTAssertEqual([15, 30, 60, 24, 0].map(Recorder.frameRate), [15, 30, 60, 30, 30])
    }

    // MARK: Stitching failure modes

    func testStitcherReportsNoMovementMismatchedFramesAndTinyFrames() {
        let frame = stripes(offset: 0)
        XCTAssertThrowsError(try ScrollStitcher.verticalShift(previous: frame, next: frame)) {
            guard case StitchError.noMovement = $0 else { return XCTFail("Expected noMovement, got \($0)") }
        }
        XCTAssertThrowsError(try ScrollStitcher.verticalShift(previous: frame, next: stripes(height: 300))) {
            guard case StitchError.dimensions = $0 else { return XCTFail("Expected dimensions, got \($0)") }
        }
        XCTAssertThrowsError(try ScrollStitcher.verticalShift(previous: stripes(height: 24), next: stripes(height: 24, offset: 5))) {
            guard case StitchError.noOverlap = $0 else { return XCTFail("Expected noOverlap, got \($0)") }
        }
    }

    func testStitcherRejectsRepeatingContentAsAmbiguous() {
        XCTAssertThrowsError(try ScrollStitcher.verticalShift(previous: stripes(offset: 0), next: stripes(offset: 90))) {
            guard case StitchError.ambiguous = $0 else { return XCTFail("Expected ambiguous, got \($0)") }
        }
    }

    func testEveryUserFacingErrorHasAMessage() {
        let stitch: [StitchError] = [.dimensions, .noMovement, .noOverlap, .ambiguous, .tooLarge, .invalidImage]
        let media: [MediaExportError] = [.invalidRange, .unsupported, .gifTooLong, .invalidGIFSettings, .overwriteSource]
        for message in stitch.map(\.errorDescription) + media.map(\.errorDescription) {
            XCTAssertFalse(message?.isEmpty ?? true)
        }
    }

    // MARK: Rendering and shortcuts

    func testBackdropPaddingIsClampedToSupportedRange() {
        let size = NSSize(width: 400, height: 200)
        XCTAssertEqual(ImageRenderer.padding(for: size, settings: BackdropSettings(padding: 10)), 20)
        XCTAssertEqual(ImageRenderer.padding(for: size, settings: BackdropSettings(padding: 80)), 50)
        XCTAssertEqual(ImageRenderer.padding(for: size, settings: BackdropSettings(padding: -5)), 0)
        XCTAssertEqual(ImageRenderer.padding(for: NSSize(width: 100, height: 100), settings: nil), 24)
        let unpadded = ImageRenderer.bitmap(ImageRenderer.render(solidImage(), marks: [], background: true, settings: BackdropSettings(padding: 0)))
        XCTAssertEqual(unpadded?.pixelsWide, 120); XCTAssertEqual(unpadded?.pixelsHigh, 80)
    }

    func testShortcutPresentationAndValidationEdgeCases() {
        let defaults = ShortcutBinding.defaults
        XCTAssertEqual(defaults.map(\.title), ["Capture area", "Capture screen", "Start / stop recording", "Scroll & Capture", "Finish scrolling capture"])
        XCTAssertEqual(defaults[4].label, "⌃⇧⌘Return")
        XCTAssertEqual(defaults[0].eventModifiers, [.control, .shift, .command])
        var disabled = defaults[0]; disabled.enabled = false
        XCTAssertEqual(disabled.label, "Off")
        var unknown = defaults[0]; unknown.keyCode = 999
        XCTAssertEqual(unknown.key, "?"); XCTAssertEqual(unknown.menuKey, "")
        XCTAssertNotNil(ShortcutBinding.validationError(Array(defaults.prefix(4))), "Every action must be configured")
        XCTAssertNotNil(ShortcutBinding.validationError(defaults + [defaults[0]]), "Duplicate action IDs must be rejected")
        var forwardDelete = defaults; forwardDelete[0].keyCode = 117; forwardDelete[0].modifiers = 0
        XCTAssertNotNil(ShortcutBinding.validationError(forwardDelete), "Forward Delete is not a function key")
    }
}
