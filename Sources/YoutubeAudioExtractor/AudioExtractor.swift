import Foundation

enum AudioExtractorError: LocalizedError {
    case binaryNotFound(String)
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "'\(name)' no encontrado en el bundle de la app."
        case .extractionFailed(let msg):
            return msg.isEmpty ? "Error en la extracción. Comprueba la URL e inténtalo de nuevo." : msg
        }
    }
}

enum ExtractionProgress: Equatable {
    case downloading(Double)  // 0.0 – 1.0
    case converting
}

enum AudioExtractor {
    static func extract(
        url: String,
        onProgress: @escaping @Sendable (ExtractionProgress) -> Void
    ) async throws -> String {
        let outputDir = try prepareOutputDirectory()
        let ytdlp  = try bundledBinary(named: "yt-dlp")
        let ffmpeg = try bundledBinary(named: "ffmpeg")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlp)
        process.arguments = [
            "--ffmpeg-location", ffmpeg,
            "--format", "bestaudio",
            "--no-playlist",
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "-o", "\(outputDir)/%(title)s.%(ext)s",
            url,
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        // Cada línea de stdout se escribe al log en tiempo real desde la cola del handler
        let parser = LineParser(onProgress: onProgress, onLine: { line in
            Logger.log("[stdout] \(line)")
        })
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            parser.receive(data: data)
        }

        Logger.log("Iniciando extracción: \(url)")
        Logger.log("Argumentos: \(process.arguments!.joined(separator: " "))")

        try process.run()

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                // Primero anulamos el handler para que no haya más escrituras concurrentes
                stdoutPipe.fileHandleForReading.readabilityHandler = nil

                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""

                if !stderr.isEmpty {
                    Logger.log("--- stderr ---\n\(stderr)")
                }
                Logger.log("Código de salida: \(proc.terminationStatus)")

                guard proc.terminationStatus == 0 else {
                    let lines = stderr.split(separator: "\n").map(String.init)
                    let msg = lines.last(where: { $0.contains("ERROR") })
                        ?? lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                        ?? "Extraction failed"
                    Logger.log("ERROR: \(msg)")
                    continuation.resume(throwing: AudioExtractorError.extractionFailed(msg))
                    return
                }

                Logger.log("Extracción completada en: \(outputDir)")
                continuation.resume(returning: outputDir)
            }
        }
    }

    private static func prepareOutputDirectory() throws -> String {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let dir = desktop.appendingPathComponent("Youtube Audio")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    private static func bundledBinary(named name: String) throws -> String {
        guard let path = Bundle.main.path(forResource: name, ofType: nil) else {
            throw AudioExtractorError.binaryNotFound(name)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }
}

// MARK: - Logger

enum Logger {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        guard let logURL = logFileURL() else { return }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: logURL)
        }
    }

    private static func logFileURL() -> URL? {
        // Carpeta logs/ junto al .app
        let appDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let logsDir = appDir.appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        return logsDir.appendingPathComponent("extractor-\(dateStr).log")
    }
}

// MARK: - LineParser

private final class LineParser {
    private var buffer = ""
    private let onProgress: (ExtractionProgress) -> Void
    private let onLine: (String) -> Void

    init(onProgress: @escaping (ExtractionProgress) -> Void,
         onLine: @escaping (String) -> Void) {
        self.onProgress = onProgress
        self.onLine = onLine
    }

    func receive(data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        var lines = buffer.components(separatedBy: "\n")
        buffer = lines.removeLast()

        for line in lines {
            onLine(line)
            if line.contains("[download]"), let pct = percentage(from: line) {
                onProgress(.downloading(pct))
            } else if line.contains("[ffmpeg]") || line.contains("[ExtractAudio]") {
                onProgress(.converting)
            }
        }
    }

    private func percentage(from line: String) -> Double? {
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for part in parts {
            if part.hasSuffix("%"), let value = Double(part.dropLast()) {
                return min(value / 100.0, 1.0)
            }
        }
        return nil
    }
}
