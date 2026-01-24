import Foundation
import Combine

class StickiesStore: ObservableObject {
    static let shared = StickiesStore()
    private let key = "StickyNotes"
    
    var defaults: UserDefaults = .standard
    // Default to Documents/StickiesMd, but customizable for tests
    var storageDirectory: URL = {
        let fileManager = FileManager.default
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents.appendingPathComponent("StickiesMd")
        }
        return fileManager.temporaryDirectory // Fallback
    }()
    
    @Published var notes: [StickyNote] = []
    
    init() {
        // Load will be called manually or explicitly if needed, 
        // but for singleton it's called immediately. 
        // We might want to reload after configuring for tests.
    }
    
    func configure(defaults: UserDefaults, storageDirectory: URL) {
        self.defaults = defaults
        self.storageDirectory = storageDirectory
        // Reload notes from the new source
        load()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(notes) {
            defaults.set(encoded, forKey: key)
        }
    }
    
    func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StickyNote].self, from: data) {
            self.notes = decoded
        } else {
            self.notes = []
        }
    }
    
    func add(note: StickyNote) {
        notes.append(note)
        save()
    }
    
    func update(note: StickyNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            save()
        }
    }
    
    func remove(note: StickyNote) {
        notes.removeAll(where: { $0.id == note.id })
        save()
    }
    
    func reset() {
        notes = []
        defaults.removeObject(forKey: key)
        // Also cleanup files in storageDirectory if needed, for now just UserDefaults
        // For UI tests, we might want to clean the directory too.
        try? FileManager.default.removeItem(at: storageDirectory)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
}
