import AppKit
import SwiftUI

struct MenuShot: View {
    let active: Bool
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: active ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.4))
                Text(status).font(.headline)
            }
            Divider()
            if active {
                Label("Stop", systemImage: "stop.fill")
                    .foregroundStyle(.red)
            } else {
                Label("1 minute", systemImage: "timer")
                Label("5 minutes", systemImage: "timer")
                Label("10 minutes", systemImage: "timer")
                Label("Forever", systemImage: "timer")
            }
            Divider()
            Text("Settings")
            Text("Quit")
        }
        .font(.system(size: 14))
        .padding(16)
        .frame(width: 270)
        .background(.regularMaterial)
    }
}

struct SettingsShot: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title2.bold())
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Schedule Mode", systemImage: "clock")
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.4))
                Toggle("Enable schedule", isOn: .constant(true))
                HStack {
                    Text("Active hours:")
                    Text("09:00")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Text("to")
                    Text("17:00")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                }
                Label("Schedule active now", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("App Aware Mode", systemImage: "apple.intelligence")
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.4))
                Text("Select from running apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    HStack { Text("Safari"); Spacer(); Text("Add").padding(.horizontal, 10).padding(.vertical, 4).background(Color.gray.opacity(0.15), in: Capsule()) }
                    HStack { Text("Xcode"); Spacer(); Text("Remove").padding(.horizontal, 10).padding(.vertical, 4).background(Color.red.opacity(0.15), in: Capsule()) }
                    HStack { Text("Terminal"); Spacer(); Text("Add").padding(.horizontal, 10).padding(.vertical, 4).background(Color.gray.opacity(0.15), in: Capsule()) }
                }
                .padding(10)
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            Spacer(minLength: 4)

            HStack {
                Spacer()
                Text("Save")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.4, green: 0.6, blue: 0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .frame(width: 700, height: 520)
        .background(.regularMaterial)
    }
}

@MainActor
func saveView<V: View>(_ view: V, to path: String, scale: CGFloat = 2.0) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale

    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to render image for \(path)\n", stderr)
        exit(1)
    }

    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path)")
    } catch {
        fputs("Failed to write \(path): \(error)\n", stderr)
        exit(1)
    }
}

let fm = FileManager.default
let outDir = "docs/screenshots"
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

Task { @MainActor in
    saveView(MenuShot(active: false, status: "Inactive"), to: "\(outDir)/menu.png")
    saveView(SettingsShot(), to: "\(outDir)/settings.png")
    saveView(MenuShot(active: true, status: "4:59"), to: "\(outDir)/active-state.png")
    NSApplication.shared.terminate(nil)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.run()
