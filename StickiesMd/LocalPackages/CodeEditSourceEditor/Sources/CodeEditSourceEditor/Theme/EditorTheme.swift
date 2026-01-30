//
//  EditorTheme.swift
//  CodeEditSourceEditor
//
//  Created by Lukas Pistrol on 29.05.22.
//

import SwiftUI

/// A collection of attributes used for syntax highlighting and other colors for the editor.
///
/// Attributes of a theme that do not apply to text (background, line highlight) are a single `NSColor` for simplicity.
/// All other attributes use the ``EditorTheme/Attribute`` type to store
public struct EditorTheme: Equatable {
    /// Represents attributes that can be applied to style text.
    public struct Attribute: Equatable, Hashable, Sendable {
        public let color: NSColor
        public let bold: Bool
        public let italic: Bool
        public let fontSize: CGFloat?

        public init(color: NSColor, bold: Bool = false, italic: Bool = false, fontSize: CGFloat? = nil) {
            self.color = color
            self.bold = bold
            self.italic = italic
            self.fontSize = fontSize
        }
    }

    public var text: Attribute
    public var insertionPoint: NSColor
    public var invisibles: Attribute
    public var background: NSColor
    public var lineHighlight: NSColor
    public var selection: NSColor
    public var keywords: Attribute
    public var commands: Attribute
    public var types: Attribute
    public var attributes: Attribute
    public var variables: Attribute
    public var values: Attribute
    public var numbers: Attribute
    public var strings: Attribute
    public var characters: Attribute
    public var comments: Attribute
    
    public var heading1: Attribute
    public var heading2: Attribute
    public var heading3: Attribute
    public var heading4: Attribute
    public var heading5: Attribute
    public var heading6: Attribute

    public init(
        text: Attribute,
        insertionPoint: NSColor,
        invisibles: Attribute,
        background: NSColor,
        lineHighlight: NSColor,
        selection: NSColor,
        keywords: Attribute,
        commands: Attribute,
        types: Attribute,
        attributes: Attribute,
        variables: Attribute,
        values: Attribute,
        numbers: Attribute,
        strings: Attribute,
        characters: Attribute,
        comments: Attribute,
        heading1: Attribute? = nil,
        heading2: Attribute? = nil,
        heading3: Attribute? = nil,
        heading4: Attribute? = nil,
        heading5: Attribute? = nil,
        heading6: Attribute? = nil
    ) {
        self.text = text
        self.insertionPoint = insertionPoint
        self.invisibles = invisibles
        self.background = background
        self.lineHighlight = lineHighlight
        self.selection = selection
        self.keywords = keywords
        self.commands = commands
        self.types = types
        self.attributes = attributes
        self.variables = variables
        self.values = values
        self.numbers = numbers
        self.strings = strings
        self.characters = characters
        self.comments = comments
        self.heading1 = heading1 ?? text
        self.heading2 = heading2 ?? text
        self.heading3 = heading3 ?? text
        self.heading4 = heading4 ?? text
        self.heading5 = heading5 ?? text
        self.heading6 = heading6 ?? text
    }

    /// Maps a capture type to the attributes for that capture determined by the theme.
    /// - Parameter capture: The capture to map to.
    /// - Returns: Theme attributes for the capture.
    private func mapCapture(_ capture: CaptureName?) -> Attribute {
        switch capture {
        case .include, .constructor, .keyword, .boolean, .variableBuiltin,
                .keywordReturn, .keywordFunction, .repeat, .conditional, .tag:
            return keywords
        case .comment: return comments
        case .variable, .property: return variables
        case .function, .method: return variables
        case .number, .float: return numbers
        case .string: return strings
        case .type: return types
        case .parameter: return variables
        case .typeAlternate: return attributes
        case .heading1: return heading1
        case .heading2: return heading2
        case .heading3: return heading3
        case .heading4: return heading4
        case .heading5: return heading5
        case .heading6: return heading6
        default: return text
        }
    }

    /// Get the color from ``theme`` for the specified capture name.
    /// - Parameter capture: The capture name
    /// - Returns: A `NSColor`
    func colorFor(_ capture: CaptureName?) -> NSColor {
        return mapCapture(capture).color
    }

    /// Returns the correct font with attributes (bold and italics) for a given capture name.
    /// - Parameters:
    ///   - capture: The capture name.
    ///   - font: The font to add attributes to.
    /// - Returns: A new font that has the correct attributes for the capture.
    func fontFor(for capture: CaptureName?, from font: NSFont) -> NSFont {
        let attributes = mapCapture(capture)
        // If no special attributes, return original font
        guard attributes.bold || attributes.italic || attributes.fontSize != nil else {
            return font
        }

        var font = font
        
        // Handle font size change first so we get a new font descriptor if needed
        if let size = attributes.fontSize {
            font = NSFontManager.shared.convert(font, toSize: size)
        }

        if attributes.bold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }

        if attributes.italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        return font
    }
}
