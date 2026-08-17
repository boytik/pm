//
//  SettingsView.swift
//  Alpha Academy
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var showProfileEditor = false
    @State private var showResetConfirm = false
    @State private var reportURL: URL?
    @State private var isExporting = false
    @State private var exportFailed = false

    /// Fill in once the listing exists. Until then Share falls back to the
    /// plain description with no link, which is better than shipping a dead
    /// URL to everyone the user invites.
    private static let appStoreID: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    profileCard
                    shareGroup
                    alphabetGroup
                    audioGroup
                    practiceGroup
                    aboutGroup
                    resetGroup
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.l)
                .padding(.bottom, Theme.Space.xxl)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorView(profile: store.profile).environmentObject(store)
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.environment["AA_OPEN_PROFILE"] == "1" {
                    showProfileEditor = true
                }
                #endif
            }
            .confirmationDialog(
                "Reset everything?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset everything", role: .destructive) { store.resetEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears all progress, stats and achievements. It cannot be undone.")
            }
            .alert("Could not build the PDF", isPresented: $exportFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        Button {
            showProfileEditor = true
        } label: {
            HStack(spacing: Theme.Space.l) {
                AvatarView(profile: store.profile, size: 62)

                VStack(alignment: .leading, spacing: 4) {
                    if store.profile.callsign.isEmpty {
                        Text("Set up your profile")
                            .font(.headline)
                            .foregroundColor(Theme.ink)
                        Text("Add a name, pick an avatar")
                            .font(.caption)
                            .foregroundColor(Theme.ink3)
                    } else {
                        Text(store.profile.callsign)
                            .font(.title3.weight(.semibold))
                            .tracking(1.5)
                            .foregroundColor(Theme.blueBright)
                        HStack(spacing: Theme.Space.s) {
                            RankInsigniaView(rank: store.profile.rank, size: 14)
                            Text(store.profile.rank.title)
                                .font(.caption)
                                .foregroundColor(Theme.ink2)
                            Text(verbatim: "· \(store.profile.xp) XP")
                                .font(AppFont.mono(11, relativeTo: .caption))
                                .foregroundColor(Theme.ink3)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.track)
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Share & rate

    private var shareGroup: some View {
        SettingsGroup(
            title: "Share",
            footer: "The record is built on this device from your own progress."
        ) {
            // ShareLink appears only once the file exists, so the sheet never
            // opens on an empty or half-written PDF.
            if let reportURL {
                ShareLink(
                    item: reportURL,
                    preview: SharePreview(
                        "Alpha Academy training record",
                        image: Image(systemName: "doc.richtext")
                    )
                ) {
                    SettingsRow(
                        title: "Share my results",
                        subtitle: "A one-page PDF record",
                        systemImage: "doc.richtext",
                        showsChevron: true
                    )
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                SettingsRow(
                    title: "Share my results",
                    subtitle: isExporting ? "Building the PDF…" : "A one-page PDF record",
                    systemImage: "doc.richtext"
                ) {
                    export()
                } trailing: {
                    if isExporting {
                        ProgressView().tint(Theme.ink2)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.track)
                    }
                }
            }

            RowDivider()

            ShareLink(item: inviteText) {
                SettingsRow(
                    title: "Tell a friend",
                    subtitle: "Anyone who spells codes over the phone",
                    systemImage: "person.2",
                    showsChevron: true
                )
            }
            .buttonStyle(PressableButtonStyle())

            RowDivider()

            SettingsRow(
                title: "Rate Alpha Academy",
                systemImage: "star",
                showsChevron: true
            ) {
                requestReview()
            }
        }
    }

    private var inviteText: String {
        """
        Alpha Academy — a trainer for the NATO phonetic alphabet.

        It teaches you to spell booking codes, emails and passport numbers \
        out loud so nobody has to ask you twice. Works offline, no account.
        """ + (Self.appStoreID.map { "\n\nhttps://apps.apple.com/app/id\($0)" } ?? "")
    }

    // MARK: - Alphabet

    private var alphabetGroup: some View {
        SettingsGroup(title: "Alphabet", footer: store.activeAlphabet.provenance) {
            ForEach(Array(AlphabetCatalog.all.enumerated()), id: \.element.id) { index, option in
                if index > 0 { RowDivider() }
                SettingsRow(
                    title: option.displayName,
                    subtitle: option.subtitle,
                    systemImage: nil
                ) {
                    store.setAlphabet(option.id)
                    Haptics.shared.select()
                } trailing: {
                    Image(systemName: store.activeAlphabetID == option.id
                          ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(store.activeAlphabetID == option.id
                                         ? Theme.blue : Theme.track)
                }
            }
        }
    }

    // MARK: - Audio

    private var audioGroup: some View {
        SettingsGroup(title: "Audio") {
            SettingsSegmentedRow(
                title: "Speech rate",
                systemImage: "speaker.wave.2",
                options: [0.38, 0.48, 0.58],
                label: { rate in
                    rate < 0.42 ? "Slow" : (rate < 0.52 ? "Normal" : "Fast")
                },
                selection: Binding(
                    get: { nearestRate(store.profile.speechRate) },
                    set: { rate in store.updateProfile { $0.speechRate = rate } }
                )
            )

            RowDivider()

            SettingsRow(title: "Hear an example", systemImage: "play.circle") {
                if let entry = store.activeAlphabet.letters.first {
                    SpeechService.shared.speak(entry, rate: store.profile.speechRate)
                }
            }

            RowDivider()

            SettingsToggleRow(
                title: "Auto-play in Study",
                subtitle: "Speaks each card as it appears",
                systemImage: "waveform",
                isOn: Binding(
                    get: { store.profile.autoSpeakInStudy },
                    set: { value in store.updateProfile { $0.autoSpeakInStudy = value } }
                )
            )
        }
    }

    /// The stored rate is a free Double; the picker offers three stops.
    private func nearestRate(_ value: Double) -> Double {
        [0.38, 0.48, 0.58].min { abs($0 - value) < abs($1 - value) } ?? 0.48
    }

    // MARK: - Practice

    private var practiceGroup: some View {
        SettingsGroup(title: "Practice") {
            SettingsSegmentedRow(
                title: "Daily goal",
                systemImage: "target",
                options: [5, 10, 15],
                label: { "\($0) min" },
                selection: Binding(
                    get: { store.profile.dailyGoalMinutes },
                    set: { value in store.updateProfile { $0.dailyGoalMinutes = value } }
                )
            )

            RowDivider()

            SettingsToggleRow(
                title: "Daily reminder",
                subtitle: "One quiet nudge, at a time you pick",
                systemImage: "bell",
                isOn: Binding(
                    get: { store.profile.remindersEnabled },
                    set: { enabled in
                        store.updateProfile { $0.remindersEnabled = enabled }
                        if enabled {
                            Task {
                                let granted = await NotificationService.requestAuthorization()
                                store.updateProfile { $0.remindersEnabled = granted }
                                NotificationService.reschedule(profile: store.profile)
                            }
                        } else {
                            NotificationService.cancelAll()
                        }
                    }
                )
            )

            if store.profile.remindersEnabled {
                RowDivider()
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "clock")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.blue)
                        .frame(width: 22)
                    Text("Reminder time").font(.body).foregroundColor(Theme.ink)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { store.profile.reminderTime },
                            set: { time in
                                store.updateProfile { $0.reminderTime = time }
                                NotificationService.reschedule(profile: store.profile)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, Theme.Space.l)
                .frame(minHeight: 52)
            }
        }
    }

    // MARK: - About

    private var aboutGroup: some View {
        SettingsGroup(
            title: "About",
            footer: "Everything is stored on this device. There is no account and nothing is uploaded."
        ) {
            SettingsRow(title: "Version") {
                RowValue(text: versionText, isMono: true)
            }
            RowDivider()
            SettingsRow(
                title: "Typefaces",
                subtitle: "Instrument Serif and IBM Plex Mono, SIL Open Font License"
            )
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - Reset

    private var resetGroup: some View {
        SettingsGroup(title: "Data") {
            SettingsRow(
                title: "Reset progress",
                subtitle: "Clears every alphabet, stat and achievement",
                systemImage: "trash",
                tint: Theme.negative
            ) {
                showResetConfirm = true
            }
        }
    }

    // MARK: - Export

    private func export() {
        guard !isExporting else { return }
        isExporting = true
        let model = ReportExporter.model(from: store)
        // A hop off this runloop turn so the row can show its spinner before
        // the render blocks the main actor.
        DispatchQueue.main.async {
            do {
                reportURL = try ReportExporter.exportPDF(model: model)
            } catch {
                exportFailed = true
            }
            isExporting = false
        }
    }
}
