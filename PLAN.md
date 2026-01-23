# **Stickies.md Project Specification**

## **1. Product Overview**

Stickies.md is a file-linked sticky note application that combines the lightness of macOS's standard "Stickies" with the advanced document creation capabilities of Markdown and Org-mode.

### **Vision**

"Keep fragments of thought edited in Emacs or VS Code always by your side as beautiful sticky notes on your desktop."

## **2. Core Functional Requirements**

1. **Native macOS Implementation**: Lightweight and fast operation using Swift/SwiftUI.
2. **Stickies UI and Customization**:
   * **Minimal Title Bar**: Minimal area for window operations, allowing changes to color and transparency.
   * Always on Top (Floating Window).
   * **Per-Window Appearance Settings**: Background color (theme color) and opacity can be set individually for each sticky note.
     * **Title Bar Controls**: Color can be changed via icons on the title bar, and opacity can be adjusted via buttons.
   * **Initial Value Randomization**: When opening a new file, a color is randomly selected from a classic stickies palette.
   * **Menu Operations**: New files can be opened from the application menu.
   * **Mouse-through Mode (Low Priority)**: An overlay setting that allows clicks to pass through to windows behind.
3. **Multi-format Support**: Parsing and rendering of Markdown and Org-mode.
   * **Direct Editing**: Text can be edited directly on the sticky note and saved as a Markdown/Org file.
4. **Full File Linking and Persistence**:
   * One-to-one correspondence with local .md or .org files.
   * Detect changes in external editors (Emacs, etc.) and reflect them immediately (Hot Reload).
   * **Save Appearance Settings**: Save the association between file paths and settings (color, opacity, window frame) to restore the same appearance on the next launch.
5. **Rich Content and Interactivity**:
   * Inline image display ([[path/to/img]] or ![]()).
   * **Image Drag & Drop (D&D)**: Automatically save files and insert links when images are dragged and dropped onto a sticky note window.
   * **Customizable Image Storage**: Directory for saving attached images can be set via relative or absolute paths.
   * Highlight TODO status.

## **3. System Architecture**

The project adopts a Monorepo format, configured with future iOS expansion in mind.

### **Project Structure**

* **StickiesMd (App)**: macOS application layer. Responsible for window management, file monitoring, UI rendering, user interface (settings screen, etc.), and **Persistence of appearance settings**.
* **OrgKit (Swift Package)**: Core library with separated parsing logic.

### **Persistence Strategy**

* Use `UserDefaults` to store a dictionary where the key is the absolute path of the file URL, and the value is a struct (JSON) containing:
  * backgroundColor: Hex String
  * opacity: Double
  * windowFrame: NSRect (String representation)

## **4. OrgKit Detailed Specification**

Build a simple and highly extensible interface, referencing the API design of swiftlang/swift-markdown.

### **API Design**

```swift
// Usage example
let parser = OrgParser()
let document = parser.parse(parsing: content)

// Visitor pattern similar to swift-markdown
struct MyRenderer: OrgVisitor {
    func visitHeading(_ heading: Heading) {
        // Handle heading
    }

    func visitParagraph(_ paragraph: Paragraph) {
        // Handle paragraph
    }
}

var renderer = MyRenderer()
renderer.visit(document)
```

### **Abstract Syntax Tree (AST) Definition Proposal**

Based on the `OrgNode` protocol, holding Block elements and Inline elements hierarchically.

* **Block Nodes**: Document, Heading, Paragraph, List, CodeBlock, Drawer, HorizontalRule
* **Inline Nodes**: Text, Strong, Emphasis, Link, Image

## **5. Implementation Roadmap**

### **Phase 1: Infrastructure**

* [ ] **Window Customization**: Use `NSPanel` (subclass of `NSWindow`). Implement title bar hiding and transparent backgrounds.
* [ ] **File Watcher**: Monitor specific files using `NSFilePresenter`.
* [ ] **Persistence**: Implement `StickiesStore` class. Save/load settings via `UserDefaults`.
* [ ] **Library Link**: Make `OrgKit` accessible from the App target.

### **Phase 2: OrgKit Development (Parser)**

* [ ] **Lexer/Scanner**: Tokenize on a per-line basis.
* [ ] **Node Types**: Define elements constituting the AST.
* [ ] **TDD Implementation**: Incremental implementation using Swift Testing.

### **Phase 3: Rendering & Interaction**

* [ ] **View Mapping**: Implement SwiftUI components corresponding to each `OrgNode`.
* [ ] **Drag & Drop**: Handle image acceptance and saving via `FileManager`.
* [ ] **Menu Operations**: Implement functionality to open files from the menu bar.
* [ ] **Appearance UI**: Implement color change and opacity adjustment buttons on the title bar.
* [ ] **Rich Rendering**: Implement rich rendering (syntax highlighting, styling) to improve visibility of Markdown and Org-mode.

### **Phase 4: UX Enhancement**

* [ ] **Mouse-through Mode**: Click-through functionality under specific conditions (modifier keys, etc.).
* [ ] **App Sandbox & Security**: Handle file access rights considering security restrictions.

### **Phase 5: Per-Window Appearance Settings**

* [x] **Window Configuration**: Add an icon to the title bar to open a window settings screen, allowing configuration of color, opacity, and file.

### **Phase 6: Content Editing**

* [x] **Editing**: Enable actual text input when the window is focused.

## **6. Technical Challenges and Investment Value**

* **Org-mode implementation in Pure Swift**: Increase reusability within the Apple ecosystem.
* **iOS Expansion**: Develop iOS apps/widgets at minimum cost using the same `OrgKit`.

## **7. Implementation and Development Policy**

### **7.1. Language Standard**

* **Code & Documentation**: All identifiers, comments, and documentation must be in **English**.

### **7.2. Automated Testing (CI)**

* **GitHub Actions**: Automatically run `swift test` on macOS runners upon Push/PR.

### **7.3. Test-Driven Development (TDD)**

* **Workflow**: Write tests first (Red), then proceed with implementation (Green).

## **8. Technical Deep Dives**

### **8.1. Window Behavior**

* level = .floating: Always on top.
* isMovableByWindowBackground = true: Move by dragging the background.
* styleMask.insert(.nonactivatingPanel): Operable without taking focus.

### **8.2. File Synchronization**

Adopt `NSFilePresenter` to detect changes while preventing conflicts with external editors.

### **8.3. Initial Color Palette (Sticky Classics)**

Adopt the following 6 colors as the default random rotation set:

1. **Yellow**: #FFF9C4 (Classic Sticky Yellow)
2. **Blue**: #E1F5FE
3. **Green**: #F1F8E9
4. **Pink**: #FCE4EC
5. **Purple**: #F3E5F5
6. **Gray**: #F5F5F5

### **8.4. Initial Opacity**
The initial value for opacity is 1, meaning non-transparent.