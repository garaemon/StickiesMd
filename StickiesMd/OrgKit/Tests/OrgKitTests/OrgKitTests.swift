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
}