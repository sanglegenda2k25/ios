import SwiftUI

// MARK: - Shared Models

struct InjectButton: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let bundleID: String
    let targetPath: String
    let resourceFileName: String
    let resourceSubfolder: String
    var launchAfterInject: Bool = false
}

struct OpenGameButton: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let urlSchemes: [String]
    let appStoreID: String
}

// MARK: - Shared Result & Error

enum InjectResult {
    case working
    case success
    case failed(String)
}

enum InjectError: LocalizedError {
    case containerNotFound(String)
    case renameFailed(String)
    var errorDescription: String? {
        switch self {
        case .containerNotFound(let id): return "App not found: \(id)"
        case .renameFailed(let reason): return "File replace failed: \(reason)"
        }
    }
}

// MARK: - Resolve container helper

func resolveContainer(bundleID: String) throws -> URL {
    if let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID) {
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    // Sebab sebenarnya, bukan sekadar "not found": tanpa identitas MHA
    // (build enterprise) atau sandbox escape aktif, container app lain
    // memang tidak bisa di-resolve dari sandbox.
    if Bundle.main.bundleIdentifier != "com.apple.mobile.MobileHouseArrest" {
        throw InjectError.containerNotFound("\(bundleID) — butuh build enterprise (identitas MHA). Build ini (\(Bundle.main.bundleIdentifier ?? "?")) tidak punya akses container.")
    }
    if KernelExploit.requiresSandboxEscape, !KernelExploit.hasSandboxAccess() {
        throw InjectError.containerNotFound("\(bundleID) — sandbox escape belum aktif. Jalankan exploit dari dashboard dulu.")
    }
    throw InjectError.containerNotFound(bundleID)
}

// MARK: - Shared Console View

struct ConsoleView: View {
    let logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7)
                    Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7)
                    Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7)
                }
                Text("CONSOLE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.3))
                    .kerning(1.5)
                Spacer()
                if !logs.isEmpty {
                    Text("\(logs.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(white: 0.055))

            // Divider
            Rectangle()
                .fill(AppTheme.accent.opacity(0.15))
                .frame(height: 0.5)

            // Log lines
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if logs.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.2))
                                Text("waiting for action...")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.2))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        } else {
                            ForEach(Array(logs.enumerated()), id: \.offset) { i, line in
                                ConsoleLogLine(index: i, text: line)
                                    .id(i)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: logs.count) { _ in
                    if let last = logs.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .frame(height: 120)
            .background(Color(white: 0.03))
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .overlay(
            Rectangle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

private struct ConsoleLogLine: View {
    let index: Int
    let text: String

    private var isSuccess: Bool { text.contains("success") || text.contains("selesai") }
    private var isError: Bool { text.contains("error") || text.contains("failed") || text.contains("skip") }

    private var lineColor: Color {
        if isSuccess { return Color.green.opacity(0.85) }
        if isError   { return Color.red.opacity(0.75) }
        return Color(white: 0.55)
    }

    private var prefixIcon: String {
        if isSuccess { return "✓" }
        if isError   { return "✗" }
        return "›"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(prefixIcon)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)
                .frame(width: 10)
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(lineColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .background(index % 2 == 0 ? Color.clear : Color(white: 0.025))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - Shared Inject Button Card

struct InjectButtonCard: View {
    let button: InjectButton
    let result: InjectResult?
    let isWorking: Bool
    let progress: Double
    let onTap: () -> Void

    @State private var pressed = false

    var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSuccess
                                ? [Color(white: 0.08), Color.green.opacity(0.08)]
                                : [Color(white: 0.10), Color(white: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if isWorking {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.04))
                }

                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Text(button.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        if isWorking {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.accent)
                        } else if isSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if isWorking {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(white: 0.08))
                                    .frame(height: 3)
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.accent.opacity(0.6), AppTheme.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progress, height: 3)
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSuccess ? Color.green.opacity(0.3)
                    : isWorking ? AppTheme.accent.opacity(0.4)
                    : Color(white: 0.13),
                    lineWidth: 1
                )
        )
        .shadow(
            color: isWorking ? AppTheme.accent.opacity(0.15) : Color.clear,
            radius: 12, x: 0, y: 4
        )
    }
}

// MARK: - OB55 Offsets (KRISHU X CHEATS — Updated 2026-09-18)
// Diterjemahkan dari offsets.h C++ ke Swift agar bisa dipakai langsung
// oleh menu inject (file-patch) dan oleh metode ESP overlay.
// JANGAN campur dengan kexploit/offsets.h (itu offset kernel iOS).

enum OB55Offsets {
    // Structural
    static let staticClass: UInt = 0x5C
    static let weapon: UInt = 0x600
    static let weaponData: UInt = 0xB0
    static let intWeaponType: UInt = 0x30
    static let weaponRecoil: UInt = 0xC
    static let noReload: UInt = 0x111
    static let followCamera: UInt = 0x450
    static let aimRotation: UInt = 0x400
    static let currentObserver: UInt = 0x110
    static let observerPlayer: UInt = 0xB8
    static let localPlayerAttributes: UInt = 0x4BC
    static let currentMatch: UInt = 0x90
    static let matchStatus: UInt = 0x60
    static let localPlayer: UInt = 0x18
    static let camera: UInt = 0xC8
    static let playerData: UInt = 0x90
    static let avatar: UInt = 0x128
    static let avatarManager: UInt = 0x48
    static let playerShadowBase: UInt = 0xA0
    static let avatarData: UInt = 0x30
    static let avatarDataIsTeam: UInt = 0x81
    static let avatarIsVisible: UInt = 0x31
    static let isFiring: UInt = 0x540
    static let dictionaryEntities: UInt = 0xC0

    // Player
    static let playerIsDead: UInt = 0x100
    static let playerName: UInt = 0x2DC
    static let xPose: UInt = 0x84
    static let aimbotVisible: UInt = 0x4A4
    static let playerAttributes: UInt = 0x4BC
    static let mainCameraTransform: UInt = 0x28
    static let viewMatrix: UInt = 0xE8
    static let inSnowSlideWayDashing: UInt = 0x2080
    static let playerID: UInt = 0x28
    static let baseProfileInfo: UInt = 0xB0
    static let isClientBot: UInt = 0x4A0
    static let runSpeedUpScale: UInt = 0x29F4

    // Silent Aim
    static let pomba: UInt = 0x540
    static let sAim2: UInt = 0x978
    static let sAim3: UInt = 0x48
    static let sAim4: UInt = 0x50
    static let guntipposition: UInt = 0x48
    static let lastAimingInfoFromWeapon: UInt = 0xE60

    // Speed
    static let gameTimer: UInt = 0x158
    static let fixedDeltaTime: UInt = 0x2C
    static let playerSpeed: UInt = 0x250

    // Weapon
    static let weaponInfo: UInt = 0x508
    static let weaponID: UInt = 0xB4
    static let weaponOnHand: UInt = 0x54
    static let combineWeaponOnHand: UInt = 0x58
}

enum OB55Bones: UInt32 {
    case head = 0x458
    case root = 0x46C
    case leftWrist = 0x454
    case spine = 0x460
    case hip = 0x468
    case rightCalf = 0x470
    case leftCalf = 0x474
    case rightFoot = 0x478
    case leftFoot = 0x47C
    case rightWrist = 0x0
    case leftHand = 0x484
    case leftShoulder = 0x48C
    case rightShoulder = 0x490
    case rightWristJoint = 0x494
    case leftWristJoint = 0x498
    case leftElbow = 0x49C
    case rightElbow = 0x4A0
}

// MARK: - ESP Method

/// Metode ESP yang didukung. Dipakai untuk picker UI + inject file-patch.
enum ESPMethod: String, CaseIterable, Identifiable {
    case line     = "LINE"
    case box      = "BOX"
    case health   = "HEALTH"
    case name     = "NAME"
    case distance = "DISTANCE"
    case full     = "FULL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line:     return "ESP Line"
        case .box:      return "ESP Box"
        case .health:   return "ESP Health"
        case .name:     return "ESP Name"
        case .distance: return "ESP Distance"
        case .full:     return "ESP Full"
        }
    }

    var icon: String {
        switch self {
        case .line:     return "line.diagonal"
        case .box:      return "square.dashed"
        case .health:   return "heart.fill"
        case .name:     return "tag.fill"
        case .distance: return "ruler.fill"
        case .full:     return "sparkles"
        }
    }

    var desc: String {
        switch self {
        case .line:     return "Garis ke musuh (Head 0x458)"
        case .box:      return "Kotak + visible check 0x31"
        case .health:   return "Bar HP via Attributes 0x4BC"
        case .name:     return "Nama via Player_Name 0x2DC"
        case .distance: return "Jarak via ViewMatrix 0xE8"
        case .full:     return "Line+Box+Health+Name+Jarak"
        }
    }

    /// Folder patch di bundle untuk metode ini.
    /// Isi dengan file hasil mod OB55 kamu, misal:
    /// patches/esp-line/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D
    var resourceSubfolder: String {
        switch self {
        case .line:     return "patches/esp-line"
        case .box:      return "patches/esp-box"
        case .health:   return "patches/esp-health"
        case .name:     return "patches/esp-name"
        case .distance: return "patches/esp-distance"
        case .full:     return "patches/esp-full"
        }
    }
}

// MARK: - ESP Config / Manager (overlay-ready)

/// Config overlay ESP. Saat ini inject pakai file-patch,
/// tapi struct ini sudah siap untuk ESP memory/overlay
/// (worldToScreen pakai Camera 0xC8 + ViewMatrix 0xE8).
struct ESPConfig {
    var showLine = true
    var showBox = true
    var showHealth = false
    var showName = true
    var showDistance = true
    var maxDistance: Float = 200
    var lineColorHex = "#FF3B30"
    var boxColorHex = "#30D158"

    static var `default`: ESPConfig { ESPConfig() }

    static func preset(for method: ESPMethod) -> ESPConfig {
        switch method {
        case .line:     return ESPConfig(showLine: true,  showBox: false, showHealth: false, showName: false, showDistance: false)
        case .box:      return ESPConfig(showLine: false, showBox: true,  showHealth: false, showName: false, showDistance: false)
        case .health:   return ESPConfig(showLine: false, showBox: true,  showHealth: true,  showName: false, showDistance: false)
        case .name:     return ESPConfig(showLine: false, showBox: false, showHealth: false, showName: true,  showDistance: false)
        case .distance: return ESPConfig(showLine: false, showBox: false, showHealth: false, showName: false, showDistance: true)
        case .full:     return ESPConfig(showLine: true,  showBox: true,  showHealth: true,  showName: true,  showDistance: true)
        }
    }
}

final class ESPManager: ObservableObject {
    static let shared = ESPManager()
    @Published var config = ESPConfig.default
    @Published var activeMethod: ESPMethod = .full
    @Published var isActive = false

    func apply(method: ESPMethod) {
        activeMethod = method
        config = ESPConfig.preset(for: method)
        isActive = true
    }

    func stop() { isActive = false }

    /// Skeleton worldToScreen untuk overlay nanti.
    /// - viewMatrix: 16 float dari [Camera 0xC8] + [ViewMatrix 0xE8]
    static func worldToScreen(
        pos: (x: Float, y: Float, z: Float),
        viewMatrix: [Float],
        screenW: Float, screenH: Float
    ) -> (x: Float, y: Float, visible: Bool) {
        guard viewMatrix.count >= 16 else { return (0, 0, false) }
        let w = viewMatrix[3] * pos.x + viewMatrix[7] * pos.y + viewMatrix[11] * pos.z + viewMatrix[15]
        guard w > 0.01 else { return (0, 0, false) }
        let x = (viewMatrix[0] * pos.x + viewMatrix[4] * pos.y + viewMatrix[8] * pos.z + viewMatrix[12]) / w
        let y = (viewMatrix[1] * pos.x + viewMatrix[5] * pos.y + viewMatrix[9] * pos.z + viewMatrix[13]) / w
        return ((x + 1) / 2 * screenW, 1 - (y + 1) / 2 * screenH, true)
    }
}

// MARK: - Shared Open Game Button Card

struct OpenGameButtonCard: View {
    let button: OpenGameButton
    let isWorking: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isWorking
                                ? [AppTheme.accent.opacity(0.18), Color(white: 0.08)]
                                : [Color(white: 0.12), Color(white: 0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(isWorking ? AppTheme.accent : Color.white.opacity(0.6))

                    Text(button.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    if isWorking {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                            .tint(AppTheme.accent)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.accent.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isWorking ? AppTheme.accent.opacity(0.5) : Color(white: 0.15),
                    lineWidth: 1
                )
        )
    }
}
