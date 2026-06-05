import Foundation

/// Parse un **sous-ensemble de JSON Schema** vers le `SchemaNode` neutre. Pur et
/// testable sur CI (aucune dépendance à FoundationModels).
///
/// Sous-ensemble supporté (suffisant pour la génération guidée on-device) :
/// - racine de type `object` avec `properties` et `required` ;
/// - types feuilles `string`, `integer`, `number`, `boolean` ;
/// - `enum` (liste de chaînes) → énumération ;
/// - `array` avec `items` ;
/// - objets imbriqués ;
/// - `description` optionnelle à tout niveau.
///
/// Tout schéma hors de ce sous-ensemble lève `BridgeError.invalidInput(field: "schema")`
/// — message clair plutôt qu'échec opaque du modèle (cf. design §G).
public enum JSONSchemaParser {

    public static func parse(json: String, rootName: String = "Result") throws -> SchemaNode {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            throw BridgeError.invalidInput(field: "schema")
        }
        return try parseNode(dict, name: rootName)
    }

    private static func parseNode(_ dict: [String: Any], name: String) throws -> SchemaNode {
        let description = dict["description"] as? String

        // `enum` (liste de chaînes) prime sur `type`.
        if let cases = dict["enum"] as? [Any] {
            let values = cases.compactMap { $0 as? String }
            guard !values.isEmpty, values.count == cases.count else {
                throw BridgeError.invalidInput(field: "schema")
            }
            return .enumeration(values: values, description: description)
        }

        guard let type = dict["type"] as? String else {
            throw BridgeError.invalidInput(field: "schema")
        }

        switch type {
        case "string":  return .string(description: description)
        case "integer": return .integer(description: description)
        case "number":  return .number(description: description)
        case "boolean": return .boolean(description: description)

        case "array":
            guard let items = dict["items"] as? [String: Any] else {
                throw BridgeError.invalidInput(field: "schema")
            }
            return .array(items: try parseNode(items, name: name + "Item"), description: description)

        case "object":
            guard let properties = dict["properties"] as? [String: Any] else {
                throw BridgeError.invalidInput(field: "schema")
            }
            let requiredNames = Set((dict["required"] as? [Any])?.compactMap { $0 as? String } ?? [])
            // Tri par nom pour un ordre déterministe (tests + sortie stable).
            let props: [SchemaNode.Property] = try properties.keys.sorted().map { key in
                guard let child = properties[key] as? [String: Any] else {
                    throw BridgeError.invalidInput(field: "schema")
                }
                return SchemaNode.Property(
                    name: key,
                    schema: try parseNode(child, name: key),
                    required: requiredNames.contains(key)
                )
            }
            return .object(name: name, properties: props, description: description)

        default:
            throw BridgeError.invalidInput(field: "schema")
        }
    }
}
