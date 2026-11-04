import Foundation
import Observation
import Synchronization
import Testing
@testable import SettingsKit

extension SettingKey where Value == Bool {
    static var testShowsLineNumbers: Self {
        Self("test.showsLineNumbers", defaultValue: true)
    }
}

extension SettingKey where Value == Int {
    static var testTabWidth: Self {
        Self("test.tabWidth", defaultValue: 4)
    }
}

extension SettingKey where Value == TestColorScheme {
    static var testColorScheme: Self {
        Self("test.colorScheme", defaultValue: .automatic)
    }
}

extension SettingKey where Value == String? {
    static var testFontName: Self {
        Self("test.fontName")
    }
}

extension SettingKey where Value == TestEditorPreferences {
    static var testEditor: Self {
        Self("test.editor", defaultValue: TestEditorPreferences())
    }
}

/// A minimal custom backend that relies on the default change observation.
private final class DictionarySettingsStorage: SettingsStorage {
    let values = Mutex<[String: SettingRepresentation]>([:])

    func value(forKey key: String) -> SettingRepresentation? {
        values.withLock {
            $0[key]
        }
    }

    func setValue(_ value: SettingRepresentation, forKey key: String) {
        values.withLock {
            $0[key] = value
        }
    }

    func removeValue(forKey key: String) {
        values.withLock {
            $0[key] = nil
        }
    }
}

private struct FailingSettingsStorage: SettingsStorage {
    struct WriteError: Error {
    }

    func value(forKey key: String) -> SettingRepresentation? {
        nil
    }

    func setValue(_ value: SettingRepresentation, forKey key: String) throws {
        throw WriteError()
    }

    func removeValue(forKey key: String) throws {
        throw WriteError()
    }
}

/// A backend whose persisted value cannot be read until it is replaced or removed.
private final class UnreadableSettingsStorage: SettingsStorage {
    struct ReadError: Error {
    }

    let values = Mutex<[String: SettingRepresentation]>([:])
    let unreadableKeys: Mutex<Set<String>>
    let failsWrites: Bool

    init(unreadableKeys: Set<String>, failsWrites: Bool = false) {
        self.unreadableKeys = Mutex(unreadableKeys)
        self.failsWrites = failsWrites
    }

    func value(forKey key: String) throws -> SettingRepresentation? {
        if unreadableKeys.withLock({ $0.contains(key) }) {
            throw ReadError()
        }
        return values.withLock {
            $0[key]
        }
    }

    func setValue(_ value: SettingRepresentation, forKey key: String) throws {
        if failsWrites {
            throw FailingSettingsStorage.WriteError()
        }
        unreadableKeys.withLock {
            _ = $0.remove(key)
        }
        values.withLock {
            $0[key] = value
        }
    }

    func removeValue(forKey key: String) throws {
        if failsWrites {
            throw FailingSettingsStorage.WriteError()
        }
        unreadableKeys.withLock {
            _ = $0.remove(key)
        }
        values.withLock {
            $0[key] = nil
        }
    }
}

/// Records whether an observation-tracked read was invalidated.
private final class ChangeFlag: Sendable {
    private let state = Mutex(false)

    var isSet: Bool {
        state.withLock {
            $0
        }
    }

    func set() {
        state.withLock {
            $0 = true
        }
    }
}

private func tracking(_ read: () -> Void) -> ChangeFlag {
    let flag = ChangeFlag()
    withObservationTracking(read) {
        flag.set()
    }
    return flag
}

@Suite("Settings Store")
struct SettingsStoreTests {
    @Test func readsDefaultsAndPersistsValues() throws {
        let storage = InMemorySettingsStorage()
        let store = SettingsStore(storage: storage)
        #expect(store[.testShowsLineNumbers] == true)
        #expect(store[.testColorScheme] == .automatic)

        store[.testShowsLineNumbers] = false
        store[.testColorScheme] = .dark
        #expect(store[.testShowsLineNumbers] == false)
        #expect(storage.value(forKey: "test.showsLineNumbers") == .bool(false))
        #expect(storage.value(forKey: "test.colorScheme") == .string("dark"))

        try store.resetValue(for: .testColorScheme)
        #expect(store[.testColorScheme] == .automatic)
        #expect(storage.value(forKey: "test.colorScheme") == nil)
    }

    @Test func readsDefaultValueForInvalidRepresentation() {
        let storage = InMemorySettingsStorage(values: ["test.tabWidth": .string("wide")])
        let store = SettingsStore(storage: storage)
        #expect(store[.testTabWidth] == 4)
    }

    @Test func removesOptionalValuesAssignedNil() {
        let storage = InMemorySettingsStorage()
        let store = SettingsStore(storage: storage)
        #expect(store[.testFontName] == nil)
        store[.testFontName] = "Menlo"
        #expect(storage.value(forKey: "test.fontName") == .string("Menlo"))
        store[.testFontName] = nil
        #expect(storage.value(forKey: "test.fontName") == nil)
    }

    @Test func bindsPropertiesOfCodableModels() {
        let store = SettingsStore(storage: InMemorySettingsStorage())
        let binding = store.binding(for: .testEditor)
        binding.tabWidth.wrappedValue = 8
        #expect(store[.testEditor] == TestEditorPreferences(showsLineNumbers: true, tabWidth: 8))
    }

    @Test func tracksObservationPerKey() {
        let store = SettingsStore(storage: InMemorySettingsStorage())
        let showsLineNumbersChanged = tracking {
            _ = store[.testShowsLineNumbers]
        }
        let tabWidthChanged = tracking {
            _ = store[.testTabWidth]
        }
        store[.testShowsLineNumbers] = false
        #expect(showsLineNumbersChanged.isSet)
        #expect(!tabWidthChanged.isSet)
    }

    @Test func doesNotNotifyObserversForUnchangedValues() {
        let store = SettingsStore(storage: InMemorySettingsStorage())
        store[.testTabWidth] = 2
        let changed = tracking {
            _ = store[.testTabWidth]
        }
        store[.testTabWidth] = 2
        #expect(!changed.isSet)
    }

    @Test func observesChangesFromStoresSharingStorage() {
        let storage = InMemorySettingsStorage()
        let first = SettingsStore(storage: storage)
        let second = SettingsStore(storage: storage)
        #expect(second[.testTabWidth] == 4)
        let changed = tracking {
            _ = second[.testTabWidth]
        }
        first[.testTabWidth] = 2
        #expect(changed.isSet)
        #expect(second[.testTabWidth] == 2)
    }

    @Test func supportsCustomStorageWithoutChangeObservation() {
        let storage = DictionarySettingsStorage()
        let store = SettingsStore(storage: storage)
        store[.testTabWidth] = 3
        #expect(store[.testTabWidth] == 3)
        #expect(storage.value(forKey: "test.tabWidth") == .integer(3))
    }

    @Test func retainsPreviousValueWhenWriteFails() {
        let store = SettingsStore(storage: FailingSettingsStorage())
        #expect(throws: FailingSettingsStorage.WriteError.self) {
            try store.setValue(8, for: .testTabWidth)
        }
        #expect(store[.testTabWidth] == 4)
    }

    @Test func replacesAndRemovesUnreadableValues() throws {
        let storage = UnreadableSettingsStorage(unreadableKeys: ["test.tabWidth", "test.showsLineNumbers"])
        let store = SettingsStore(storage: storage)
        #expect(throws: UnreadableSettingsStorage.ReadError.self) {
            try store.value(for: .testTabWidth)
        }
        let flag = tracking {
            _ = store[.testTabWidth]
        }
        try store.setValue(8, for: .testTabWidth)
        #expect(flag.isSet)
        #expect(try store.value(for: .testTabWidth) == 8)

        try store.resetValue(for: .testShowsLineNumbers)
        #expect(try store.value(for: .testShowsLineNumbers) == true)
    }

    @Test func rereadsUnreadableValueAfterFailedWrite() {
        let storage = UnreadableSettingsStorage(unreadableKeys: ["test.tabWidth"], failsWrites: true)
        let store = SettingsStore(storage: storage)
        #expect(throws: FailingSettingsStorage.WriteError.self) {
            try store.setValue(8, for: .testTabWidth)
        }
        #expect(throws: UnreadableSettingsStorage.ReadError.self) {
            try store.value(for: .testTabWidth)
        }
    }
}
