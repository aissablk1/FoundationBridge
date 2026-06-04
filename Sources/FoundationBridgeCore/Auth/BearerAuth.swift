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
    ///
    /// La comparaison du secret est faite à **temps constant** pour ne pas exposer
    /// le token à une attaque temporelle.
    public static func isAuthorized(
        configuredToken: String?,
        authorizationHeader: String?,
        apiKeyHeader: String?
    ) -> Bool {
        guard let configured = configuredToken, !configured.isEmpty else {
            return true
        }
        if let auth = authorizationHeader, auth.hasPrefix("Bearer ") {
            let presented = String(auth.dropFirst("Bearer ".count))
            if constantTimeEquals(presented, configured) {
                return true
            }
        }
        if let key = apiKeyHeader, constantTimeEquals(key, configured) {
            return true
        }
        return false
    }

    /// Égalité d'octets à temps constant : ne court-circuite ni sur la longueur ni
    /// sur le premier octet divergent (mitige les attaques temporelles).
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var diff = a.count ^ b.count
        let maxLen = max(a.count, b.count)
        var i = 0
        while i < maxLen {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            diff |= Int(x ^ y)
            i += 1
        }
        return diff == 0
    }
}
