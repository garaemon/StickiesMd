import Foundation
import Combine
import OrgKit

class StickyNoteViewModel: NSObject, ObservableObject, NSFilePresenter {
    @Published var note: StickyNote
    @Published var content: String = ""
    @Published var document: OrgDocument = OrgDocument(children: [])
    
    var presentedItemURL: URL? {
        return note.fileURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    init(note: StickyNote) {
        self.note = note
        super.init()
        loadContent()
        NSFileCoordinator.addFilePresenter(self)
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    func loadContent() {
        do {
            let data = try Data(contentsOf: note.fileURL)
            if let text = String(data: data, encoding: .utf8) {
                self.content = text
                self.document = OrgParser().parse(text)
            }
        } catch {
            print("Failed to load content: \(error)")
        }
    }
    
    func presentedItemDidChange() {
        loadContent()
    }
}
