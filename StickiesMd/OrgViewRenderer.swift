import SwiftUI
import OrgKit

class OrgViewRenderer: OrgVisitor {
    var views: [AnyView] = []
    var textBuffer: String = ""
    let baseURL: URL?
    
    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    // Inline rendering state
    var inlineViews: [AnyView] = []
    
    func render(_ node: OrgNode) -> AnyView {
        views = []
        node.accept(self)
        if !views.isEmpty {
            return views[0]
        }
        return AnyView(EmptyView())
    }
    
    func visit(_ node: OrgNode) {
        node.accept(self)
    }
    
    func visitDocument(_ node: OrgDocument) {
        var childViews: [AnyView] = []
        for child in node.children {
            let renderer = OrgViewRenderer(baseURL: baseURL)
            childViews.append(renderer.render(child))
        }
        views.append(AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<childViews.count, id: \.self) { index in
                    childViews[index]
                }
            }
        ))
    }
    
    func visitHeading(_ node: Heading) {
        views.append(AnyView(
            Text(node.text)
                .font(.system(size: CGFloat(24 - node.level * 2), weight: .bold))
                .padding(.top, 4)
        ))
    }
    
    func visitParagraph(_ node: Paragraph) {
        inlineViews = []
        for child in node.children {
            child.accept(self)
        }
        
        // Combine inline views
        // Note: This is a simplified implementation. SwiftUI Text concatenation or layout might be needed for complex inline styles.
        // For now, we wrap them in a flexible stack or just render text.
        // Since we have ImageNode, we might need a FlowLayout-like structure, but for simplicity, we'll try to use Text concatenation for texts and separate views for images if possible,
        // or just use a horizontal stack if it's a single line.
        // Given Stickies nature, wrapping text with images inline is hard in pure SwiftUI without Text(Image).
        // Let's assume images are block-like or we use a custom FlowLayout later.
        // For MVP, we'll use a wrapping HStack approach or just display them sequentially.
        
        if inlineViews.count == 1 {
            views.append(inlineViews[0])
        } else {
            // Primitive FlowLayout using WrapStack from algorithms or just vertical for now if mixed?
            // Let's try to construct a single Text view if only text/links, else separate.
            views.append(AnyView(
                WrappingHStack(views: inlineViews)
            ))
        }
    }
    
    func visitText(_ node: TextNode) {
        inlineViews.append(AnyView(Text(node.text)))
    }
    
    func visitLink(_ node: LinkNode) {
        let label = node.text ?? node.url
        inlineViews.append(AnyView(
            Text(label)
                .foregroundColor(.blue)
                .underline()
                .onTapGesture {
                    if let url = URL(string: node.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
        ))
    }
    
    func visitImage(_ node: ImageNode) {
        let imageURL: URL
        if node.source.hasPrefix("/") {
            imageURL = URL(fileURLWithPath: node.source)
        } else if let baseURL = baseURL {
            imageURL = baseURL.deletingLastPathComponent().appendingPathComponent(node.source)
        } else {
            imageURL = URL(fileURLWithPath: node.source)
        }
        
        inlineViews.append(AnyView(
            AsyncImage(url: imageURL) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fit)
                     .frame(maxWidth: 200)
            } placeholder: {
                Text("[Image: \(node.source)]")
                    .foregroundColor(.secondary)
            }
        ))
    }
    
    func visitList(_ node: ListNode) {
        views.append(AnyView(
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(node.items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top) {
                        Text(node.ordered ? "\(index + 1)." : "•")
                        Text(item)
                    }
                }
            }
        ))
    }
    
    func visitCodeBlock(_ node: CodeBlock) {
        views.append(AnyView(
            VStack(alignment: .leading) {
                if let lang = node.language {
                    Text(lang)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(node.content)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        ))
    }
    
    func visitHorizontalRule(_ node: HorizontalRule) {
        views.append(AnyView(Divider()))
    }
    
    func visitStrong(_ node: StrongNode) {
        inlineViews.append(AnyView(Text(node.text).bold()))
    }
    
    func visitEmphasis(_ node: EmphasisNode) {
        inlineViews.append(AnyView(Text(node.text).italic()))
    }
}

// Simple Layout for mixed content
struct WrappingHStack: View {
    let views: [AnyView]
    
    var body: some View {
        // Simplified: just HStack for now, better flow layout needed for real rich text
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<views.count, id: \.self) { index in
                views[index]
            }
        }
    }
}
