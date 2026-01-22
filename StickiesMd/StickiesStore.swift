import Foundation
import Combine

class StickiesStore: ObservableObject {
    static let shared = StickiesStore()
    private let key = "StickyNotes"
    
    @Published var notes: [StickyNote] = []
    
    init() {
        load()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StickyNote].self, from: data) {
            self.notes = decoded
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
}
