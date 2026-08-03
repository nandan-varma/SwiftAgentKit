import Foundation

/// Errors produced while parsing or evaluating an arithmetic expression.
enum MathParseError: Error, Equatable, Sendable {
    case unexpectedCharacter(Character)
    case unexpectedEnd
    case unbalancedParentheses
    case malformedExpression
    case divisionByZero
}

/// A small, safe recursive-descent evaluator for arithmetic expressions.
///
/// Supports `+ - * /`, parentheses, unary minus, and decimal numbers. Unlike
/// `NSExpression`, every failure mode is a Swift `throws` error — malformed
/// input can never crash the process.
struct MathExpressionEvaluator {
    private enum Token: Equatable {
        case number(Double)
        case plus, minus, star, slash, lparen, rparen
    }

    static func evaluate(_ expression: String) throws -> Double {
        let tokens = try tokenize(expression)
        var parser = Parser(tokens: tokens)
        let result = try parser.parseExpression()
        guard parser.isAtEnd else {
            throw MathParseError.malformedExpression
        }
        return result
    }

    private static func tokenize(_ expression: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(expression)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case _ where c.isWhitespace:
                i += 1
            case "+": tokens.append(.plus); i += 1
            case "-": tokens.append(.minus); i += 1
            case "*": tokens.append(.star); i += 1
            case "/": tokens.append(.slash); i += 1
            case "(": tokens.append(.lparen); i += 1
            case ")": tokens.append(.rparen); i += 1
            case _ where c.isNumber || c == ".":
                var numStr = ""
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    numStr.append(chars[i])
                    i += 1
                }
                guard let value = Double(numStr) else {
                    throw MathParseError.unexpectedCharacter(c)
                }
                tokens.append(.number(value))
            default:
                throw MathParseError.unexpectedCharacter(c)
            }
        }
        return tokens
    }

    /// Grammar: expression := term (('+'|'-') term)*
    ///          term       := factor (('*'|'/') factor)*
    ///          factor     := '-' factor | '+' factor | primary
    ///          primary    := number | '(' expression ')'
    private struct Parser {
        let tokens: [Token]
        var position = 0

        var isAtEnd: Bool { position >= tokens.count }

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while !isAtEnd {
                switch tokens[position] {
                case .plus:
                    position += 1
                    value += try parseTerm()
                case .minus:
                    position += 1
                    value -= try parseTerm()
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parseFactor()
            while !isAtEnd {
                switch tokens[position] {
                case .star:
                    position += 1
                    value *= try parseFactor()
                case .slash:
                    position += 1
                    let divisor = try parseFactor()
                    guard divisor != 0 else { throw MathParseError.divisionByZero }
                    value /= divisor
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseFactor() throws -> Double {
            guard !isAtEnd else { throw MathParseError.unexpectedEnd }
            switch tokens[position] {
            case .minus:
                position += 1
                return -(try parseFactor())
            case .plus:
                position += 1
                return try parseFactor()
            default:
                return try parsePrimary()
            }
        }

        mutating func parsePrimary() throws -> Double {
            guard !isAtEnd else { throw MathParseError.unexpectedEnd }
            switch tokens[position] {
            case .number(let value):
                position += 1
                return value
            case .lparen:
                position += 1
                let value = try parseExpression()
                guard !isAtEnd, tokens[position] == .rparen else {
                    throw MathParseError.unbalancedParentheses
                }
                position += 1
                return value
            default:
                throw MathParseError.malformedExpression
            }
        }
    }
}
