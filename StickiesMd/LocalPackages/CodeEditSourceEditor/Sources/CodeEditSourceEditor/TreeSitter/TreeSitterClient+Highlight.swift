//
//  TreeSitterClient+Highlight.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 3/10/23.
//

import Foundation
import SwiftTreeSitter
import CodeEditLanguages

extension TreeSitterClient {
    func queryHighlightsForRange(range: NSRange) -> [HighlightRange] {
        guard let state = self.state else { return [] }

        var highlights: [HighlightRange] = []
        var injectedSet = IndexSet(integersIn: range)

        for layer in state.layers where layer.id != state.primaryLayer.id {
            // Query injected only if a layer's ranges intersects with `range`
            for layerRange in layer.ranges {
                if let rangeIntersection = range.intersection(layerRange) {
                    let queryResult = queryLayerHighlights(
                        layer: layer,
                        range: rangeIntersection
                    )

                    highlights.append(contentsOf: queryResult)
                    injectedSet.remove(integersIn: rangeIntersection)
                }
            }
        }

        // Query primary for any ranges that weren't used in the injected layers.
        for range in injectedSet.rangeView {
            let queryResult = queryLayerHighlights(
                layer: state.layers[0],
                range: NSRange(range)
            )
            highlights.append(contentsOf: queryResult)
        }

        return highlights
    }

    /// Queries the given language layer for any highlights.
    /// - Parameters:
    ///   - layer: The layer to query.
    ///   - range: The range to query for.
    /// - Returns: Any ranges to highlight.
    internal func queryLayerHighlights(
        layer: LanguageLayer,
        range: NSRange
    ) -> [HighlightRange] {
        guard let tree = layer.tree,
              let rootNode = tree.rootNode else {
            return []
        }

        // This needs to be on the main thread since we're going to use the `textProvider` in
        // the `highlightsFromCursor` method, which uses the textView's text storage.
        guard let queryCursor = layer.languageQuery?.execute(node: rootNode, in: tree) else {
            return []
        }
        queryCursor.setRange(range)
        queryCursor.matchLimit =  Constants.matchLimit

        var highlights: [HighlightRange] = []

        // See https://github.com/CodeEditApp/CodeEditSourceEditor/pull/228
        if layer.id == .jsdoc {
            highlights.append(HighlightRange(range: range, capture: .comment))
        }

        highlights += highlightsFromCursor(cursor: queryCursor, includedRange: range)

        return highlights
    }

    /// Resolves a query cursor to the highlight ranges it contains.
    /// **Must be called on the main thread**
    /// - Parameters:
    ///     - cursor: The cursor to resolve.
    ///     - includedRange: The range to include highlights from.
    /// - Returns: Any highlight ranges contained in the cursor.
    internal func highlightsFromCursor(
        cursor: QueryCursor,
        includedRange: NSRange
    ) -> [HighlightRange] {
        guard let readCallback else { return [] }
        var ranges: [NSRange: Int] = [:]
        
        let allCaptures = cursor
            .resolve(with: .init(textProvider: readCallback)) // Resolve our cursor against the query
            .flatMap { $0.captures }
            
        return allCaptures
            .reversed() // SwiftTreeSitter returns captures in the reverse order of what we need to filter with.
            .compactMap { capture in
                let range = capture.range
                let index = capture.index

                // Lower indexed captures are favored over higher, this is why we reverse it above
                if let existingLevel = ranges[range], existingLevel <= index {
                    return nil
                }

                guard var captureName = CaptureName.fromString(capture.name) else {
                    return nil
                }
                
                // Enhanced Heading Detection
                // If we captured a generic heading title (text.title), try to determine the level
                // by inspecting the parent node structure.
                if captureName == .heading1 {
                    let node = capture.node
                    if let parent = node.parent {
                        // Standard Markdown (atx_heading)
                        // Structure: (atx_heading (atx_h1_marker) (inline))
                        
                        // Check for explicit markers in siblings
                        for i in 0..<parent.childCount {
                            if let child = parent.child(at: i) {
                                let type = child.nodeType
                                if type == "atx_h1_marker" { captureName = .heading1; break }
                                if type == "atx_h2_marker" { captureName = .heading2; break }
                                if type == "atx_h3_marker" { captureName = .heading3; break }
                                if type == "atx_h4_marker" { captureName = .heading4; break }
                                if type == "atx_h5_marker" { captureName = .heading5; break }
                                if type == "atx_h6_marker" { captureName = .heading6; break }
                            }
                        }
                    }
                }

                // Update the filter level to the current index since it's lower and a 'valid' capture
                ranges[range] = index

                // Validate range and capture name
                let intersectionRange = range.intersection(includedRange) ?? .zero
                guard intersectionRange.length > 0 else {
                    return nil
                }

                return HighlightRange(range: intersectionRange, capture: captureName)
            }
    }
}
