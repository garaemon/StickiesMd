import Testing
@testable import OrgKit

@Suite struct OrgParserTests {
    @Test func testParseHeading() {
        let parser = OrgParser()
        let doc = parser.parse("* Heading 1\n** Heading 2")
        
        #expect(doc.children.count == 2)
        
        if let h1 = doc.children[0] as? Heading {
            #expect(h1.level == 1)
            #expect(h1.text == "Heading 1")
        } else {
            Issue.record("Expected Heading")
        }
        
        if let h2 = doc.children[1] as? Heading {
            #expect(h2.level == 2)
            #expect(h2.text == "Heading 2")
        } else {
            Issue.record("Expected Heading")
        }
    }
    
    @Test func testParseParagraph() {
        let parser = OrgParser()
        let doc = parser.parse("Hello world\nThis is a test")
        
        #expect(doc.children.count == 2)
        #expect(doc.children[0] is Paragraph)
        #expect((doc.children[0] as? Paragraph)?.text == "Hello world")
    }
    
    @Test func testParseInlineImage() {
        let parser = OrgParser()
        let doc = parser.parse("[[file:image.png]]")
        
        #expect(doc.children.count == 1)
        guard let paragraph = doc.children[0] as? Paragraph else {
            Issue.record("Expected Paragraph")
            return
        }
        
        #expect(paragraph.children.count == 1)
        guard let image = paragraph.children[0] as? ImageNode else {
            Issue.record("Expected ImageNode")
            return
        }
        
        #expect(image.source == "image.png")
    }
    
    @Test func testParseLink() {
        let parser = OrgParser()
        let doc = parser.parse("[[https://example.com][Example]]")
        
        #expect(doc.children.count == 1)
        guard let paragraph = doc.children[0] as? Paragraph else {
            Issue.record("Expected Paragraph")
            return
        }
        
        #expect(paragraph.children.count == 1)
        guard let link = paragraph.children[0] as? LinkNode else {
            Issue.record("Expected LinkNode")
            return
        }
        
        #expect(link.url == "https://example.com")
        #expect(link.text == "Example")
    }
    
    @Test func testMixedContent() {
        let parser = OrgParser()
        let doc = parser.parse("Text before [[file:img.png]] text after")
        
        guard let paragraph = doc.children[0] as? Paragraph else {
            Issue.record("Expected Paragraph")
            return
        }
        
        #expect(paragraph.children.count == 3)
        #expect((paragraph.children[0] as? TextNode)?.text == "Text before ")
        #expect((paragraph.children[1] as? ImageNode)?.source == "img.png")
        #expect((paragraph.children[2] as? TextNode)?.text == " text after")
    }
}
