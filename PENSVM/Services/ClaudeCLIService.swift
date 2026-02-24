import Foundation
import AppKit

enum ClaudeCLIError: LocalizedError {
    case invalidImage
    case cliNotFound
    case executionError(String)
    case invalidResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process image."
        case .cliNotFound:
            return "Claude CLI not found. Ensure it is installed."
        case .executionError(let message):
            return "CLI error: \(message)"
        case .invalidResponse:
            return "Could not parse response."
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

class ClaudeCLIService {
    // MARK: - Singleton
    static let shared = ClaudeCLIService()

    // MARK: - Persistent Process Management
    private var persistentProcess: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var outputBuffer: Data = Data()
    private let outputQueue = DispatchQueue(label: "com.pensvm.claude.output")
    private var pendingContinuation: CheckedContinuation<String, Error>?

    private let fileManager = FileManager.default

    /// Resolves Claude CLI path in order of preference:
    /// 1. ~/.local/bin/claude (native binary - recommended)
    /// 2. ~/.bun/bin/claude (bun install)
    /// 3. nvm node bin path (legacy npm install)
    /// 4. /usr/local/bin/claude (fallback)
    private var claudePath: String {
        let candidates = [
            NSHomeDirectory() + "/.local/bin/claude",           // Native binary
            NSHomeDirectory() + "/.bun/bin/claude",             // Bun install
            nvmClaudePath,                                       // Legacy npm via nvm
            "/usr/local/bin/claude"                              // System fallback
        ]

        return candidates.first { fileManager.fileExists(atPath: $0) } ?? candidates[0]
    }

    private var nvmNodeBinPath: String {
        let nvmDir = NSHomeDirectory() + "/.nvm/versions/node"
        guard let versions = try? fileManager.contentsOfDirectory(atPath: nvmDir) else {
            return ""
        }
        let latest = versions
            .filter { $0.hasPrefix("v") }
            .sorted { v1, v2 in
                let clean1 = v1.dropFirst().split(separator: ".").compactMap { Int($0) }
                let clean2 = v2.dropFirst().split(separator: ".").compactMap { Int($0) }
                for (a, b) in zip(clean1, clean2) {
                    if a != b { return a > b }
                }
                return clean1.count > clean2.count
            }
            .first

        if let latest = latest {
            return "\(nvmDir)/\(latest)/bin"
        }
        return ""
    }

    private var nvmClaudePath: String {
        let binPath = nvmNodeBinPath
        return binPath.isEmpty ? "" : "\(binPath)/claude"
    }

    // MARK: - Persistent Service Lifecycle

    /// Starts the persistent Claude CLI service with streaming JSON mode
    func startPersistentService() {
        guard persistentProcess == nil else {
            print("🔄 Persistent service already running")
            return
        }

        guard fileManager.fileExists(atPath: claudePath) else {
            print("❌ Claude CLI not found at \(claudePath)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose"
        ]

        // Set environment
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let nvmBin = nvmNodeBinPath
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:\(NSHomeDirectory())/.bun/bin:\(nvmBin):\(currentPath)"
        process.environment = env

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        stdin = inputPipe.fileHandleForWriting
        stdout = outputPipe.fileHandleForReading

        // Set up async reading from stdout
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            self?.outputQueue.async {
                self?.outputBuffer.append(data)
                self?.processOutputBuffer()
            }
        }

        do {
            try process.run()
            persistentProcess = process
            print("✅ Persistent Claude CLI service started")
        } catch {
            print("❌ Failed to start persistent service: \(error)")
        }
    }

    /// Stops the persistent Claude CLI service
    func stopPersistentService() {
        guard let process = persistentProcess else { return }

        stdout?.readabilityHandler = nil
        stdin = nil
        stdout = nil

        process.terminate()
        persistentProcess = nil
        outputBuffer = Data()
        print("🛑 Persistent Claude CLI service stopped")
    }

    /// Process the output buffer looking for complete JSON messages
    private func processOutputBuffer() {
        // Look for newline-delimited JSON messages
        while let newlineIndex = outputBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let messageData = outputBuffer.prefix(upTo: newlineIndex)
            outputBuffer = Data(outputBuffer.suffix(from: outputBuffer.index(after: newlineIndex)))

            guard !messageData.isEmpty,
                  let _ = String(data: messageData, encoding: .utf8) else {
                continue
            }

            // Parse the JSON message
            guard let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
                continue
            }

            // Check for result message type
            if let type = json["type"] as? String {
                if type == "result" {
                    if let result = json["result"] as? String {
                        DispatchQueue.main.async { [weak self] in
                            self?.pendingContinuation?.resume(returning: result)
                            self?.pendingContinuation = nil
                        }
                    } else if let subtype = json["subtype"] as? String, subtype == "error_response" {
                        let errorMsg = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                        DispatchQueue.main.async { [weak self] in
                            self?.pendingContinuation?.resume(throwing: ClaudeCLIError.executionError(errorMsg))
                            self?.pendingContinuation = nil
                        }
                    }
                }
            }
        }
    }

    // Automatically use mock data in Debug builds, real AI in Release
    #if DEBUG
    private let useDebugData = true
    #else
    private let useDebugData = false
    #endif

    private let debugJSON = """
    {"sentences":[{"parts":[{"type":"text","content":"Iūlius et Aemilia in "},{"type":"gap","stem":"vīll","correctEnding":"ā","dictionaryForm":"vīlla","wordType":"noun (1st decl)"},{"type":"text","content":" "},{"type":"gap","stem":"habit","correctEnding":"ant","dictionaryForm":"habitāre","wordType":"verb (1st conj)"},{"type":"text","content":" cum "},{"type":"gap","stem":"līber","correctEnding":"īs","dictionaryForm":"līberī","wordType":"noun (2nd decl)"},{"type":"text","content":" et "},{"type":"gap","stem":"serv","correctEnding":"īs","dictionaryForm":"servus","wordType":"noun (2nd decl)"},{"type":"text","content":"."}]},{"parts":[{"type":"text","content":"Dominus "},{"type":"gap","stem":"mult","correctEnding":"ōs","dictionaryForm":"multus","wordType":"adj (1st/2nd decl)"},{"type":"text","content":" "},{"type":"gap","stem":"serv","correctEnding":"ōs","dictionaryForm":"servus","wordType":"noun (2nd decl)"},{"type":"text","content":" et "},{"type":"gap","stem":"mult","correctEnding":"ās","dictionaryForm":"multus","wordType":"adj (1st/2nd decl)"},{"type":"text","content":" "},{"type":"gap","stem":"ancill","correctEnding":"ās","dictionaryForm":"ancilla","wordType":"noun (1st decl)"},{"type":"text","content":" habet."}]},{"parts":[{"type":"text","content":"Aemilia in "},{"type":"gap","stem":"peristȳl","correctEnding":"ō","dictionaryForm":"peristȳlum","wordType":"noun (2nd decl)"},{"type":"text","content":" est cum "},{"type":"gap","stem":"Mārc","correctEnding":"ō","dictionaryForm":"Mārcus","wordType":"noun (2nd decl)"},{"type":"text","content":" et "},{"type":"gap","stem":"Quīnt","correctEnding":"ō","dictionaryForm":"Quīntus","wordType":"noun (2nd decl)"},{"type":"text","content":" et "},{"type":"gap","stem":"Iūli","correctEnding":"ā","dictionaryForm":"Iūlia","wordType":"noun (1st decl)"},{"type":"text","content":"."}]}]}
    """

    private let jsonSchema = """
    {
      "type": "object",
      "properties": {
        "sentences": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "parts": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "type": { "type": "string", "enum": ["text", "gap"] },
                    "content": { "type": "string" },
                    "stem": { "type": "string" },
                    "correctEnding": { "type": "string" },
                    "dictionaryForm": { "type": "string" },
                    "wordType": { "type": "string" },
                    "genitiveForm": { "type": "string" },
                    "gender": { "type": "string" }
                  },
                  "required": ["type"]
                }
              }
            },
            "required": ["parts"]
          }
        }
      },
      "required": ["sentences"]
    }
    """

    private func buildPrompt(imagePath: String) -> String {
        return """
        Read the image at \(imagePath). This is a PENSVM A Latin exercise from "Lingua Latina per se Illustrata".

        In these exercises, INCOMPLETE WORDS end with a HYPHEN/DASH "-" character.
        Examples: "vīll-", "habit-", "līber-", "serv-", "mult-", "ancill-"

        YOUR TASK:
        1. Find every word that ends with "-" (hyphen)
        2. The STEM is the COMPLETE text before the hyphen (e.g., "habit" from "habit-", "līber" from "līber-")
        3. Determine the CORRECT ENDING based on Latin grammar
        4. Words WITHOUT a hyphen are complete text
        5. For EACH gap, provide the DICTIONARY FORM and WORD TYPE

        STEM RULES (VERY IMPORTANT):
        - The stem is ALL characters before the hyphen, as one unit
        - NEVER split a stem into multiple parts
        - "habit-" → stem is "habit" (NOT "habi" + "t")
        - "līber-" → stem is "līber" (NOT "lībe" + "r")
        - "serv-" → stem is "serv" (NOT "ser" + "v")

        DICTIONARY FORM RULES:
        - For VERBS: use the infinitive (e.g., "habitāre", "esse", "habēre")
        - For NOUNS: use nominative singular (e.g., "vīlla", "servus", "puer")
        - For ADJECTIVES: use nominative singular masculine (e.g., "multus", "bonus")
        - For PROPER NOUNS: use nominative singular (e.g., "Mārcus", "Iūlia")

        WORD TYPE VALUES:
        - "verb (1st conj)", "verb (2nd conj)", "verb (3rd conj)", "verb (4th conj)", "verb (irreg)"
        - "noun (1st decl)", "noun (2nd decl)", "noun (3rd decl)", "noun (4th decl)", "noun (5th decl)"
        - "adj (1st/2nd decl)", "adj (3rd decl)"
        - "proper noun"

        SENTENCE SPLITTING:
        - Each Latin sentence (ending with ".") should be a SEPARATE object in the "sentences" array

        EXAMPLE INPUT: "Iūlius in vīll- habitat."
        EXAMPLE OUTPUT:
        {
          "sentences": [
            {
              "parts": [
                {"type": "text", "content": "Iūlius in "},
                {"type": "gap", "stem": "vīll", "correctEnding": "ā", "dictionaryForm": "vīlla", "wordType": "noun (1st decl)", "genitiveForm": "vīllae", "gender": "f"},
                {"type": "text", "content": " habitat."}
              ]
            }
          ]
        }

        CRITICAL RULES:
        - The stem must be the COMPLETE word before the hyphen - never split it
        - Use macrons (ā, ē, ī, ō, ū) in correctEnding when appropriate
        - EACH sentence ending with "." must be a SEPARATE object
        - ALWAYS include dictionaryForm and wordType for each gap
        - ALWAYS include genitiveForm (full genitive form, e.g. "insulae", "servī", "pāstōris") and gender ("f", "m", or "n") for noun/adjective gaps
        """
    }

    func parseExercise(from imageData: Data) async throws -> Exercise {
        // DEBUG MODE: Return mock data instantly
        if useDebugData {
            print("🔧 DEBUG MODE: Using mock data")
            return try parseDebugJSON()
        }

        // 1. Save image to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")

        do {
            try imageData.write(to: tempURL)
        } catch {
            throw ClaudeCLIError.invalidImage
        }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // 2. Check if CLI exists
        guard FileManager.default.fileExists(atPath: claudePath) else {
            throw ClaudeCLIError.cliNotFound
        }

        // 3. Build and run the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "-p", buildPrompt(imagePath: tempURL.path),
            "--output-format", "json",
            "--json-schema", jsonSchema,
            "--allowedTools", "Read",
            "--no-session-persistence"
        ]

        // Ensure Claude CLI and Node.js paths are in PATH
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let nvmBin = nvmNodeBinPath
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:\(NSHomeDirectory())/.bun/bin:\(nvmBin):\(currentPath)"
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ClaudeCLIError.executionError(error.localizedDescription)
        }

        // Wait for process to complete
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ClaudeCLIError.executionError(errorMessage)
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ClaudeCLIError.invalidResponse
        }

        print("📝 Claude CLI Response:")
        print(output)
        print("---")

        return try parseResponse(output)
    }

    private func parseResponse(_ output: String) throws -> Exercise {
        guard let data = output.data(using: .utf8) else {
            throw ClaudeCLIError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCLIError.parseError("Could not parse JSON")
        }

        // Claude CLI returns structured_output when using --json-schema
        guard let structuredOutput = json["structured_output"] as? [String: Any],
              let sentencesJson = structuredOutput["sentences"] as? [[String: Any]] else {
            // Fallback: try to parse from result field if structured_output is missing
            if let result = json["result"] as? String,
               let resultData = result.data(using: .utf8),
               let resultJson = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
               let sentences = resultJson["sentences"] as? [[String: Any]] {
                return try parseSentences(sentences)
            }
            throw ClaudeCLIError.parseError("Missing structured_output in response")
        }

        print("✅ Found \(sentencesJson.count) sentences")

        // Debug: Print each sentence's parts
        for (i, sentence) in sentencesJson.enumerated() {
            print("📖 Sentence \(i + 1):")
            if let parts = sentence["parts"] as? [[String: Any]] {
                for part in parts {
                    if let type = part["type"] as? String {
                        if type == "text", let content = part["content"] as? String {
                            print("   TEXT: \"\(content)\"")
                        } else if type == "gap", let stem = part["stem"] as? String, let ending = part["correctEnding"] as? String {
                            print("   GAP: stem=\"\(stem)\" ending=\"\(ending)\"")
                        }
                    }
                }
            }
        }

        return try parseSentences(sentencesJson)
    }

    private func parseSentences(_ sentencesJson: [[String: Any]]) throws -> Exercise {
        let sentences = try sentencesJson.map { sentenceJson -> Sentence in
            guard let partsJson = sentenceJson["parts"] as? [[String: Any]] else {
                throw ClaudeCLIError.invalidResponse
            }

            let parts = try partsJson.map { partJson -> SentencePart in
                guard let type = partJson["type"] as? String else {
                    throw ClaudeCLIError.invalidResponse
                }

                if type == "text" {
                    guard let content = partJson["content"] as? String else {
                        throw ClaudeCLIError.invalidResponse
                    }
                    return .text(content)
                } else if type == "gap" {
                    guard let stem = partJson["stem"] as? String,
                          let correctEnding = partJson["correctEnding"] as? String else {
                        throw ClaudeCLIError.invalidResponse
                    }
                    let dictionaryForm = partJson["dictionaryForm"] as? String
                    let wordType = partJson["wordType"] as? String
                    let genitiveForm = partJson["genitiveForm"] as? String
                    let gender = partJson["gender"] as? String
                    return .gap(Gap(stem: stem, correctEnding: correctEnding, dictionaryForm: dictionaryForm, wordType: wordType, genitiveForm: genitiveForm, gender: gender))
                } else {
                    throw ClaudeCLIError.invalidResponse
                }
            }

            return Sentence(parts: parts)
        }

        return Exercise(sentences: sentences)
    }

    private func parseDebugJSON() throws -> Exercise {
        guard let data = debugJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sentencesJson = json["sentences"] as? [[String: Any]] else {
            throw ClaudeCLIError.parseError("Invalid debug JSON")
        }
        return try parseSentences(sentencesJson)
    }

    // MARK: - Translation

    func translateSentence(_ latinText: String) async throws -> String {
        // DEBUG MODE: Return mock translation
        if useDebugData {
            print("🔧 DEBUG MODE: Using mock translation")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay to simulate
            return "In Italy there are many villas."
        }

        // Check if CLI exists
        guard FileManager.default.fileExists(atPath: claudePath) else {
            throw ClaudeCLIError.cliNotFound
        }

        let prompt = """
        Translate this Latin sentence to English. Provide only the translation, nothing else.
        Be literal and exact. Do not add explanations or notes.

        Latin: \(latinText)
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "-p", prompt,
            "--output-format", "json",
            "--no-session-persistence"
        ]

        // Ensure Claude CLI and Node.js paths are in PATH
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let nvmBin = nvmNodeBinPath
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:\(NSHomeDirectory())/.bun/bin:\(nvmBin):\(currentPath)"
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ClaudeCLIError.executionError(error.localizedDescription)
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        print("🔧 Claude CLI path: \(claudePath)")
        print("🔧 Exit status: \(process.terminationStatus)")

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ CLI stderr: \(errorMessage)")
            throw ClaudeCLIError.executionError(errorMessage)
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ClaudeCLIError.invalidResponse
        }

        print("📝 Translation response: \(output)")

        // Parse JSON response to extract result
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCLIError.parseError("Could not parse JSON response")
        }

        print("📦 JSON keys: \(json.keys)")

        guard let result = json["result"] as? String else {
            throw ClaudeCLIError.parseError("Missing 'result' field in response. Keys: \(json.keys)")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
