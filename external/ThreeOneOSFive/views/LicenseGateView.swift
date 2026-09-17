import SwiftUI

// MARK: - LicenseGateView

struct LicenseGateView<Content: View>: View {
    @StateObject private var license = LicenseService.shared
    @State private var showGuide = false
    @AppStorage("kxteam.guideShown") private var guideShown = false
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if let state = license.licenseState, state.isValid {
                content()
                    .onAppear {
                        if !guideShown {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showGuide = true
                                guideShown = true
                            }
                        }
                    }
                    .sheet(isPresented: $showGuide) {
                        SafetyGuideSheet()
                    }
            } else {
                KeyEntryView()
            }
        }
    }
}

// MARK: - Safety Guide Sheet

struct SafetyGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, color: Color, text: String)] = [
        ("shield.lefthalf.filled",   .blue,   "Pastikan Menekan Tombol **Bypass Anticheat** Pada Menu Security, App Free Fire Harus Di Close Terlebih Dahulu (Lakukan Langkah Ini Setiap Kali App Free Fire Habis Ditutup)"),
        ("arrow.right.circle.fill",  .green,  "Setelah Itu Lalu Bisa Login Free Fire, Pastikan Untuk **Inject Aim Di Lobby**"),
        ("star.fill",                .yellow, "Disarankan Menggunakan **FF Max Appstore** Karena Jauh Lebih Aman 👍🏻"),
        ("clock.badge.exclamationmark.fill", .orange, "Jangan Terlalu Lama Di Lobby, **Segera Clean Cache**"),
    ]

    var body: some View {
        sheetContent
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if #available(iOS 16.4, *) {
            mainContent
                .presentationBackground(Color.black)
        } else {
            mainContent
                .background(Color.black.ignoresSafeArea())
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.15))
                            .frame(width: 70, height: 70)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.top, 32)

                    Text("PANDUAN AGAR AMAN")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .kerning(1)
                    Text("ANTI BANNED 99%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .kerning(2)
                    Text("Baca & ikuti langkah-langkah berikut dengan benar")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Divider
                Rectangle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                // Steps
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(step.color.opacity(0.15))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: step.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(step.color)
                                    }
                                    Text("\(i + 1)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.3))
                                }
                                .frame(width: 38)

                                Text(.init(step.text))
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Color(white: 0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                            }
                            .padding(14)
                            .background(Color(white: 0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(step.color.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                }

                // Footer button
                Button {
                    dismiss()
                } label: {
                    Text("Mengerti, Siap Main!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - KeyEntryView

struct KeyEntryView: View {
    @StateObject private var license = LicenseService.shared
    @State private var keyInput = ""
    @State private var shaking = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                            )
                            .frame(width: 90, height: 90)
                        if let icon = UIImage(named: "AppIcon60x60")
                            ?? UIImage(named: "AppIcon") {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        } else {
                            Text("KX")
                                .font(.system(size: 36, weight: .black))
                                .foregroundStyle(.blue)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("KX TEAM EXTERNAL IOS")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                        Text("</> KX TEAM")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.55))
                        Text("Developer @KarenTzy")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text("Enter your license key to continue")
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.4))
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 48)

                // Key input card
                VStack(spacing: 16) {
                    TextField("License", text: $keyInput)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.blue.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .offset(x: shaking ? -8 : 0)
                        .animation(shaking ? .default.repeatCount(4, autoreverses: true).speed(8) : .default, value: shaking)

                    if let error = license.lastError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                    }

                    Button(action: submitKey) {
                        ZStack {
                            if license.isChecking {
                                ProgressView().tint(.white)
                            } else {
                                Text("Activate Key")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            keyInput.isEmpty
                                ? Color.blue.opacity(0.3)
                                : Color.blue
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(keyInput.isEmpty || license.isChecking)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Contact buttons
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // Buy Key
                        Button {
                            if let url = URL(string: "https://discord.gg/4YdWc4aB2") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 12))
                                Text("Buy Key")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(.white)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Channel
                        Button {
                            if let url = URL(string: "https://discord.gg/4YdWc4aB2") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 12))
                                Text("Channel")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(.white)
                            .background(AppTheme.accent.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 12)

                Text("Key is bound to this device on first activation")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, 28)
            }
        }
    }

    private func submitKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            let success = await license.validate(key: trimmed)
            if !success {
                await MainActor.run {
                    shaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shaking = false }
                }
            }
        }
    }
}
