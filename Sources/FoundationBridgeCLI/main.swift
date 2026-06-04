import Foundation
import FoundationBridgeCore
import FoundationModelsBackend
import FoundationBridgeServer

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
      serve [--port N]     Demarre le serveur HTTP (REST OpenAI + Anthropic)
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

func readStdin() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

func parsePort(_ args: [String]) -> Int {
    if let i = args.firstIndex(of: "--port"), i + 1 < args.count, let p = Int(args[i + 1]) {
        return p
    }
    return 8080
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
case "serve":
    let port = parsePort(args)
    do {
        print("FoundationBridge — serveur HTTP sur http://127.0.0.1:\(port)")
        print("  GET  /healthz")
        print("  GET  /v1/models")
        print("  POST /v1/chat/completions   (OpenAI)")
        print("  POST /v1/messages           (Anthropic)")
        try await FoundationBridgeServer.makeApplication(config: .init(port: port)).runService()
    } catch {
        FileHandle.standardError.write(Data((String(describing: error) + "\n").utf8))
        code = ExitCode.genericError.rawValue
    }
case "help", "--help", "-h":
    printUsage()
default:
    printUsage()
    code = ExitCode.invalidInput.rawValue
}

exit(code)
