//
//  BoopToken.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Foundation

struct BoopToken {

    enum TokenType: String {
        case comment
        case string
        case attribute
        case keyword
        case number
        case extra
    }

    let type: TokenType
    let range: NSRange
    /// Greedy tokens (strings, comments) switch off tokens that start inside them.
    let isGreedy: Bool
}
