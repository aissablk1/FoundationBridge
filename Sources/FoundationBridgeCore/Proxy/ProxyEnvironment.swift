/// Calcule les variables d'environnement à injecter dans un processus enfant pour
/// qu'il route ses appels API vers le bridge local (mode proxy « reroute local »).
///
/// Pur et testable : ne lance aucun processus, n'importe rien d'externe. La commande
/// CLI `proxy` s'en sert pour envelopper un agent (`claude`, un script Python `openai`,
/// etc.) afin qu'il parle au modèle on-device sans aucune modification côté client.
public enum ProxyEnvironment {

    /// Clé d'API factice fournie aux SDK qui exigent une valeur non vide quand aucun
    /// token n'est configuré (le bridge local n'authentifie pas en mode ouvert).
    public static let placeholderKey = "foundationbridge-local"

    /// Variables d'environnement pointant les SDK OpenAI/Anthropic vers le bridge local.
    ///
    /// - `OPENAI_BASE_URL` : racine + suffixe `/v1` (convention des clients OpenAI).
    /// - `ANTHROPIC_BASE_URL` : racine (les clients Anthropic, dont Claude Code, ajoutent
    ///   eux-mêmes `/v1/messages`).
    /// - `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` : le token configuré s'il existe, sinon une
    ///   clé factice (certains SDK refusent de démarrer sans clé).
    ///
    /// Un host d'écoute `0.0.0.0` (toutes interfaces) n'est pas une URL client valide :
    /// il est ramené à `127.0.0.1` pour l'enfant.
    public static func overrides(host: String, port: Int, token: String? = nil) -> [String: String] {
        let clientHost = (host == "0.0.0.0") ? "127.0.0.1" : host
        let base = "http://\(clientHost):\(port)"
        let key = (token?.isEmpty == false) ? token! : placeholderKey
        return [
            "OPENAI_BASE_URL": "\(base)/v1",
            "OPENAI_API_KEY": key,
            "ANTHROPIC_BASE_URL": base,
            "ANTHROPIC_API_KEY": key,
        ]
    }
}
