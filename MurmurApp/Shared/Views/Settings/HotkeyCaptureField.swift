#if os(macOS)
import AppKit
import SwiftUI
import MurmurKit

/// A read-only field that displays the current hotkey. Clicking it enters
/// capture mode: the next keyDown with at least one modifier is converted
/// to a `HotkeySpec` and written back through the binding.
struct HotkeyCaptureField: View {
    @Binding var hotkeyString: String
    @State private var capturing = false

    var body: some View {
        Button {
            capturing.toggle()
        } label: {
            HStack {
                Text(capturing ? "Press a key combination…" : displayText)
                    .foregroundStyle(capturing ? .secondary : .primary)
                Spacer()
                if capturing {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 1)
            .background(Color.settingsSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.s))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.s)
                    .strokeBorder(capturing ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .background(KeyCaptureMonitor(active: $capturing, onCapture: handleCapture))
    }

    private var displayText: String {
        HotkeySpec.parse(hotkeyString)?.displayString
            ?? (hotkeyString.isEmpty ? "Not set" : hotkeyString)
    }

    private func handleCapture(spec: HotkeySpec) {
        hotkeyString = spec.displayString
        capturing = false
    }
}

/// Installs / removes a local NSEvent monitor while `active == true`.
private struct KeyCaptureMonitor: NSViewRepresentable {
    @Binding var active: Bool
    let onCapture: (HotkeySpec) -> Void

    final class Coordinator {
        var monitor: Any?
        var onCapture: ((HotkeySpec) -> Void)?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onCapture = onCapture
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCapture = onCapture
        let coordinator = context.coordinator
        if active && coordinator.monitor == nil {
            coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if let spec = makeSpec(from: event) {
                    coordinator.onCapture?(spec)
                    return nil // swallow event
                }
                return event
            }
        } else if !active, let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    private func makeSpec(from event: NSEvent) -> HotkeySpec? {
        var mods = HotkeySpec.Modifiers()
        let flags = event.modifierFlags
        if flags.contains(.control) { mods.insert(.control) }
        if flags.contains(.option)  { mods.insert(.option) }
        if flags.contains(.shift)   { mods.insert(.shift) }
        if flags.contains(.command) { mods.insert(.command) }
        guard !mods.isEmpty else { return nil }

        var parts: [String] = []
        if mods.contains(.control) { parts.append("Ctrl") }
        if mods.contains(.option)  { parts.append("Alt") }
        if mods.contains(.shift)   { parts.append("Shift") }
        if mods.contains(.command) { parts.append("Cmd") }
        let keyToken = displayName(for: event)
        parts.append(keyToken)
        return HotkeySpec.parse(parts.joined(separator: "+"))
    }

    private func displayName(for event: NSEvent) -> String {
        // Prefer the unmodified character (Cmd+Shift+a → "a", not "A"), and
        // fall back to a key-code lookup for non-printable keys.
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty, chars != " " {
            let trimmed = chars.trimmingCharacters(in: .controlCharacters)
            if !trimmed.isEmpty { return trimmed }
        }
        return Self.keyCodeName(event.keyCode) ?? "?"
    }

    private static func keyCodeName(_ code: UInt16) -> String? {
        switch code {
        case 49:  return "Space"
        case 48:  return "Tab"
        case 36:  return "Return"
        case 53:  return "Esc"
        case 51:  return "Backspace"
        case 117: return "Delete"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 50:  return "`"
        default:  return nil
        }
    }
}
#endif
