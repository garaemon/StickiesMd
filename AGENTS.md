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
     * **Minimap**: Hidden by default (remove "mini editor" on top right).
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

The project adopts a simple single-target structure, leveraging powerful third-party editors.

### **Project Structure**

* **StickiesMd (App)**: macOS application layer. Responsible for window management, file monitoring, UI rendering, user interface (settings screen, etc.), and **Persistence of appearance settings**.
  * **Editor Engine**: Uses `CodeEditSourceEditor` for high-performance text editing and syntax highlighting.
  * **Note**: Previously used a separate `OrgKit` package, but consolidated into the main app target to streamline development, relying on `CodeEditSourceEditor` for core text handling.

### **Persistence Strategy**

* Use `UserDefaults` to store a dictionary where the key is the absolute path of the file URL, and the value is a struct (JSON) containing all per-window settings defined in Section 2.

## **4. Text Processing Strategy**

Instead of a dedicated AST parser (like the deprecated `OrgKit`), the app relies on `CodeEditSourceEditor` for rendering and editing. 

* **Parsing**: `CodeEditSourceEditor` (backed by Tree-sitter) handles syntax highlighting and basic structure.
* **Advanced Logic**: Future features requiring deep structure understanding (e.g., outlining, folding) will utilize Tree-sitter's AST or lightweight internal logic within the App target.

## **5. Implementation Roadmap**

### **Phase 1: Infrastructure**

* [x] **Window Customization**: Use `NSPanel` (subclass of `NSWindow`). Implement title bar hiding and transparent backgrounds.
* [x] **File Watcher**: Monitor specific files using `NSFilePresenter`.
* [x] **Persistence**: Implement `StickiesStore` class. Save/load settings via `UserDefaults`.

### **Phase 2: Core Text Editing**

* [x] **Editor Integration**: Integrated `CodeEditSourceEditor` as the primary editing and rendering engine.
* [x] **Org-mode Support**: Currently using Markdown mode as a fallback for Org files.
* [x] **Editing**: Enable actual text input using `CodeEditSourceEditor` when the window is focused.

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
  * [x] **Heading Size**: Investigate and implement larger font sizes for headings within `CodeEditSourceEditor` (Implemented custom `EditorTheme`, `CaptureName` extensions, and runtime heading level detection).

### **Phase 4: Refactoring & Cleanup**

* [ ] **Remove OrgKit**: Delete the unused `OrgKit` package and remove dependencies.
* [ ] **Cleanup ViewModel**: Remove unused `OrgDocument` and parser calls from `StickyNoteViewModel`.

### **Phase 5: UX Enhancement**

* [ ] **Mouse-through Mode**: Click-through functionality under specific conditions (modifier keys, etc.).
* [ ] **App Sandbox & Security**: Handle file access rights considering security restrictions.

### **Phase 6: Advanced Features (Future)**

* [ ] **Org-mode Syntax Highlighting**: Fully support Org-mode syntax in `CodeEditSourceEditor`.
* [ ] **Inline Image Preview**: Display images directly within the editor.
* [ ] **Bi-directional Linking**: Navigate between notes via links.

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
