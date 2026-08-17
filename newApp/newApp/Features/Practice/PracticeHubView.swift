//
//  PracticeHubView.swift
//  Alpha Academy
//

import SwiftUI

struct PracticeHubView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeMode: TrainingMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        SectionHeader(title: "Modes")
                        ForEach(TrainingMode.practiceModes) { mode in
                            Button { activeMode = mode } label: { modeCard(mode) }
                                .buttonStyle(PressableButtonStyle())
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        SectionHeader(title: "Scenario sets")
                        Text("Encode and Decode draw their strings from these.")
                            .font(.caption)
                            .foregroundColor(Theme.ink2)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Space.m)],
                            spacing: Theme.Space.m
                        ) {
                            ForEach(ScenarioCatalog.all) { set in
                                scenarioChip(set)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.l)
                // Clears the floating tab bar.
                .padding(.bottom, Theme.tabBarClearance)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Practice")
            .fullScreenCover(item: $activeMode) { mode in
                SessionContainerView(
                    mode: mode,
                    alphabet: store.activeAlphabet,
                    progress: store.progressMap(),
                    goalMinutes: store.profile.dailyGoalMinutes
                ) { result in
                    store.commit(result)
                    activeMode = nil
                }
            }
            .onAppear {
                #if DEBUG
                // Lets QA jump straight into a mode:
                //   SIMCTL_CHILD_AA_INITIAL_MODE=encode xcrun simctl launch …
                if activeMode == nil,
                   let raw = ProcessInfo.processInfo.environment["AA_INITIAL_MODE"],
                   let mode = TrainingMode(rawValue: raw) {
                    activeMode = mode
                }
                #endif
            }
        }
    }

    private func modeCard(_ mode: TrainingMode) -> some View {
        let accuracy = store.stats.accuracyByMode[mode]

        return HStack(spacing: Theme.Space.m) {
            Image(systemName: mode.symbolName)
                .font(.title3)
                .foregroundColor(Theme.blue)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(Theme.chipNeutral)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.headline)
                    .foregroundColor(Theme.ink)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.ink2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: Theme.Space.s)

            if let accuracy, accuracy.sampleSize >= 10 {
                Text("\(Int(accuracy.allTime * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.ink2)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.track)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func scenarioChip(_ set: ScenarioSet) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Image(systemName: set.category.symbolName)
                .font(.subheadline)
                .foregroundColor(Theme.blue)
            Text(set.title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.ink)
            Text(set.samples.first ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Theme.ink2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .cardSurface()
    }
}
