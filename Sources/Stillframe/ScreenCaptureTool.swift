import Foundation
import CoreGraphics

/// The interactive screenshot modes offered by the capture bar, menus and shortcuts.
enum CaptureMode: String, CaseIterable {
    case area, window, screen

    var itemTitle: String {
        switch self {
        case .area: return "Area capture"
        case .window: return "Window capture"
        case .screen: return "Fullscreen capture"
        }
    }
}

/// Builds arguments for, and runs, macOS `/usr/sbin/screencapture`.
/// Argument construction is pure so it can be unit tested without screen permissions.
enum ScreenCaptureTool {
    static let executable = URL(fileURLWithPath: "/usr/sbin/screencapture")

    /// `-R` takes global display coordinates with a top-left origin, in points.
    static func regionArgument(_ rect: CGRect) -> String {
        "-R\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"
    }

    static func arguments(mode: CaptureMode, region: CGRect?, includeCursor: Bool, windowShadow: Bool, output: URL) -> [String] {
        var args = ["-x", "-t", "png"]
        if mode == .area, let region { args.append(regionArgument(region)) }
        else if mode == .window { args += ["-i", "-w"] }
        else { args.append("-m") }
        if mode == .screen, includeCursor { args.append("-C") }
        if mode == .window, !windowShadow { args.append("-o") }
        args.append(output.path)
        return args
    }

    /// Silent capture of a fixed region, used for each scrolling-capture frame.
    static func regionCaptureArguments(_ region: CGRect, output: URL) -> [String] {
        ["-x", regionArgument(region), output.path]
    }

    /// Runs the tool and returns its exit status without blocking the caller's executor.
    static func run(_ arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        // Diagnostics are not used; discarding them avoids a full, unread pipe stalling the tool.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

enum AppLinks {
    static let screenRecordingPrivacy = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}

extension Notification.Name {
    static let stillframeShowSettings = Notification.Name("StillframeSettings")
}
