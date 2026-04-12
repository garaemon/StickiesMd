# **Stickies.md Project Specification**

## **1. Product Overview**

Stickies.md is a file-linked sticky note application that combines the lightness of macOS's standard "Stickies" with the advanced document creation capabilities of Markdown and Org-mode.

### **Vision**

"Keep fragments of thought edited in Emacs or VS Code always by your side as beautiful sticky notes on your desktop."

## **2. Core Functional Requirements**

1. **Electron Desktop App**: Cross-platform capable, built with TypeScript/HTML/CSS.
2. **Stickies UI and Customization**:
   * **Frameless Window**: Minimal titlebar with custom toolbar for window operations, color and transparency controls.
   * Always on Top (Floating Window).
   * **Per-Window Appearance Settings**: Background color (theme color), font color, and opacity can be set individually for each sticky note.
     * **Toolbar Controls**: Color can be changed via settings panel, opacity via slider.
   * **Editor Customization**:
     * **Line Numbers**: Toggleable visibility, saved per window.
     * **Heading Styles**: Headings displayed with larger font sizes for structure visibility.
   * **Initial Value Randomization**: When opening a new file, a color is randomly selected from a classic stickies palette.
   * **Menu Operations**: New files can be opened from the application menu.
3. **Multi-format Support**: Parsing and rendering of Markdown and Org-mode.
   * **Direct Editing**: Text can be edited directly on the sticky note and saved as a Markdown/Org file.
4. **Full File Linking and Persistence**:
   * One-to-one correspondence with local .md or .org files.
   * Detect changes in external editors (Emacs, etc.) and reflect them immediately (Hot Reload via chokidar).
   * **Save Appearance Settings**: Save per-note settings via electron-store to restore on next launch.
     * **Stored Properties**:
       * `backgroundColor`: Hex String
       * `fontColor`: Hex String
       * `opacity`: Number (0.0-1.0)
       * `frame`: `{ x, y, width, height }`
       * `showLineNumbers`: Boolean
       * `isAlwaysOnTop`: Boolean
5. **Rich Content and Interactivity**:
   * Inline image display (`[[file:path]]` or `![](path)`) via CodeMirror Decoration widgets.
   * **Image Drag & Drop (D&D)**: Automatically save files and insert links.
   * Clickable links (bare URLs and structured links).

## **3. System Architecture**

### **Technology Stack**

| Layer | Technology |
|-------|-----------|
| Framework | Electron |
| Build Tool | electron-vite (Vite-based) |
| Language | TypeScript (strict mode) |
| Editor | CodeMirror 6 |
| Markdown | @codemirror/lang-markdown (Lezer) |
| Org-mode | StreamLanguage tokenizer + ViewPlugin decorations |
| File Watch | chokidar v4 |
| Persistence | electron-store |
| Test (unit) | Vitest |
| Test (E2E) | Playwright |
| Lint | ESLint v9 flat config + typescript-eslint |
| Format | Prettier |
| Distribution | electron-builder |

### **Project Structure**

```
├── src/
│   ├── main/                     # Main process (Node.js)
│   │   ├── index.ts              # App lifecycle
│   │   ├── window-manager.ts     # Multi-window management
│   │   ├── sticky-window.ts      # BrowserWindow factory
│   │   ├── file-watcher.ts       # chokidar file watching
│   │   ├── store.ts              # electron-store persistence
│   │   ├── menu.ts               # Application menu
│   │   └── ipc-handlers.ts       # IPC channel handlers
│   ├── renderer/                 # Renderer process (Web)
│   │   ├── editor/               # CodeMirror 6 editor
│   │   ├── ui/                   # Toolbar, settings panel
│   │   ├── styles/               # CSS
│   │   └── preload.ts            # Context bridge
│   └── shared/                   # Shared types and constants
├── test/
│   ├── unit/                     # Vitest unit tests
│   └── e2e/                      # Playwright E2E tests
└── .github/workflows/            # CI/CD
```

### **Persistence Strategy**

* Use `electron-store` to persist an array of `StickyNote` objects as JSON. Each note stores file path, appearance settings, and window position.

## **4. Text Processing Strategy**

* **Markdown**: `@codemirror/lang-markdown` with Lezer incremental parser. Handles headings, bold, italic, code, links, images natively.
* **Org-mode**: Custom `StreamLanguage` tokenizer for block-level elements (headings, code blocks, property drawers) + `ViewPlugin` with `Decoration.mark` for inline emphasis (`*bold*`, `/italic/`, `_underline_`, `+strike+`, `~code~`, `=verbatim=`). PRE/POST character validation rules ported from Org-mode spec.
* **Images**: CodeMirror `Decoration.widget` inserts `<img>` elements below image link lines. Local images served via custom `local-image://` protocol.

## **5. Implementation Roadmap**

### **Phase 1: Infrastructure** ✅

* [x] Electron project scaffold with electron-vite
* [x] BrowserWindow: frameless, transparent, always-on-top, traffic light positioning
* [x] Shared types: StickyNote interface, FileFormat, palette constants, IPC channels

### **Phase 2: Persistence & Multi-Window** ✅

* [x] electron-store persistence (notes array)
* [x] WindowManager: createWindow, restoreWindows, window tracking
* [x] Window position/size persistence (debounced move/resize)
* [x] Application menu: New Sticky (Cmd+N), Open (Cmd+O), Save (Cmd+S)

### **Phase 3: Markdown Editor** ✅

* [x] CodeMirror 6 with @codemirror/lang-markdown
* [x] Heading sizes (h1:26px through h6:14px), bold, italic, strikethrough, code
* [x] Link handler: Markdown links + bare URL detection
* [x] Line numbers toggle (CodeMirror Compartment)

### **Phase 4: Org-mode Editor** ✅

* [x] StreamLanguage tokenizer (headings, code blocks, property drawers, lists)
* [x] ViewPlugin inline emphasis with PRE/POST rules
* [x] Org links: `[[url][desc]]`, `[[url]]`
* [x] Format auto-detect (file extension)

### **Phase 5: File Synchronization** ✅

* [x] chokidar watcher per note
* [x] Save flow: editor -> debounce -> IPC -> atomic write (temp + rename)
* [x] Reload flow: chokidar -> readFile -> compare lastSavedContent -> IPC
* [x] Save-reload loop prevention

### **Phase 6: Image Display & Drag-and-Drop** ✅

* [x] CodeMirror Decoration.widget for inline images
* [x] Custom protocol (local-image://) for serving local images
* [x] Image size constraints (max-height 200px)

### **Phase 7: UI Controls & Settings** ✅

* [x] Custom toolbar: filename, save/pin/settings buttons
* [x] Settings panel: color palette (6 colors), opacity slider, font color picker, line numbers toggle
* [x] Always-on-top toggle, mouse-through mode

### **Phase 8: Quality & CI** ✅

* [x] ESLint + Prettier + TypeScript strict type checking
* [x] Vitest unit tests (47 tests)
* [x] Playwright E2E tests
* [x] GitHub Actions: lint, unit test, E2E, security audit, CodeQL, dependency review

### **Phase 9: Future Enhancements**

* [ ] **Bi-directional Linking**: Navigate between notes via links.
* [ ] **TODO highlighting**: Highlight TODO/DONE status in Org-mode.
* [ ] **Lezer grammar for Org-mode**: Replace StreamLanguage with proper incremental Lezer grammar.

## **6. Development Policy**

### **6.1. Language Standard**

* **Code & Documentation**: All identifiers, comments, and documentation must be in **English**.

### **6.2. Automated Testing (CI)**

* **GitHub Actions**: Runs lint, format check, type check, unit tests, E2E tests, and security scanning on Push/PR.

### **6.3. Test-Driven Development (TDD)**

* **Workflow**: Write tests first (Red), then proceed with implementation (Green).

### **6.4. Pull Request Workflow**

* **Pre-requisites**: Always run linter, formatter, and tests before creating a Pull Request.
  * **Lint**: `npm run lint`
  * **Format**: `npm run format:check`
  * **Type Check**: `npm run typecheck`
  * **Tests**: `npm run test:unit`

## **7. Technical Deep Dives**

### **7.1. Window Behavior (Electron)**

* `alwaysOnTop: true` with `level: 'floating'`: Always on top.
* CSS `-webkit-app-region: drag`: Move by dragging the toolbar.
* `frame: false` + `titleBarStyle: 'hidden'`: Frameless with macOS traffic lights.
* `transparent: true`: Transparent window, color applied via CSS.
* `win.setIgnoreMouseEvents(true)`: Mouse-through mode.

### **7.2. File Synchronization**

Uses `chokidar` to detect external file changes. Save-reload loop prevention via `lastSavedContent` comparison (same pattern as the original NSFilePresenter implementation).

### **7.3. Initial Color Palette (Sticky Classics)**

6 colors as the default random rotation set:

1. **Yellow**: #FFF9C4
2. **Blue**: #E1F5FE
3. **Green**: #F1F8E9
4. **Pink**: #FCE4EC
5. **Purple**: #F3E5F5
6. **Gray**: #F5F5F5

### **7.4. Initial Opacity**

The initial value for opacity is 1, meaning non-transparent.
