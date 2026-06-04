/// Décision d'autorisation **pure** (sans dépendance HTTP), donc unit-testable.
/// Le middleware Hummingbird (couche serveur) se contente d'extraire les en-têtes
/// et de déléguer ici.
public enum BearerAuth {

    /// Détermine si une requête est autorisée.
    ///
    /// - `configuredToken` nil ou vide → **toujours autorisé** (mode local ouvert,
    ///   cohérent avec un bind `127.0.0.1` par défaut).
    /// - sinon → exige `Authorization: Bearer <token>` **ou** `x-api-key: <token>`
    ///   (ce dernier pour la compatibilité des clients Anthropic).
    public static func isAuthorized(
        configuredToken: String?,
        authorizationHeader: String?,
        apiKeyHeader: String?
    ) -> Bool {
        guard let configured = configuredToken, !configured.isEmpty else {
            return true
        }
        if let auth = authorizationHeader, auth == "Bearer \(configured)" {
            return true
        }
        if let key = apiKeyHeader, key == configured {
            return true
        }
        return false
    }
}
