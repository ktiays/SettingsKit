import Foundation
import Testing
@testable import SettingsKit

private let representativeValues: [String: SettingRepresentation] = [
    "bool": .bool(true),
    "integer": .integer(-42),
    "double": .double(3.25),
    "string": .string("Größe\u{0}Suffix"),
    "emptyString": .string(""),
    "data": .data(Data([0, 1, 255])),
    "emptyData": .data(Data()),
]

@Suite("SQLite Settings Storage")
struct SQLiteSettingsStorageTests {
    @Test func roundTripsEveryRepresentation() throws {
        let storage = try SQLiteSettingsStorage(location: .inMemory)
        for (key, value) in representativeValues {
            try storage.setValue(value, forKey: key)
        }
        for (key, value) in representativeValues {
            #expect(try storage.value(forKey: key) == value)
        }
        try storage.setValue(.integer(1), forKey: "bool")
        #expect(try storage.value(forKey: "bool") == .integer(1))
        try storage.removeValue(forKey: "bool")
        #expect(try storage.value(forKey: "bool") == nil)
    }

    @Test func persistsValuesAcrossConnections() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SettingsKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appending(path: "Nested/Settings.sqlite")
        do {
            let store = SettingsStore(storage: try SQLiteSettingsStorage(url: url, tableName: "preferences"))
            store[.testColorScheme] = .light
            store[.testEditor] = TestEditorPreferences(showsLineNumbers: false, tabWidth: 2)
        }
        let store = SettingsStore(storage: try SQLiteSettingsStorage(url: url, tableName: "preferences"))
        #expect(store[.testColorScheme] == .light)
        #expect(store[.testEditor] == TestEditorPreferences(showsLineNumbers: false, tabWidth: 2))
    }

    @Test func rejectsInvalidTableNames() {
        for name in ["", "1settings", "settings; DROP TABLE x", "set\"tings"] {
            #expect(throws: SQLiteSettingsStorageError.self) {
                try SQLiteSettingsStorage(location: .inMemory, tableName: name)
            }
        }
    }

    @Test func notifiesObserversOfChangedKeys() throws {
        let storage = try SQLiteSettingsStorage(location: .inMemory)
        let first = SettingsStore(storage: storage)
        let second = SettingsStore(storage: storage)
        #expect(second[.testShowsLineNumbers] == true)
        first[.testShowsLineNumbers] = false
        #expect(second[.testShowsLineNumbers] == false)
    }
}

@Suite("User Defaults Settings Storage", .serialized)
struct UserDefaultsSettingsStorageTests {
    private static func withSuite(_ body: (UserDefaults, UserDefaultsSettingsStorage) throws -> Void) throws {
        let suiteName = "SettingsKitTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        try body(defaults, UserDefaultsSettingsStorage(defaults: defaults, keyPrefix: "Settings."))
    }

    @Test func roundTripsEveryRepresentation() throws {
        try Self.withSuite { defaults, storage throws in
            for (key, value) in representativeValues {
                storage.setValue(value, forKey: key)
            }
            for (key, value) in representativeValues {
                #expect(try storage.value(forKey: key) == value)
            }
            #expect(defaults.object(forKey: "Settings.integer") as? Int == -42)
            storage.removeValue(forKey: "integer")
            #expect(try storage.value(forKey: "integer") == nil)
        }
    }

    @Test func readsValuesWrittenDirectlyToDefaults() throws {
        try Self.withSuite { defaults, storage throws in
            defaults.set(Date(timeIntervalSinceReferenceDate: 10), forKey: "Settings.date")
            defaults.set(["array"], forKey: "Settings.array")
            defaults.set(Float(1.5), forKey: "Settings.float")
            #expect(try storage.value(forKey: "date") == .double(10))
            #expect(try storage.value(forKey: "float") == .double(1.5))
            #expect(throws: SettingsStorageError.unsupportedValue(key: "array")) {
                try storage.value(forKey: "array")
            }
        }
    }

    @Test func refreshesStoreAfterExternalChanges() throws {
        try Self.withSuite { defaults, storage throws in
            let store = SettingsStore(storage: storage)
            #expect(store[.testTabWidth] == 4)
            defaults.set(6, forKey: "Settings.test.tabWidth")
            #expect(store[.testTabWidth] == 6)
        }
    }
}
