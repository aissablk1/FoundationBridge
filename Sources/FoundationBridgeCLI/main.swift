import Foundation
import FoundationBridgeCore
import FoundationModelsBackend
import FoundationBridgeServer
import FoundationBridgeMCP
import FoundationBridgeACP

/// CLI FoundationBridge. Codes de sortie sémantiques (cf. `ExitCode`).

func printUsage() {
    let usage = """
    foundationbridge \(FoundationBridge.coreVersion)
    Passerelle vers le LLM on-device d'Apple (FoundationModels).

    USAGE:
      foundationbridge <commande> [arguments]

    COMMANDES:
      version              Affiche la version
      diagnose             Affiche la disponibilite du modele on-device
      generate <texte>     Genere une reponse (lit aussi stdin si pas d'argument)
      structured <texte> <json-schema>
                           Genere un objet JSON conforme au JSON Schema fourni
      serve [--port N] [--host H] [--token T]
                           Demarre le serveur HTTP (REST OpenAI + Anthropic)
                           --token (ou env FB_TOKEN) active l'auth Bearer
                           --host non-local exige un token
      mcp [--http [--port N] [--host H] [--token T]]
                           Serveur MCP : stdio par defaut, ou Streamable-HTTP (--http)
                           sur /mcp (Claude Desktop/Code, Cursor, Zed, clients distants)
      proxy [--port N] [--host H] [--token T] -- <commande> [args...]
                           Lance <commande> avec OPENAI_BASE_URL/ANTHROPIC_BASE_URL
                           pointant sur le bridge local (ex: proxy -- claude)
      acp                  Demarre le serveur ACP stdio (Zed Agent Client Protocol)
      help                 Affiche cette aide

    CODES DE SORTIE:
      0 succes . 1 erreur . 2 modele indisponible . 3 garde-fou
      4 depassement contexte . 5 entree invalide . 6 rate limit
    """
    print(usage)
}

func currentAvailability() -> ModelAvailability {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        return FoundationModelsGenerator.modelAvailability()
    }
    return .unknown("macOS 26 requis")
    #else
    return .unknown("FoundationModels indisponible sur cette plateforme")
    #endif
}

func runGenerate(prompt: String) async -> Int32 {
    if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        FileHandle.standardError.write(Data("Entree invalide : prompt vide\n".utf8))
        return ExitCode.invalidInput.rawValue
    }
    do {
        let text: String
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            text = try await FoundationModelsGenerator().respond(to: prompt, options: .init())
        } else {
            throw BridgeError.modelUnavailable(reason: "macOS 26 requis")
        }
        #else
        throw BridgeError.modelUnavailable(reason: "FoundationModels indisponible sur cette plateforme")
        #endif
        print(text)
        return ExitCode.success.rawValue
    } catch let error as BridgeError {
        FileHandle.standardError.write(Data((error.message + "\n").utf8))
        return error.exitCode.rawValue
    } catch {
        FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
        return ExitCode.genericError.rawValue
    }
}

/// Génération structurée : parse un JSON Schema, génère un objet JSON conforme on-device.
func runStructured(prompt: String, schemaJSON: String) async -> Int32 {
    guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        FileHandle.standardError.write(Data("Entree invalide : prompt vide\n".utf8))
        return ExitCode.invalidInput.rawValue
    }
    do {
        let node = try JSONSchemaParser.parse(json: schemaJSON)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let json = try await FoundationModelsStructuredGenerator()
                .generateStructured(prompt: prompt, schema: node, options: .init())
            print(json)
            return ExitCode.success.rawValue
        }
        throw BridgeError.modelUnavailable(reason: "macOS 26 requis")
        #else
        throw BridgeError.modelUnavailable(reason: "FoundationModels indisponible sur cette plateforme")
        #endif
    } catch let error as BridgeError {
        FileHandle.standardError.write(Data((error.message + "\n").utf8))
        return error.exitCode.rawValue
    } catch {
        FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
        return ExitCode.genericError.rawValue
    }
}

func readStdin() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

func parsePort(_ args: [String]) -> Int {
    if let i = args.firstIndex(of: "--port"), i + 1 < args.count, let p = Int(args[i + 1]) {
        return p
    }
    return 11434
}

/// Lit la valeur d'un drapeau `--clef valeur`, sinon nil.
func parseFlag(_ args: [String], _ flag: String) -> String? {
    if let i = args.firstIndex(of: flag), i + 1 < args.count {
        return args[i + 1]
    }
    return nil
}

/// Sonde `GET /healthz` jusqu'à 200 (ou expiration). Sert à n'enchaîner le lancement
/// de l'enfant qu'une fois le serveur local prêt à recevoir le trafic rerouté.
func waitForHealthz(host: String, port: Int, attempts: Int = 30) async -> Bool {
    let clientHost = (host == "0.0.0.0") ? "127.0.0.1" : host
    guard let url = URL(string: "http://\(clientHost):\(port)/healthz") else { return false }
    for _ in 0..<attempts {
        if let (_, response) = try? await URLSession.shared.data(from: url),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            return true
        }
        try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
    }
    return false
}

/// Mode proxy « reroute local » : démarre le serveur local en tâche de fond puis lance
/// la commande enfant avec `OPENAI_BASE_URL`/`ANTHROPIC_BASE_URL` pointant sur le bridge.
/// L'enfant (Claude Code, SDK openai/anthropic…) parle ainsi au modèle on-device sans
/// modification. Le code de sortie de l'enfant est propagé ; le serveur est arrêté ensuite.
func runProxy(host: String, port: Int, token: String?, childArgv: [String]) async -> Int32 {
    let app = FoundationBridgeServer.makeApplication(config: .init(host: host, port: port, token: token))
    let serverTask = Task { try? await app.runService() }
    defer { serverTask.cancel() }

    guard await waitForHealthz(host: host, port: port) else {
        FileHandle.standardError.write(Data("Refus proxy : le serveur local n'a pas démarré (port \(port) occupé ?).\n".utf8))
        return ExitCode.genericError.rawValue
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = childArgv
    process.environment = ProcessInfo.processInfo.environment.merging(
        ProxyEnvironment.overrides(host: host, port: port, token: token)
    ) { _, injected in injected }

    do {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in cont.resume() }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    } catch {
        FileHandle.standardError.write(Data(("Échec du lancement de la commande enfant : \(error)\n").utf8))
        return ExitCode.genericError.rawValue
    }
    return process.terminationStatus
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "help"
var code: Int32 = ExitCode.success.rawValue

switch command {
case "version", "--version", "-v":
    print("foundationbridge \(FoundationBridge.coreVersion)")
case "diagnose":
    let availability = currentAvailability()
    print("Disponibilite du modele : \(availability.reason)")
    code = availability.isReady ? ExitCode.success.rawValue : ExitCode.modelUnavailable.rawValue
case "generate":
    let inline = args.dropFirst().joined(separator: " ")
    let prompt = inline.isEmpty ? readStdin() : inline
    code = await runGenerate(prompt: prompt)
case "structured":
    let rest = Array(args.dropFirst())
    if rest.count >= 2 {
        code = await runStructured(prompt: rest[0], schemaJSON: rest[1])
    } else {
        FileHandle.standardError.write(Data("Usage : foundationbridge structured \"<texte>\" '<json-schema>'\n".utf8))
        code = ExitCode.invalidInput.rawValue
    }
case "serve":
    let port = parsePort(args)
    let host = parseFlag(args, "--host") ?? "127.0.0.1"
    let token = parseFlag(args, "--token") ?? ProcessInfo.processInfo.environment["FB_TOKEN"]
    if host != "127.0.0.1" && host != "localhost" && (token ?? "").isEmpty {
        FileHandle.standardError.write(Data("Refus securite : --host non-local exige --token (ou FB_TOKEN).\n".utf8))
        code = ExitCode.guardrailBlocked.rawValue
    } else {
        do {
            let auth = (token ?? "").isEmpty ? "ouverte (local)" : "Bearer requise"
            print("FoundationBridge — serveur HTTP sur http://\(host):\(port)  [auth : \(auth)]")
            print("  GET  /healthz")
            print("  GET  /v1/models")
            print("  POST /v1/chat/completions   (OpenAI)")
            print("  POST /v1/messages           (Anthropic)")
            print("  WS   /ws                    (streaming bidirectionnel)")
            try await FoundationBridgeServer.makeWebSocketApplication(config: .init(host: host, port: port, token: token)).runService()
        } catch {
            FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
            code = ExitCode.genericError.rawValue
        }
    }
case "mcp":
    // stdout est reserve au JSON-RPC ; tout diagnostic part sur stderr.
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let router = MCPToolRouter(
            backend: FoundationModelsGenerator(),
            availability: { FoundationModelsGenerator.modelAvailability() },
            structured: FoundationModelsStructuredGenerator()
        )
        if args.contains("--http") {
            // Transport Streamable-HTTP (clients MCP web/distants). stdout reste libre.
            let port = parsePort(args)
            let host = parseFlag(args, "--host") ?? "127.0.0.1"
            let token = parseFlag(args, "--token") ?? ProcessInfo.processInfo.environment["FB_TOKEN"]
            if host != "127.0.0.1" && host != "localhost" && (token ?? "").isEmpty {
                FileHandle.standardError.write(Data("Refus securite : --host non-local exige --token (ou FB_TOKEN).\n".utf8))
                code = ExitCode.guardrailBlocked.rawValue
            } else {
                FileHandle.standardError.write(Data("FoundationBridge MCP (HTTP) sur http://\(host):\(port)/mcp\n".utf8))
                do {
                    try await FoundationBridgeServer.runMCPHTTP(
                        router: router,
                        config: .init(host: host, port: port, token: token),
                        version: FoundationBridge.coreVersion
                    )
                } catch {
                    FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
                    code = ExitCode.genericError.rawValue
                }
            }
        } else {
            FileHandle.standardError.write(Data("FoundationBridge MCP (stdio) pret.\n".utf8))
            do {
                try await MCPServerRunner.run(router: router, version: FoundationBridge.coreVersion)
            } catch {
                FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
                code = ExitCode.genericError.rawValue
            }
        }
    } else {
        FileHandle.standardError.write(Data("MCP indisponible : macOS 26 requis.\n".utf8))
        code = ExitCode.modelUnavailable.rawValue
    }
    #else
    FileHandle.standardError.write(Data("MCP indisponible : FoundationModels absent sur cette plateforme.\n".utf8))
    code = ExitCode.modelUnavailable.rawValue
    #endif
case "proxy":
    let port = parsePort(args)
    let host = parseFlag(args, "--host") ?? "127.0.0.1"
    let token = parseFlag(args, "--token") ?? ProcessInfo.processInfo.environment["FB_TOKEN"]
    if let sep = args.firstIndex(of: "--"), sep + 1 < args.count {
        let childArgv = Array(args[(sep + 1)...])
        print("FoundationBridge — proxy local http://\(host):\(port) → \(childArgv.joined(separator: " "))")
        code = await runProxy(host: host, port: port, token: token, childArgv: childArgv)
    } else {
        FileHandle.standardError.write(Data("Usage : foundationbridge proxy [--port N] [--host H] [--token T] -- <commande> [args...]\n".utf8))
        code = ExitCode.invalidInput.rawValue
    }
case "acp":
    // stdout est reserve au JSON-RPC ; tout diagnostic part sur stderr.
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let server = ACPServer(backend: FoundationModelsGenerator())
        FileHandle.standardError.write(Data("FoundationBridge ACP (stdio) pret.\n".utf8))
        await server.runStdio()
    } else {
        FileHandle.standardError.write(Data("ACP indisponible : macOS 26 requis.\n".utf8))
        code = ExitCode.modelUnavailable.rawValue
    }
    #else
    FileHandle.standardError.write(Data("ACP indisponible : FoundationModels absent sur cette plateforme.\n".utf8))
    code = ExitCode.modelUnavailable.rawValue
    #endif
case "help", "--help", "-h":
    printUsage()
default:
    printUsage()
    code = ExitCode.invalidInput.rawValue
}

exit(code)
