# **Stickies.md プロジェクト仕様書**

## **1. プロダクト概要**

Stickies.mdは、macOS標準の「スティッキーズ」の軽快さと、MarkdownおよびOrg-modeによる高度な文書作成能力を組み合わせた、ファイル連動型の付箋アプリです。

### **ビジョン**

「EmacsやVS Codeで編集した思考の断片を、デスクトップ上の美しい付箋として常に傍らに置く」

## **2. 主要機能要件**

1. **macOSネイティブ実装**: Swift/SwiftUIによる軽量で高速な動作。
2. **スティッキーズUIとカスタマイズ**:
   * **ミニマルなタイトルバー**: ウィンドウ操作のための最小限の領域を備え、ここから色や透明度の変更が可能。
   * 常に最前面に表示（Floating Window）。
   * **ウィンドウ単位の外観設定**: 各付箋ごとに背景色（テーマカラー）と透明度（Opacity）を個別に設定可能。
     * **タイトルバーコントロール**: タイトルバー上のアイコンから色変更、およびボタンによる不透明度変更が可能。
   * **初期値のランダム化**: 新しくファイルを開く際、クラシックなスティッキーズ・パレットからランダムに色を選択。
   * **メニュー操作**: アプリケーションメニューから新しいファイルを開くことが可能。
   * **マウス透過モード (Low Priority)**: オーバーレイ表示として、クリックを背後のウィンドウへ通す設定。
3. **マルチフォーマット対応**: MarkdownおよびOrg-modeのパースとレンダリング。
   * **直接編集機能**: 付箋上で直接テキストを編集し、Markdown/Orgファイルとして保存可能。
4. **完全ファイル連動と設定の永続化**:
   * ローカルの.mdまたは.orgファイルと1対1で対応。
   * 外部エディタ（Emacs等）での変更を検知して即座に反映（Hot Reload）。
   * **外観設定の保存**: ファイルパスと設定（色・透明度・ウィンドウ位置）を紐づけて保存し、次回起動時に同じ外観で復元。
5. **リッチコンテンツと対話性**:
   * インライン画像表示（[[path/to/img]] または ![]()）。
   * **画像ドラッグ＆ドロップ (D&D)**: 付箋ウィンドウへの画像ドラッグ＆ドロップで、自動的にファイルを保存しリンクを挿入。
   * **カスタマイズ可能な画像保存先**: 添付画像の保存ディレクトリを相対パスまたは絶対パスで設定可能。
   * TODOステータスのハイライト。

## **3. システムアーキテクチャ**

プロジェクトはMonorepo形式を採用し、将来的なiOS展開を見据えた構成とする。

### **プロジェクト構造**

* **StickiesMd (App)**: macOSアプリケーション層。ウィンドウ管理、ファイル監視、UI描画、ユーザーインターフェース（設定画面等）、**外観設定の永続化（Persistence）**を 担当。
* **OrgKit (Swift Package)**: パースロジックを分離したコアライブラリ。

### **設定の永続化戦略**

* UserDefaults を利用し、ファイルURLの絶対パスをキーとした辞書形式で、以下の情報を格納した構造体（JSON）を保存する。
  * backgroundColor: Hex String
  * opacity: Double
  * windowFrame: NSRect (String representation)

## **4. OrgKit 詳細仕様**

swiftlang/swift-markdownのAPI設計を参考に、シンプルかつ拡張性の高いインターフェースを構築する。

### **API デザイン**

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

### **抽象構文木 (AST) 定義案**

OrgNode プロトコルを基本とし、Block要素とInline要素を階層的に保持する。

* **Block Nodes**: Document, Heading, Paragraph, List, CodeBlock, Drawer, HorizontalRule
* **Inline Nodes**: Text, Strong, Emphasis, Link, Image

## **5. 実装ロードマップ**

### **Phase 1: 基盤構築 (Infrastructure)**

* [ ] **Window Customization**: NSPanel (NSWindowのサブクラス) を使用。タイトルバー非表示化と透明背景の実装。
* [ ] **File Watcher**: NSFilePresenter を使用した特定ファイルの監視。
* [ ] **Persistence**: StickiesStore クラスの実装。UserDefaults を介した設定のセーブ/ロード。
* [ ] **Library Link**: Appターゲットから OrgKit を参照可能にする。

### **Phase 2: OrgKit 開発 (Parser)**

* [ ] **Lexer/Scanner**: 行単位でのトークン分割。
* [ ] **Node Types**: ASTを構成する各要素の定義。
* [ ] **TDD Implementation**: Swift Testing によるインクリメンタルな実装。

### **Phase 3: レンダリングとインタラクション (Rendering & Interaction)**

* [ ] **View Mapping**: 各 OrgNode に対応する SwiftUI コンポーネントの実装。
* [ ] **Drag & Drop**: 画像受入と FileManager による保存処理。
* [ ] **Menu Operations**: メニューバーからファイルを開く機能の実装。
* [ ] **Appearance UI**: タイトルバー上のアイコンからの色変更および不透明度変更ボタンの実装。
* [ ] **Rich Rendering**: MarkdownおよびOrg-modeの視認性を高めるためのリッチなレンダリング（シンタックスハイライト、スタイル適用）の実装。

### **Phase 4: ユーザ体験の向上 (UX)**

* [ ] **Window Shading**: ダブルクリック等でウィンドウを縮小。
* [ ] **Mouse-through Mode**: 特定条件下（キー修飾等）でのクリック透過機能。
* [ ] **App Sandbox & Security**: セキュリティ上の制限を考慮したファイルアクセス権のハンドリング。

### **Phase 5: ウィンドウ単位の外観設定**

* [x] **Window Configuration**: タイトルバーにwindowの設定画面を開くアイコンを設置し，色や透明度，ファイルを設定できるようにする

### **Phase 6: 内容の編集**

* [x] **Editing**: windowをフォーカスしたら実際に文章を打てるようにすること


## **6. 技術的挑戦と投資価値**

* **Pure SwiftによるOrg-mode実装**: Appleエコシステムにおける再利用性を高める。
* **iOS展開**: 同じ OrgKit を使用して、iOSアプリ/ウィジェットを最小コストで開発可能。

## **7. 実装・開発方針 (Implementation Policy)**

### **7.1. Language Standard**

* **Code & Documentation**: すべての識別子、コメント、ドキュメントは**英語**を使用する。

### **7.2. Automated Testing (CI)**

* **GitHub Actions**: Push/PR時にmacOSランナーで swift test を自動実行。

### **7.3. Test-Driven Development (TDD)**

* **Workflow**: テストを先に書き（Red）、実装を進める（Green）。

## **8. 技術的な詳細 (Technical Deep Dives)**

### **8.1. Window Behavior**

* level = .floating: 常に最前面。
* isMovableByWindowBackground = true: 背景ドラッグで移動。
* styleMask.insert(.nonactivatingPanel): フォーカスを奪わずに操作可能。

### **8.2. File Synchronization**

NSFilePresenter を採用し、外部エディタとの競合を防ぎつつ変更を検知する。

### **8.3. Initial Color Palette (Sticky Classics)**

以下の6色をデフォルトのランダム回転セットとして採用する：

1. **Yellow**: #FFF9C4 (Classic Sticky Yellow)
2. **Blue**: #E1F5FE
3. **Green**: #F1F8E9
4. **Pink**: #FCE4EC
5. **Purple**: #F3E5F5
6. **Gray**: #F5F5F5

### **8.4. Initial Opacity**
透明度の初期値は1, つまり非透明であるとする。
