import Foundation
import Testing
@testable import MurmurKit

@Suite("HotkeySpec parser")
struct HotkeySpecTests {
    @Test("Parses the default Ctrl+backtick")
    func parsesDefaultCtrlBacktick() throws {
        let spec = try #require(HotkeySpec.parse("Ctrl+`"))
        #expect(spec.modifiers == .control)
        #expect(spec.keyCode == 50)
        #expect(spec.displayString == "Ctrl+`")
    }

    @Test("Modifier names are case-insensitive and accept aliases")
    func modifierAliases() throws {
        let cases = ["control+space", "CTRL+space", "Ctrl+Space"]
        for raw in cases {
            let spec = try #require(HotkeySpec.parse(raw))
            #expect(spec.modifiers == .control)
            #expect(spec.keyCode == 49)
        }
    }

    @Test("Cmd/Command/Meta/Super all map to command")
    func commandAliases() throws {
        for alias in ["Cmd", "Command", "Meta", "Super"] {
            let spec = try #require(HotkeySpec.parse("\(alias)+A"))
            #expect(spec.modifiers == .command)
            #expect(spec.keyCode == 0)
        }
    }

    @Test("Alt/Option/Opt all map to option")
    func optionAliases() throws {
        for alias in ["Alt", "Option", "Opt"] {
            let spec = try #require(HotkeySpec.parse("\(alias)+F1"))
            #expect(spec.modifiers == .option)
            #expect(spec.keyCode == 122)
        }
    }

    @Test("Multiple modifiers combine")
    func multipleModifiers() throws {
        let spec = try #require(HotkeySpec.parse("Cmd+Shift+Space"))
        #expect(spec.modifiers == [.command, .shift])
        #expect(spec.keyCode == 49)
    }

    @Test("Canonical display string normalises modifier order")
    func displayStringCanonicalOrder() throws {
        let spec = try #require(HotkeySpec.parse("Shift+Ctrl+Cmd+T"))
        #expect(spec.displayString == "Ctrl+Shift+Cmd+T")
    }

    @Test("Function keys are recognised")
    func functionKeys() throws {
        let spec = try #require(HotkeySpec.parse("Cmd+F12"))
        #expect(spec.keyCode == 111)
    }

    @Test("Arrow keys are recognised")
    func arrowKeys() throws {
        let spec = try #require(HotkeySpec.parse("Cmd+Up"))
        #expect(spec.keyCode == 126)
    }

    @Test("Rejects empty string")
    func rejectsEmpty() {
        #expect(HotkeySpec.parse("") == nil)
    }

    @Test("Rejects strings with no modifier")
    func rejectsNoModifier() {
        #expect(HotkeySpec.parse("Space") == nil)
        #expect(HotkeySpec.parse("F1") == nil)
    }

    @Test("Rejects unknown modifier")
    func rejectsUnknownModifier() {
        #expect(HotkeySpec.parse("Hyper+A") == nil)
    }

    @Test("Rejects unknown key")
    func rejectsUnknownKey() {
        #expect(HotkeySpec.parse("Ctrl+NotARealKey") == nil)
    }

    @Test("Rejects duplicate modifier")
    func rejectsDuplicateModifier() {
        #expect(HotkeySpec.parse("Ctrl+Ctrl+A") == nil)
    }

    @Test("Rejects trailing or leading plus")
    func rejectsMalformedSeparators() {
        #expect(HotkeySpec.parse("Ctrl+") == nil)
        #expect(HotkeySpec.parse("+A") == nil)
        #expect(HotkeySpec.parse("Ctrl++A") == nil)
    }

    @Test("Whitespace around tokens is tolerated")
    func tolerantOfWhitespace() throws {
        let spec = try #require(HotkeySpec.parse("  Ctrl  +   Space  "))
        #expect(spec.modifiers == .control)
        #expect(spec.keyCode == 49)
    }

    @Test("Punctuation keys map correctly")
    func punctuationKeys() throws {
        #expect(try #require(HotkeySpec.parse("Ctrl+;")).keyCode == 41)
        #expect(try #require(HotkeySpec.parse("Ctrl+,")).keyCode == 43)
        #expect(try #require(HotkeySpec.parse("Ctrl+.")).keyCode == 47)
        #expect(try #require(HotkeySpec.parse("Ctrl+/")).keyCode == 44)
    }
}
