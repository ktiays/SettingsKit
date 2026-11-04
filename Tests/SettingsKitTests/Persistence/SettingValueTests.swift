import Foundation
import Testing
@testable import SettingsKit

enum TestColorScheme: String, SettingValue {
    case automatic
    case light
    case dark
}

struct TestEditorPreferences: CodableSettingValue, Equatable {
    var showsLineNumbers = true
    var tabWidth = 4
}

@Suite("Setting Values")
struct SettingValueTests {
    @Test func convertsPrimitiveValues() {
        #expect(true.settingRepresentation == .bool(true))
        #expect(42.settingRepresentation == .integer(42))
        #expect(1.5.settingRepresentation == .double(1.5))
        #expect("Text".settingRepresentation == .string("Text"))
        #expect(Data([1, 2]).settingRepresentation == .data(Data([1, 2])))
        #expect(Float(settingRepresentation: .double(2.5)) == 2.5)
    }

    @Test func toleratesCompatibleNumericRepresentations() {
        #expect(Bool(settingRepresentation: .integer(1)) == true)
        #expect(Bool(settingRepresentation: .integer(2)) == nil)
        #expect(Int(settingRepresentation: .double(3)) == 3)
        #expect(Int(settingRepresentation: .double(3.5)) == nil)
        #expect(Double(settingRepresentation: .integer(7)) == 7)
        #expect(String(settingRepresentation: .integer(7)) == nil)
    }

    @Test func roundTripsDatesAndURLs() throws {
        let date = Date(timeIntervalSinceReferenceDate: 123.25)
        #expect(try Date(settingRepresentation: #require(date.settingRepresentation)) == date)
        let url = URL(filePath: "/tmp/Settings Example")
        #expect(try URL(settingRepresentation: #require(url.settingRepresentation)) == url)
    }

    @Test func persistsRawRepresentableValuesByRawValue() throws {
        #expect(try TestColorScheme.dark.settingRepresentation == .string("dark"))
        #expect(TestColorScheme(settingRepresentation: .string("light")) == .light)
        #expect(TestColorScheme(settingRepresentation: .string("sepia")) == nil)
    }

    @Test func persistsCodableValuesAsJSON() throws {
        let preferences = TestEditorPreferences(showsLineNumbers: false, tabWidth: 2)
        let representation = try #require(try preferences.settingRepresentation)
        #expect(representation == .string(#"{"showsLineNumbers":false,"tabWidth":2}"#))
        #expect(TestEditorPreferences(settingRepresentation: representation) == preferences)
        #expect(TestEditorPreferences(settingRepresentation: .string("{")) == nil)
        #expect([String](settingRepresentation: .string(#"["a","b"]"#)) == ["a", "b"])
    }

    @Test func representsOptionalNoneAsAbsence() throws {
        let none: Int? = nil
        #expect(try none.settingRepresentation == nil)
        #expect(try Int?.some(5).settingRepresentation == .integer(5))
        #expect(Int?(settingRepresentation: .integer(5)) == .some(.some(5)))
        #expect(Int?(settingRepresentation: .string("5")) == nil)
    }
}
