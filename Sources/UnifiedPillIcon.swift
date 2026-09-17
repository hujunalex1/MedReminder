import SwiftUI
import AppKit

/// Unified App Icon Image Provider for all app surfaces
enum AppIconImage {
    static let menuBar: NSImage = {
        if let path = Bundle.main.path(forResource: "menu_icon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        return NSImage(systemSymbolName: "pill.fill", accessibilityDescription: nil) ?? NSImage()
    }()

    static let row: NSImage = {
        if let path = Bundle.main.path(forResource: "row_icon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        return NSImage(systemSymbolName: "pill.fill", accessibilityDescription: nil) ?? NSImage()
    }()

    static let empty: NSImage = {
        if let path = Bundle.main.path(forResource: "empty_icon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        return NSImage(systemSymbolName: "pills", accessibilityDescription: nil) ?? NSImage()
    }()
}

/// Unified Pill Icon View for medication rows and detail views
struct UnifiedPillIcon: View {
    var size: CGFloat = 26
    var cornerRadius: CGFloat = 6

    var body: some View {
        Image(nsImage: AppIconImage.row)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
