import Foundation
@preconcurrency import JSONSchema
@preconcurrency import SwiftyJSON

/// `JSONSchema`'s case storage isn't `public` — only its `Codable` conformance and
/// static factory methods are. Encoding then re-parsing through `JSONSerialization`
/// is the only supported way to introspect a schema's raw JSON shape from outside
/// the `JSONSchema` module, so provider request builders share this helper instead
/// of duplicating the encode/`JSONSerialization` round trip.
extension JSONSchema {
    func asJSON() throws -> JSON {
        let data = try JSONEncoder().encode(self)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return JSON(object)
    }
}
