import FoundationBridgeCore

#if canImport(FoundationModels)
import FoundationModels

/// Génération **structurée** on-device : traduit un `SchemaNode` neutre en
/// `DynamicGenerationSchema` d'Apple, lance une génération guidée, et renvoie le JSON
/// produit (`GeneratedContent.jsonString`). Disponible uniquement sur macOS 26+ avec
/// Apple Intelligence (Mac Apple Silicon éligible).
@available(macOS 26.0, *)
public struct FoundationModelsStructuredGenerator: StructuredGenerating {

    public init() {}

    public func generateStructured(
        prompt: String,
        schema: SchemaNode,
        options: FoundationBridgeCore.GenerationOptions
    ) async throws -> String {
        if let error = FoundationModelsGenerator.modelAvailability().asErrorIfUnavailable() {
            throw error
        }

        // Construction du schéma de génération à partir du schéma neutre.
        let generationSchema: GenerationSchema
        do {
            let root = Self.dynamic(from: schema, fallbackName: "Result")
            generationSchema = try GenerationSchema(root: root, dependencies: [])
        } catch {
            // Schéma incohérent (noms dupliqués, référence cassée…) → entrée invalide
            // exploitable plutôt qu'échec opaque.
            throw BridgeError.invalidInput(field: "schema")
        }

        let session: LanguageModelSession
        if let instructions = options.instructions {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }
        let response = try await session.respond(to: prompt, schema: generationSchema)
        return response.content.jsonString
    }

    /// Traduit récursivement le `SchemaNode` neutre vers `DynamicGenerationSchema`.
    static func dynamic(from node: SchemaNode, fallbackName: String) -> DynamicGenerationSchema {
        switch node {
        case .string:
            return DynamicGenerationSchema(type: String.self)
        case .integer:
            return DynamicGenerationSchema(type: Int.self)
        case .number:
            return DynamicGenerationSchema(type: Double.self)
        case .boolean:
            return DynamicGenerationSchema(type: Bool.self)
        case let .enumeration(values, description):
            return DynamicGenerationSchema(name: fallbackName, description: description, anyOf: values)
        case let .array(items, _):
            return DynamicGenerationSchema(arrayOf: dynamic(from: items, fallbackName: fallbackName + "Item"))
        case let .object(name, properties, description):
            let props = properties.map { property in
                DynamicGenerationSchema.Property(
                    name: property.name,
                    schema: dynamic(from: property.schema, fallbackName: property.name),
                    isOptional: !property.required
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: props)
        }
    }
}
#endif
