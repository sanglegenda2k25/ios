import SwiftUI

// MARK: - Security Menu View

struct SecurityMenuView: View {
    @State private var selectedGame: GameTarget = .ff
    @State private var results: [UUID: InjectResult] = [:]
    @State private var working: UUID? = nil
    @State private var progress: [UUID: Double] = [:]
    @State private var consoleLogs: [String] = []

    // Cleanup state
    @State private var isCleaningUp = false
    @State private var cleanupResult: CleanupResult? = nil
    @State private var showCleanupConfirm = false

    enum CleanupResult {
        case success(Int, String)   // filesRemoved, sizeSaved
        case failed(String)
        case nothingFound
    }

    let baseButtons: [InjectButton] = [
        InjectButton(
            name: "BYPASS ANTICHEAT",
            category: "SECURITY",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/Bypass anticheats"
        ),
    ]

    /// Paths (relative to app container) to delete during cleanup.
    /// These are the cheat asset directories + caches that could trigger anticheat.
    private var cleanupPaths: [String] {
        [
            // Injected cheat asset cache
            "Documents/contentcache/Compulsory/ios/gameassetbundles",
            // General contentcache (re-downloaded fresh on next launch)
            "Documents/contentcache",
            // System cache
            "Library/Caches",
            // Tmp leftovers
            "tmp",
        ]
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
                                            results = [:]
                                            cleanupResult = nil
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

                                Text("Target: \(selectedGame.bundleID)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.35))
                                    .padding(.horizontal, 16)
                            }

                            // MARK: Inject Buttons
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("SECURITY")
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
                                            let targeted = InjectButton(
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

                            // MARK: Cleanup Section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("CLEANUP")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                VStack(spacing: 10) {
                                    // Cleanup result banner
                                    if let result = cleanupResult {
                                        HStack(spacing: 8) {
                                            switch result {
                                            case .success(let count, let size):
                                                Image(systemName: "checkmark.shield.fill")
                                                    .foregroundStyle(.green)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text("Cleanup selesai")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                    Text("\(count) item dihapus · \(size) freed")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(Color(white: 0.5))
                                                }
                                            case .nothingFound:
                                                Image(systemName: "checkmark.shield")
                                                    .foregroundStyle(AppTheme.accent)
                                                Text("Tidak ada file cheat/cache ditemukan")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color(white: 0.6))
                                            case .failed(let msg):
                                                Image(systemName: "xmark.octagon.fill")
                                                    .foregroundStyle(.red)
                                                Text(msg)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color(white: 0.6))
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color(white: 0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color(white: 0.15), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 16)
                                    }

                                    // Cleanup Button
                                    Button {
                                        showCleanupConfirm = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            if isCleaningUp {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .scaleEffect(0.8)
                                                    .tint(.white)
                                                Text("Membersihkan...")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(.white)
                                            } else {
                                                Image(systemName: "trash.fill")
                                                    .font(.system(size: 14))
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text("Cleanup Cheats Cache")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.white)
                                                    Text("Hapus file injeksi + cache \(selectedGame.rawValue)")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(Color(white: 0.6))
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color(white: 0.4))
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(white: 0.12), Color(white: 0.08)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(isCleaningUp ? AppTheme.accent.opacity(0.5) : Color(white: 0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isCleaningUp)
                                    .padding(.horizontal, 16)

                                    // Info footer
                                    Text("Menghapus contentcache, cheat asset yang ter-inject, Library/Caches, dan file tmp agar terhindar dari deteksi anticheat.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(white: 0.35))
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 24)
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
                        Text("Security")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(selectedGame.rawValue)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .confirmationDialog(
                "Cleanup \(selectedGame.rawValue)?",
                isPresented: $showCleanupConfirm,
                titleVisibility: .visible
            ) {
                Button("Cleanup Sekarang", role: .destructive) {
                    runCleanup()
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Ini akan menghapus contentcache, cheat files, dan cache dari \(selectedGame.rawValue). Game harus download ulang asset saat dibuka kembali.")
            }
        }
    }

    // MARK: - Cleanup Logic

    private func runCleanup() {
        guard !isCleaningUp else { return }
        isCleaningUp = true
        cleanupResult = nil
        log("cleanup [\(selectedGame.rawValue)] — mulai...")

        let bundleID = selectedGame.bundleID
        let gameName = selectedGame.rawValue
        let paths = cleanupPaths

        Task.detached(priority: .userInitiated) {
            do {
                let containerURL = try resolveContainer(bundleID: bundleID)
                let fm = FileManager.default
                var removedCount = 0
                var totalBytes: Int64 = 0

                for relativePath in paths {
                    let url = containerURL.appendingPathComponent(relativePath)
                    guard fm.fileExists(atPath: url.path) else { continue }

                    // Calculate size before deleting
                    if let attrs = try? fm.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        totalBytes += size
                    }
                    // For directories, sum content size
                    if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                        for case let fileURL as URL in enumerator {
                            if let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let sz = res.fileSize {
                                totalBytes += Int64(sz)
                            }
                            removedCount += 1
                        }
                    } else {
                        removedCount += 1
                    }

                    do {
                        try fm.removeItem(at: url)
                        await MainActor.run {
                            log("cleanup — deleted: \(relativePath)")
                        }
                    } catch {
                        await MainActor.run {
                            log("cleanup — skip \(relativePath): \(error.localizedDescription)")
                        }
                    }
                }

                let sizeStr = Self.formatBytes(totalBytes)
                await MainActor.run {
                    isCleaningUp = false
                    if removedCount == 0 {
                        cleanupResult = .nothingFound
                        log("cleanup [\(gameName)] — tidak ada file ditemukan")
                    } else {
                        cleanupResult = .success(removedCount, sizeStr)
                        log("cleanup [\(gameName)] — selesai: \(removedCount) item, \(sizeStr) freed")
                    }
                }
            } catch {
                await MainActor.run {
                    isCleaningUp = false
                    cleanupResult = .failed(error.localizedDescription)
                    log("cleanup [\(gameName)] — error: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1   { return String(format: "%.1f GB", gb) }
        if mb >= 1   { return String(format: "%.1f MB", mb) }
        if kb >= 1   { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }

    // MARK: - Inject Logic

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
