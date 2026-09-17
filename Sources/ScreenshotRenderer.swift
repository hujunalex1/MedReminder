import Cocoa
import SwiftUI

enum ScreenshotRenderer {
    @MainActor
    static func renderAll() {
        print("📸 Generating high-res Retina screenshots via NSWindow...")
        let fm = FileManager.default
        let outDir = URL(fileURLWithPath: "docs/images")
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        let store = MedicationStore()
        let med1 = Medication(
            name: "阿莫西林胶囊",
            dosage: "500mg (1粒)",
            times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
            frequency: .daily,
            notes: "饭后温水送服"
        )
        let med2 = Medication(
            name: "维生素 C 泡腾片",
            dosage: "1片",
            times: [TimeOfDay(hour: 12, minute: 30)],
            frequency: .daily,
            notes: "温水溶解后饮用"
        )
        let med3 = Medication(
            name: "褪黑素软胶囊",
            dosage: "3mg (半片)",
            times: [TimeOfDay(hour: 22, minute: 30)],
            frequency: .daily,
            notes: "睡前半小时服用"
        )

        store.medications = [med1, med2, med3]
        store.records = [
            DoseRecord(medicationId: med1.id, scheduledTime: med1.times[0].dateToday(), status: .taken)
        ]

        // 1. Today View
        let todayView = ContentView()
            .environment(store)

        renderWindow(view: todayView, to: outDir.appendingPathComponent("preview_today.png"))

        // 2. Add View
        let addView = AddMedicationView(editing: nil, onDone: {})
            .environment(store)

        renderWindow(view: addView, to: outDir.appendingPathComponent("preview_add.png"))

        // 3. Manage View
        let manageView = AllMedicationsView(onBack: {}, onEdit: { _ in })
            .environment(store)

        renderWindow(view: manageView, to: outDir.appendingPathComponent("preview_manage.png"))

        print("🎉 Screenshots successfully generated in docs/images/")
    }

    @MainActor
    private static func renderWindow<V: View>(view: V, to fileURL: URL) {
        let size = NSSize(width: 360, height: 500)
        let hostingView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hostingView.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hostingView
        window.layoutIfNeeded()
        window.displayIfNeeded()

        // Wait a runloop pass for SwiftUI layout to settle
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("⚠️ Failed to get bitmap rep for \(fileURL.lastPathComponent)")
            return
        }
        rep.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
            try? png.write(to: fileURL)
            print("✅ Generated \(fileURL.lastPathComponent) (\(png.count) bytes)")
        }
    }
}
