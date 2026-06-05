/// Représentation **neutre** d'un schéma de sortie structurée, indépendante de
/// FoundationModels. Sous-ensemble de JSON Schema suffisant pour la génération guidée
/// du modèle on-device. Le backend réel (device-gated) traduit ce `SchemaNode` en
/// `DynamicGenerationSchema` d'Apple ; ce type, lui, reste pur et testable sur CI.
public indirect enum SchemaNode: Sendable, Equatable {
    case string(description: String?)
    case integer(description: String?)
    case number(description: String?)
    case boolean(description: String?)
    /// Énumération de chaînes (`enum` JSON Schema sur un type string).
    case enumeration(values: [String], description: String?)
    case array(items: SchemaNode, description: String?)
    case object(name: String, properties: [Property], description: String?)

    /// Une propriété d'objet : nom, schéma, et caractère requis.
    public struct Property: Sendable, Equatable {
        public let name: String
        public let schema: SchemaNode
        public let required: Bool
        public init(name: String, schema: SchemaNode, required: Bool) {
            self.name = name
            self.schema = schema
            self.required = required
        }
    }
}

/// Capacité de **génération structurée** : produit une sortie JSON conforme à un
/// `SchemaNode`. Distincte de `TextGenerating` (texte libre) car tous les backends ne
/// la supportent pas (seul le binding FoundationModels réel l'implémente on-device).
public protocol StructuredGenerating: Sendable {
    /// Génère un objet JSON conforme au schéma. Renvoie la chaîne JSON sérialisée.
    /// - Throws: `BridgeError` (indisponibilité, garde-fou, entrée invalide).
    func generateStructured(
        prompt: String,
        schema: SchemaNode,
        options: GenerationOptions
    ) async throws -> String
}
