import SwiftUI

// MARK: - Game Target Selector

enum GameTarget: String, CaseIterable, Identifiable {
    case ff    = "Free Fire"
    case ffmax = "Free Fire MAX"
    case epep  = "EPEP"
    var id: String { rawValue }

    var bundleID: String {
        switch self {
        case .ff:    return "com.dts.freefireth"
        case .ffmax: return "com.dts.freefiremax"
        case .epep:  return "com.garena.smba"
        }
    }

    var icon: String {
        switch self {
        case .ff:    return "gamecontroller.fill"
        case .ffmax: return "sparkles"
        case .epep:  return "scope"
        }
    }

    /// Games shown in the AIMBOT/inject menu (no EPEP there)
    static var aimbotCases: [GameTarget] { [.ff, .ffmax] }
}

// MARK: - Inject Menu View (AIMBOT)

struct InjectMenuView: View {
    @State private var selectedGame: GameTarget = .ff
    @State private var results: [UUID: InjectResult] = [:]
    @State private var working: UUID? = nil
    @State private var progress: [UUID: Double] = [:]
    @State private var consoleLogs: [String] = []
    // ESP state — metode ESP OB55
    @State private var selectedESP: ESPMethod = .full
    @ObservedObject private var espManager = ESPManager.shared

    // Base buttons — bundleID will be overridden at inject time from selectedGame
    let baseButtons: [InjectButton] = [
        InjectButton(
            name: "AIMNECK",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimneck"
        ),
        InjectButton(
            name: "AIMDRAG",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            // Fixed: was pointing to a directory — now points to the actual file inside avatar/
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D",
            resourceFileName: "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D",
            resourceSubfolder: "patches/aimdrag"
        ),
        InjectButton(
            name: "AIMBODY",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimbody"
        ),
    ]

    // MARK: - ESP Buttons (OB55)
    // Setiap metode ESP = 1 button file-patch.
    // Taruh file mod kamu di folder yang sesuai, contoh:
    // patches/esp-line/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D
    // patches/esp-full/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D
    // NOTE: pakai `let` (bukan computed) agar UUID stabil antar render.
    let espBaseButtons: [InjectButton] = [
        InjectButton(
            name: "ESP LINE",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-line"
        ),
        InjectButton(
            name: "ESP BOX",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-box"
        ),
        InjectButton(
            name: "ESP HEALTH",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-health"
        ),
        InjectButton(
            name: "ESP NAME",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-name"
        ),
        InjectButton(
            name: "ESP DISTANCE",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-distance"
        ),
        InjectButton(
            name: "ESP FULL",
            category: "ESP",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/esp-full"
        ),
    ]

    /// Mapping button ESP -> ESPMethod untuk apply config overlay.
    private func espMethod(for button: InjectButton) -> ESPMethod? {
        switch button.resourceSubfolder {
        case "patches/esp-line": return .line
        case "patches/esp-box": return .box
        case "patches/esp-health": return .health
        case "patches/esp-name": return .name
        case "patches/esp-distance": return .distance
        case "patches/esp-full": return .full
        default: return nil
        }
    }

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            consoleLogs.append("[\(ts)] \(msg)")
            if consoleLogs.count > 40 { consoleLogs.removeFirst() }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {

                            // MARK: Game Selector
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("TARGET GAME")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                HStack(spacing: 10) {
                                    ForEach(GameTarget.aimbotCases) { game in
                                        Button {
                                            selectedGame = game
                                            // Reset results when switching game
                                            results = [:]
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: game.icon)
                                                    .font(.system(size: 11))
                                                Text(game.rawValue)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 38)
                                            .foregroundStyle(selectedGame == game ? .white : Color(white: 0.55))
                                            .background(
                                                selectedGame == game
                                                    ? AppTheme.accent
                                                    : Color(white: 0.12)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(
                                                        selectedGame == game ? AppTheme.accent : Color(white: 0.2),
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)

                                // Show active bundleID
                                Text("Target: \(selectedGame.bundleID)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.35))
                                    .padding(.horizontal, 16)
                            }

                            // MARK: Inject Buttons
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("AIMBOT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                VStack(spacing: 10) {
                                    ForEach(baseButtons) { button in
                                        InjectButtonCard(
                                            button: button,
                                            result: results[button.id],
                                            isWorking: working == button.id,
                                            progress: progress[button.id] ?? 0
                                        ) {
                                            // Inject with selected game's bundleID
                                            var targeted = button
                                            targeted = InjectButton(
                                                name: button.name,
                                                category: button.category,
                                                bundleID: selectedGame.bundleID,
                                                targetPath: button.targetPath,
                                                resourceFileName: button.resourceFileName,
                                                resourceSubfolder: button.resourceSubfolder,
                                                launchAfterInject: button.launchAfterInject
                                            )
                                            injectDynamic(original: button, targeted: targeted)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            // MARK: ESP Method Picker (OB55)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("ESP METHOD — OB55")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                // Grid picker 3 kolom
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(ESPMethod.allCases) { method in
                                        Button {
                                            selectedESP = method
                                            espManager.apply(method: method)
                                            log("ESP method -> \(method.title) (\(method.desc))")
                                        } label: {
                                            VStack(spacing: 6) {
                                                Image(systemName: method.icon)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(selectedESP == method ? .white : AppTheme.accent)
                                                Text(method.rawValue)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(selectedESP == method ? .white : Color(white: 0.7))
                                                Text(method.desc)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(selectedESP == method ? .white.opacity(0.8) : Color(white: 0.4))
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.7)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 78)
                                            .background(selectedESP == method ? AppTheme.accent : Color(white: 0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(selectedESP == method ? AppTheme.accent : Color(white: 0.15), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)

                                Text("Aktif: \(selectedESP.title) • ViewMatrix 0xE8 • Camera 0xC8 • IsVisible 0x31 • Name 0x2DC")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.4))
                                    .padding(.horizontal, 16)
                            }

                            // MARK: ESP Buttons
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("ESP")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                VStack(spacing: 10) {
                                    ForEach(espBaseButtons) { button in
                                        InjectButtonCard(
                                            button: button,
                                            result: results[button.id],
                                            isWorking: working == button.id,
                                            progress: progress[button.id] ?? 0
                                        ) {
                                            if let m = espMethod(for: button) {
                                                selectedESP = m
                                                espManager.apply(method: m)
                                            }
                                            let targeted = InjectButton(
                                                name: button.name,
                                                category: button.category,
                                                bundleID: selectedGame.bundleID,
                                                targetPath: button.targetPath,
                                                resourceFileName: button.resourceFileName,
                                                resourceSubfolder: button.resourceSubfolder,
                                                launchAfterInject: button.launchAfterInject
                                            )
                                            log("ESP \(button.name) [\(selectedGame.rawValue)] metode=\(selectedESP.rawValue)")
                                            injectDynamic(original: button, targeted: targeted)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                Text("Butuh file di bundle: patches/esp-*/cache_res... • Offset: DictionaryEntities 0xC0, Avatar_IsVisible 0x31, Bones Head 0x458")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.35))
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    }

                    ConsoleView(logs: consoleLogs)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Menu")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(selectedGame.rawValue)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
        }
    }

    private func injectDynamic(original: InjectButton, targeted: InjectButton) {
        guard working != original.id else { return }

        let resourceURL: URL? = {
            let bundleBase = URL(fileURLWithPath: Bundle.main.bundlePath)
            let subfolderPath = bundleBase
                .appendingPathComponent(targeted.resourceSubfolder)
                .appendingPathComponent(targeted.resourceFileName)
            if FileManager.default.fileExists(atPath: subfolderPath.path) {
                return subfolderPath
            }
            let rootPath = bundleBase.appendingPathComponent(targeted.resourceFileName)
            return FileManager.default.fileExists(atPath: rootPath.path) ? rootPath : nil
        }()

        guard let resourceURL else {
            results[original.id] = .failed("File not found in bundle")
            log("\(targeted.name) [\(selectedGame.rawValue)] — inject error: file not found")
            return
        }

        working = original.id
        results[original.id] = .working
        progress[original.id] = 0

        let id = original.id
        let startTime = Date()
        let duration: Double = 5.0
        let gameName = selectedGame.rawValue

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let pct = min(elapsed / duration, 1.0)
            DispatchQueue.main.async { progress[id] = pct }
            if pct >= 1.0 { timer.invalidate() }
        }

        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            do {
                let containerURL = try resolveContainer(bundleID: targeted.bundleID)
                let targetURL = containerURL.appendingPathComponent(targeted.targetPath)
                let dir = targetURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                // Verify targetURL is a file path, not a directory
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue {
                    throw InjectError.renameFailed("target is a directory")
                }
                let data = try Data(contentsOf: resourceURL)
                let staging = dir.appendingPathComponent(".kxteam-inject-\(UUID().uuidString)")
                try data.write(to: staging, options: .atomic)
                let renameResult = rename(staging.path, targetURL.path)
                if renameResult != 0 {
                    let errMsg = String(cString: strerror(errno))
                    try? FileManager.default.removeItem(at: staging)
                    throw InjectError.renameFailed(errMsg)
                }
                await MainActor.run {
                    results[id] = .success
                    progress[id] = 1.0
                    working = nil
                    log("\(targeted.name) [\(gameName)] — apply success")
                }
            } catch {
                await MainActor.run {
                    results[id] = .failed(error.localizedDescription)
                    working = nil
                    log("\(targeted.name) [\(gameName)] — inject error: \(error.localizedDescription)")
                }
            }
        }
    }
}
