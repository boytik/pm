//
//  SettingsView.swift
//  Alpha Academy
//
//  A standard Form on purpose. People pattern-match settings screens; a
//  bespoke one looks worse and costs a day.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Your name", text: $nameDraft)
                        .autocorrectionDisabled()
                    if !derivedCallsign.isEmpty {
                        LabeledContent("Callsign", value: derivedCallsign)
                    }
                    LabeledContent("Rank", value: store.profile.rank.title)
                    LabeledContent("XP", value: "\(store.profile.xp)")
                }

                Section("Alphabet") {
                    Picker("Active", selection: Binding(
                        get: { store.activeAlphabetID },
                        set: { store.setAlphabet($0) }
                    )) {
                        ForEach(AlphabetCatalog.all) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    Text(store.activeAlphabet.provenance)
                        .font(.caption2)
                        .foregroundColor(Theme.inkSecondary)
                }

                Section("Audio") {
                    HStack {
                        Text("Speech rate")
                        Slider(
                            value: Binding(
                                get: { store.profile.speechRate },
                                set: { rate in store.updateProfile { $0.speechRate = rate } }
                            ),
                            in: 0.35...0.62
                        )
                        Button("Test") {
                            if let entry = store.activeAlphabet.letters.first {
                                SpeechService.shared.speak(entry, rate: store.profile.speechRate)
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    Toggle("Auto-play in Study", isOn: Binding(
                        get: { store.profile.autoSpeakInStudy },
                        set: { value in store.updateProfile { $0.autoSpeakInStudy = value } }
                    ))
                }

                Section("Practice") {
                    Picker("Daily goal", selection: Binding(
                        get: { store.profile.dailyGoalMinutes },
                        set: { value in store.updateProfile { $0.dailyGoalMinutes = value } }
                    )) {
                        ForEach([5, 10, 15], id: \.self) { Text("\($0) minutes").tag($0) }
                    }

                    Toggle("Daily reminder", isOn: Binding(
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
                    ))

                    if store.profile.remindersEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: Binding(
                                get: { store.profile.reminderTime },
                                set: { time in
                                    store.updateProfile { $0.reminderTime = time }
                                    NotificationService.reschedule(profile: store.profile)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section {
                    Button("Reset progress", role: .destructive) {
                        showResetConfirm = true
                    }
                } footer: {
                    Text("Everything is stored on this device only. There is no account.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { commitName(); dismiss() }
                }
            }
            .onAppear { nameDraft = store.profile.name }
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
        }
    }

    private var derivedCallsign: String {
        guard !nameDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        return CallsignGenerator.callsign(from: nameDraft, alphabet: store.activeAlphabet)
    }

    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        store.updateProfile {
            $0.name = trimmed
            $0.callsign = derivedCallsign
        }
    }
}
