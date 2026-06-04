import FoundationBridgeCore

/// Validateur pur et sans état des paramètres extraits d'une requête.
/// Aucune dépendance vers FoundationModels ni vers le serveur HTTP.
public enum RequestValidator {

    /// Valide le prompt et les options de génération.
    /// - Throws: `BridgeError.invalidInput(field:)` si une contrainte est violée.
    public static func validate(prompt: String, options: GenerationOptions) throws {
        // Prompt non vide (après retrait des espaces et sauts de ligne)
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.invalidInput(field: "messages")
        }

        // maxTokens strictement positif si fourni
        if let maxTokens = options.maximumTokens {
            guard maxTokens > 0 else {
                throw BridgeError.invalidInput(field: "max_tokens")
            }
        }

        // temperature dans [0, 2] si fournie
        if let temperature = options.temperature {
            guard temperature >= 0, temperature <= 2 else {
                throw BridgeError.invalidInput(field: "temperature")
            }
        }
    }
}
