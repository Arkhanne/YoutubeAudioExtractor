import SwiftUI

struct ContentView: View {
    @State private var urlText = ""
    @State private var appState: AppState = .idle

    enum AppState {
        case idle
        case extracting(ExtractionProgress?)
        case success(String)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 14) {
            if case .success = appState { } else {
                HStack(spacing: 8) {
                    TextField("URL de YouTube", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isExtracting)
                        .onSubmit { extract() }

                    Button("Extraer") { extract() }
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isExtracting)
                        .buttonStyle(.borderedProminent)
                }
            }

            Group {
                switch appState {
                case .idle:
                    Color.clear.frame(height: 16)

                case .extracting(let progress):
                    statusText(for: progress)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .success(let dir):
                    successView(dir)

                case .error(let msg):
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity)
                }
            }
            .animation(.default, value: isExtracting)
        }
        .padding(20)
        .frame(width: 440)
    }

    // MARK: - Subvistas

    @ViewBuilder
    private func statusText(for progress: ExtractionProgress?) -> some View {
        let label: String = {
            switch progress {
            case .downloading: return "Descargando audio…"
            case .converting:  return "Convirtiendo a MP3…"
            case nil:          return "Iniciando…"
            }
        }()
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func successView(_ dir: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Audio extraído correctamente")
                .font(.headline)

            Text(dir)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button("Cerrar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.return)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Lógica

    private var isExtracting: Bool {
        if case .extracting = appState { return true }
        return false
    }

    private func extract() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        appState = .extracting(nil)

        Task {
            do {
                let savedDir = try await AudioExtractor.extract(url: url) { prog in
                    Task { @MainActor in appState = .extracting(prog) }
                }
                await MainActor.run { appState = .success(savedDir) }
            } catch {
                await MainActor.run { appState = .error(error.localizedDescription) }
            }
        }
    }
}
