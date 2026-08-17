//
//  OnboardingFlowView.swift
//  Alpha Academy
//

import SwiftUI
import UserNotifications

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: AppRouter

    @State private var page = 0
    @State private var alphabet: AlphabetID = .nato
    @State private var name = ""
    @State private var goalMinutes = 10
    @State private var wantsReminder = false

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)

            TabView(selection: $page) {
                whyPage.tag(0)
                alphabetPage.tag(1)
                callsignPage.tag(2)
                goalPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
                .padding(Theme.Space.l)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: Theme.Space.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Rectangle()
                    .fill(index <= page ? Theme.blue : Theme.track)
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.2), value: page)
    }

    private var footer: some View {
        VStack(spacing: Theme.Space.s) {
            PrimaryButton(title: page == pageCount - 1 ? "Start training" : "Continue") {
                if page == pageCount - 1 {
                    finish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            if page == 2, !name.isEmpty == false {
                Button("Skip for now") { withAnimation { page += 1 } }
                    .font(.subheadline)
                    .foregroundColor(Theme.ink2)
            }
        }
    }

    // MARK: - Pages

    private var whyPage: some View {
        OnboardingPage(
            symbolName: "quote.bubble",
            title: "Spell anything, once.",
            message: "Booking codes, emails, passport numbers — say them so nobody has to ask twice."
        ) {
            VStack(spacing: Theme.Space.s) {
                Text("“Is that M as in Mike, or N as in November?”")
                    .font(.footnote.italic())
                    .foregroundColor(Theme.ink2)
                    .multilineTextAlignment(.center)
                Text("B  →  BRAVO")
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .tracking(2)
                    .foregroundColor(Theme.ink)
                    .padding(Theme.Space.m)
                    .cardSurface()
            }
        }
    }

    private var alphabetPage: some View {
        OnboardingPage(
            symbolName: "list.bullet.rectangle",
            title: "Choose your alphabet.",
            message: "You can switch at any time. Each one tracks its own progress."
        ) {
            VStack(spacing: Theme.Space.m) {
                ForEach(AlphabetCatalog.all) { option in
                    Button {
                        alphabet = option.id
                        Haptics.shared.select()
                    } label: {
                        alphabetRow(option)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func alphabetRow(_ option: PhoneticAlphabet) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: alphabet == option.id ? "largecircle.fill.circle" : "circle")
                .foregroundColor(alphabet == option.id ? Theme.blue : Theme.track)
                .font(.title3)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(option.displayName)
                    .font(.headline)
                    .foregroundColor(Theme.ink)
                Text(option.subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.ink2)
                    .multilineTextAlignment(.leading)
                Text(option.letters.prefix(3).map(\.word).joined(separator: " · "))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.blue)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var callsignPage: some View {
        OnboardingPage(
            symbolName: "person.text.rectangle",
            title: "Your callsign.",
            message: "Type your name and the alphabet does the rest. Optional — skip if you like."
        ) {
            VStack(spacing: Theme.Space.l) {
                TextField("Your name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Space.m)
                    .cardSurface()

                if !derivedCallsign.isEmpty {
                    VStack(spacing: Theme.Space.xs) {
                        Text("YOUR CALLSIGN").sectionHeaderStyle()
                        Text(derivedCallsign)
                            .font(.title2.weight(.semibold))
                            .tracking(2)
                            .foregroundColor(Theme.blue)
                    }
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity)
                    .cardSurface()
                }
            }
        }
    }

    private var goalPage: some View {
        OnboardingPage(
            symbolName: "calendar",
            title: "Pick a daily goal.",
            message: "Short and regular beats long and rare. You can change this later."
        ) {
            VStack(spacing: Theme.Space.m) {
                ForEach([5, 10, 15], id: \.self) { minutes in
                    Button {
                        goalMinutes = minutes
                        Haptics.shared.select()
                    } label: {
                        HStack {
                            Image(systemName: goalMinutes == minutes
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(goalMinutes == minutes ? Theme.blue : Theme.track)
                            Text("\(minutes) minutes a day")
                                .font(.headline)
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Text("~\(minutes * 2) items")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Theme.ink2)
                        }
                        .padding(Theme.Space.l)
                        .cardSurface()
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Toggle(isOn: $wantsReminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder").font(.headline).foregroundColor(Theme.ink)
                        Text("One quiet nudge, at a time you pick.")
                            .font(.caption).foregroundColor(Theme.ink2)
                    }
                }
                .padding(Theme.Space.l)
                .cardSurface()
            }
        }
    }

    // MARK: - Logic

    private var derivedCallsign: String {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        return CallsignGenerator.callsign(
            from: name,
            alphabet: AlphabetCatalog.alphabet(alphabet)
        )
    }

    private func finish() {
        store.completeOnboarding(
            name: name.trimmingCharacters(in: .whitespaces),
            goalMinutes: goalMinutes,
            alphabet: alphabet
        )

        // Only ask for notifications if the learner explicitly opted in.
        // Never at launch, never on the first screen — a "not now" would
        // burn the one system prompt we get.
        if wantsReminder {
            Task {
                let granted = (try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])) ?? false
                store.updateProfile { $0.remindersEnabled = granted }
                if granted { NotificationService.reschedule(profile: store.profile) }
                router.phase = .main
            }
        } else {
            router.phase = .main
        }
    }
}

/// Shared layout so the four steps cannot drift apart.
private struct OnboardingPage<Content: View>: View {
    let symbolName: String
    let title: String
    let message: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                Image(systemName: symbolName)
                    .font(.system(size: 34))
                    .foregroundColor(Theme.blue)
                    .frame(width: 76, height: 76)
                    .cardSurface()
                    .padding(.top, Theme.Space.xl)

                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundColor(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                content
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.xl)
        }
    }
}
