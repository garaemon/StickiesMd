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
   * **Per-Window Appearance Settings**: Background color (theme color), font color, and opacity can be set individually for each sticky note.
     * **Title Bar Controls**: Color can be changed via icons on the title bar, and opacity can be adjusted via buttons.
   * **Editor Customization**:
     * **Minimap**: Hidden by default.
     * **Line Numbers**: Toggleable visibility, saved per window.
     * **Heading Styles**: Headings should be displayed with larger font sizes for better structure visibility.
   * **Initial Value Randomization**: When opening a new file, a color is randomly selected from a classic stickies palette.
   * **Menu Operations**: New files can be opened from the application menu.
3. **Multi-format Support**: Parsing and rendering of Markdown and Org-mode.
   * **Direct Editing**: Text can be edited directly on the sticky note and saved as a Markdown/Org file.
4. **Full File Linking and Persistence**:
   * One-to-one correspondence with local .md or .org files.
   * Detect changes in external editors (Emacs, etc.) and reflect them immediately (Hot Reload).
   * **Save Appearance Settings**: Save the association between file paths and settings to restore the same appearance on the next launch.
     * **Stored Properties**:
       * `backgroundColor`: Hex String
       * `fontColor`: Hex String (New)
       * `opacity`: Double
       * `windowFrame`: NSRect (String representation)
       * `showLineNumbers`: Bool (New)
5. **Rich Content and Interactivity**:
   * Inline image display ([[path/to/img]] or ![]()).
   * **Image Drag & Drop (D&D)**: Automatically save files and insert links when images are dragged and dropped onto a sticky note window.
   * **Customizable Image Storage**: Directory for saving attached images can be set via relative or absolute paths.
   * Highlight TODO status.

## **3. System Architecture**

The project adopts a simple single-target structure, leveraging powerful native frameworks and libraries.

### **Project Structure**

* **StickiesMd (App)**: macOS application layer. Responsible for window management, file monitoring, UI rendering, user interface (settings screen, etc.), and **Persistence of appearance settings**.
  * **Editor Engine**: Uses **TextKit 2** for high-performance text rendering and editing, backed by **OrgKit** for parsing and syntax highlighting.
* **OrgKit (Package)**: A standalone Swift Package responsible for document parsing and structure analysis.
  * **Core**: Integrates **SwiftTreeSitter** to provide a unified interface for Markdown and Org-mode parsing.
  * **Functionality**: Provides structured data (AST nodes, styling ranges) to the app, decoupling the editor from specific Tree-sitter details.

### **Persistence Strategy**

* Use `UserDefaults` to store a dictionary where the key is the absolute path of the file URL, and the value is a struct (JSON) containing all per-window settings defined in Section 2.

## **4. Text Processing Strategy**

The app utilizes **SwiftTreeSitter** for robust parsing of Markdown and Org-mode files, and **TextKit 2** for high-performance rendering and editing.

* **Parsing**: Use **SwiftTreeSitter** to generate an Abstract Syntax Tree (AST) from the text. This allows for accurate detection of document structure (headers, lists, links, etc.) for both Markdown and Org-mode.
* **Rendering & Editing**: Use **TextKit 2** (`NSTextLayoutManager`, `NSTextContentStorage`, `NSTextViewportLayoutController`) to render the text. Syntax highlighting and rich text attributes (font size for headers, colors) are applied based on the AST provided by SwiftTreeSitter.

## **5. Implementation Roadmap**

### **Phase 1: Infrastructure**

* [x] **Window Customization**: Use `NSPanel` (subclass of `NSWindow`). Implement title bar hiding and transparent backgrounds.
* [x] **File Watcher**: Monitor specific files using `NSFilePresenter`.
* [x] **Persistence**: Implement `StickiesStore` class. Save/load settings via `UserDefaults`.

### **Phase 2: Core Text Editing (Transition to TextKit 2)**

* [ ] **Dependency Setup**: Add `SwiftTreeSitter` and relevant language grammars (Markdown, Org-mode) to the project.
* [ ] **TextKit 2 Integration**: Implement a custom text editor view using `NSTextLayoutManager`, `NSTextContentStorage`, and `NSTextView`.
* [ ] **Syntax Highlighting**: Implement a mechanism to query `SwiftTreeSitter` for syntax nodes and apply attributes to the `NSTextContentStorage`.
* [ ] **Org-mode Support**: Ensure proper parsing of Org-mode files using Tree-sitter.
* [ ] **Markdown Support**: Ensure proper parsing of Markdown files using Tree-sitter.

### **Phase 3: Interaction & Features**

* [x] **Drag & Drop**: Handle image acceptance and saving via `FileManager`.
* [x] **Menu Operations**: Implement functionality to open files from the menu bar.
* [x] **Appearance UI**: Implement color change and opacity adjustment buttons on the title bar.
* [x] **Window Configuration**: Per-window settings for color, opacity, and file association.
* [x] **Editor Cleanup**: 
  * [x] Remove Minimap (right-side mini editor).
  * [x] Implement toggle for Line Numbers.
* [x] **Styling**:
  * [x] Implement Per-window Font Color (UI & Persistence).
  * [ ] **Heading Size**: Implement dynamic font sizing for headings based on Tree-sitter AST.

### **Phase 4: Refactoring & OrgKit Enhancement**

* [ ] **Enhance OrgKit**:
  * [ ] Move Tree-sitter setup and highlighting logic from `RichTextEditor` into `OrgKit`.
  * [ ] Implement a unified `DocumentParser` in `OrgKit` that returns abstract style attributes/ranges.
  * [ ] Add more comprehensive tests for multi-byte characters and various Markdown/Org structures.
* [ ] **Cleanup StickiesMd**:
  * [ ] Remove the `CodeEditSourceEditor` dependency and associated code once TextKit 2 implementation is stable.
  * [ ] Refactor `RichTextEditor` to use the high-level API provided by `OrgKit`.
  * [ ] Cleanup `StickyNoteViewModel` by removing unused legacy parser calls.

### **Phase 5: UX Enhancement**

* [ ] **Mouse-through Mode**: Click-through functionality under specific conditions (modifier keys, etc.).
* [ ] **App Sandbox & Security**: Handle file access rights considering security restrictions.

### **Phase 6: Advanced Features (Future)**

* [ ] **Inline Image Preview**: Display images directly within the editor using `NSTextAttachment`.
* [ ] **Bi-directional Linking**: Navigate between notes via links.

## **6. Technical Challenges and Investment Value**

* **Modern Text Handling**: Leveraging TextKit 2 ensures the app is future-proof and performant on modern macOS.
* **Robust Parsing**: Tree-sitter provides industry-standard parsing capabilities, making support for complex formats like Org-mode more reliable.

## **7. Implementation and Development Policy**

### **7.1. Language Standard**

* **Code & Documentation**: All identifiers, comments, and documentation must be in **English**.

### **7.2. Automated Testing (CI)**

* **GitHub Actions**: Automatically run `swift test` on macOS runners upon Push/PR.

### **7.3. Test-Driven Development (TDD)**

* **Workflow**: Write tests first (Red), then proceed with implementation (Green).

### **7.4. Pull Request Workflow**

* **Pre-requisites**: Always run linter, formatter, and tests before creating a Pull Request.
  * **Formatter**: `swift-format --recursive --in-place .`
  * **Tests**: `xcodebuild test -project StickiesMd.xcodeproj -scheme StickiesMd -destination 'platform=macOS'`

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