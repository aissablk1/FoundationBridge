import FoundationBridgeCore

#if canImport(FoundationModels)
import FoundationModels

/// Backend réel : conforme `TextGenerating` du cœur en s'appuyant sur le LLM
/// on-device d'Apple (FoundationModels). Disponible uniquement sur macOS 26+
/// avec Apple Intelligence activé sur un Mac Apple Silicon éligible.
///
/// Note : FoundationModels expose aussi un type `GenerationOptions` ; on qualifie
/// donc explicitement `FoundationBridgeCore.GenerationOptions` pour lever l'ambiguïté.
@available(macOS 26.0, *)
public struct FoundationModelsGenerator: TextGenerating {

    public init() {}

    /// Traduit `SystemLanguageModel.availability` vers le type neutre du cœur.
    public static func modelAvailability() -> ModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .deviceNotEligible
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .modelNotReady:
                return .modelNotReady
            @unknown default:
                return .unknown("modèle indisponible (raison inconnue)")
            }
        }
    }

    public func respond(to prompt: String, options: FoundationBridgeCore.GenerationOptions) async throws -> String {
        if let error = Self.modelAvailability().asErrorIfUnavailable() {
            throw error
        }
        let session: LanguageModelSession
        if let instructions = options.instructions {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }
        let response = try await session.respond(to: prompt)
        return response.content
    }

    public func stream(to prompt: String, options: FoundationBridgeCore.GenerationOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if let error = Self.modelAvailability().asErrorIfUnavailable() {
                    continuation.finish(throwing: error)
                    return
                }
                let session: LanguageModelSession
                if let instructions = options.instructions {
                    session = LanguageModelSession(instructions: instructions)
                } else {
                    session = LanguageModelSession()
                }
                do {
                    // FoundationModels émet des snapshots CUMULATIFS (l'état partiel
                    // complet à chaque étape). On n'émet que le nouveau suffixe afin de
                    // produire des deltas façon SSE/OpenAI. On se protège d'un éventuel
                    // snapshot plus court (rollback non garanti, cf. design §F).
                    var previous = ""
                    for try await snapshot in session.streamResponse(to: prompt) {
                        let cumulative = snapshot.content
                        if cumulative.count >= previous.count {
                            let delta = String(cumulative.dropFirst(previous.count))
                            if !delta.isEmpty { continuation.yield(delta) }
                        }
                        previous = cumulative
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
#endif
