import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        ZStack(alignment: .bottom) {
            // Content
            ZStack {
                ForEach(featureVisibility.visibleSections) { section in
                    sectionContent(section)
                        .opacity(tabNavigation.selectedTab == section.rawValue ? 1 : 0)
                        .allowsHitTesting(tabNavigation.selectedTab == section.rawValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 70)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(featureVisibility.visibleSections) { section in
                    let isSelected = tabNavigation.selectedTab == section.rawValue
                    Button {
                        tabNavigation.select(section.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? AppTheme.accent : Color(white: 0.45))
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            Text(language.text(section.titleKey))
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? AppTheme.accent : Color(white: 0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected
                                ? AppTheme.accent.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
            .padding(.top, 6)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.85))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(AppTheme.accent.opacity(0.2)),
                alignment: .top
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("ZX TEAM")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: wallpapersSupported
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            InjectMenuView()
        case .extra:
            ExtraMenuView()
        case .security:
            SecurityMenuView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .extra: return "tab.extra"
        case .security: return "tab.security"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "gearshape.fill"
        case .files: return "folder.fill"
        case .patches: return "square.grid.2x2.fill"
        case .extra: return "bolt.fill"
        case .security: return "lock.shield.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @StateObject private var license = LicenseService.shared
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showLicenseKey = false
    @State private var showLogoutConfirm = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: Hero Brand Card
                        heroBrandCard

                        // MARK: License Card
                        if let state = license.licenseState {
                            licenseCard(state)
                        }

                        // MARK: Device Card
                        deviceCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("ZX TEAM")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(AppTheme.accent)
                        Text("Jaki x Zerion x Zain")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.accent.opacity(0.6))
                    }
                }
            }
            .confirmationDialog("Logout?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Logout", role: .destructive) {
                    LicenseService.shared.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your license key will need to be re-entered.")
            }
        }
    }

    // MARK: Hero Brand Card
    private var heroBrandCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.18), Color(white: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)

            HStack(spacing: 16) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 62, height: 62)
                    if let icon = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 62, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Text("ZX")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("ZX TEAM")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text("JAKI X ZERION X ZAIN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .kerning(2)
                    HStack(spacing: 4) {
                        Text("by </> ZX TEAM")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(white: 0.45))
                        Text("·")
                            .foregroundStyle(Color(white: 0.3))
                        Text("@sanglegenda2k25")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.accent.opacity(0.8))
                    }
                    Text("v\(AppInfo.appVersion)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.28))
                }
                Spacer()
            }
            .padding(18)
        }
    }

    // MARK: License Card
    private func licenseCard(_ state: LicenseState) -> some View {
        VStack(spacing: 0) {
            // Header
            sectionHeader(icon: "key.fill", title: "LICENSE")

            VStack(spacing: 1) {
                // Key row
                infoRow {
                    Image(systemName: "key.fill")
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 20)
                    if showLicenseKey {
                        Text(state.key)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("••••-••••-••••-••••")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                    Button { showLicenseKey.toggle() } label: {
                        Image(systemName: showLicenseKey ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                }

                // Expiry row
                infoRow {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(state.daysRemaining <= 1 ? .red : .green)
                        .frame(width: 20)
                    Text("Expired")
                        .foregroundStyle(Color(white: 0.55))
                        .font(.system(size: 13))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(state.expiresAt, style: .date)
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("\(state.daysRemaining) day\(state.daysRemaining == 1 ? "" : "s") remaining")
                            .font(.system(size: 11))
                            .foregroundStyle(state.daysRemaining <= 1 ? .red : .green)
                    }
                }

                // Logout
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13))
                        Text("Logout / Change Key")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.3))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color(white: 0.06))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(white: 0.12), lineWidth: 1)
        )
    }

    // MARK: Device Card
    private var deviceCard: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "iphone", title: "DEVICE")

            VStack(spacing: 1) {
                infoRow {
                    Image(systemName: "iphone")
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                        .frame(width: 20)
                    Text("iPhone Model")
                        .foregroundStyle(Color(white: 0.55))
                        .font(.system(size: 13))
                    Spacer()
                    Text(AppInfo.displayMachineName)
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(.white)
                }

                infoRow {
                    Image(systemName: "gear")
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                        .frame(width: 20)
                    Text("iOS Version")
                        .foregroundStyle(Color(white: 0.55))
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(.white)
                }

                infoRow {
                    Image(systemName: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(appState.isSupported ? .green : .red)
                        .frame(width: 20)
                    Text("Compatibility")
                        .foregroundStyle(Color(white: 0.55))
                        .font(.system(size: 13))
                    Spacer()
                    Text(appState.isSupported ? "Supported" : "Unsupported")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appState.isSupported ? .green : .red)
                }

                if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                    infoRow {
                        Image(systemName: "memorychip")
                            .foregroundStyle(AppTheme.accent.opacity(0.8))
                            .frame(width: 20)
                        Text(language.text("dashboard.kernel_status"))
                            .foregroundStyle(Color(white: 0.55))
                            .font(.system(size: 13))
                        Spacer()
                        if appState.kernelExploitRunning {
                            HStack(spacing: 5) {
                                ProgressView().controlSize(.mini)
                                Text(language.text("dashboard.kernel_running"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(appState.exploitStatus.isSuccess ? .green : .secondary)
                        }
                    }
                }
            }

            // Footer
            Text("Support iOS 15 – 27")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.25))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(Color(white: 0.06))
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(white: 0.12), lineWidth: 1)
        )
    }

    // MARK: Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .kerning(1.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.1), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(AppTheme.accent.opacity(0.15))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func infoRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.07))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.1))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
