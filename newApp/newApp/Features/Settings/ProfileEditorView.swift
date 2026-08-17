//
//  ProfileEditorView.swift
//  Alpha Academy
//

import PhotosUI
import SwiftUI

/// Name, callsign and avatar.
///
/// Photo selection uses `PhotosPicker`, which runs out of process and grants
/// the app no library access at all — so this screen adds **no** permission
/// prompt and no `NSPhotoLibraryUsageDescription`. That matters: in this
/// category the apps badged "Data Not Collected" are the ones rated 5.0.
struct ProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var avatars = AvatarStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var avatar: AvatarConfig
    @State private var photoItem: PhotosPickerItem?
    @State private var photoFailed = false
    @FocusState private var nameFocused: Bool

    init(profile: UserProfile) {
        _name = State(initialValue: profile.name)
        _avatar = State(initialValue: profile.avatar)
    }

    private var previewProfile: UserProfile {
        var p = store.profile
        p.name = name
        p.callsign = derivedCallsign
        p.avatar = avatar
        return p
    }

    private var derivedCallsign: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return CallsignGenerator.callsign(from: trimmed, alphabet: store.activeAlphabet)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    preview
                    nameGroup
                    kindGroup
                    if avatar.kind == .symbol { symbolGroup }
                    tintGroup
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.l)
                .padding(.bottom, Theme.Space.xxl)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.ink2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task { await load(item) }
            }
            .alert("That image could not be read", isPresented: $photoFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a different photo.")
            }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: Theme.Space.m) {
            AvatarView(profile: previewProfile, size: 96)

            if derivedCallsign.isEmpty {
                Text("Add a name to get a callsign")
                    .font(.footnote)
                    .foregroundColor(Theme.ink3)
            } else {
                VStack(spacing: 4) {
                    Text("Your callsign").microLabelStyle()
                    Text(derivedCallsign)
                        .font(.title3.weight(.semibold))
                        .tracking(2)
                        .foregroundColor(Theme.blueBright)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
        .cardSurface()
    }

    // MARK: - Groups

    private var nameGroup: some View {
        SettingsGroup(
            title: "Name",
            footer: "Used only on this device to build your callsign. Nothing is uploaded."
        ) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "person")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.blue)
                    .frame(width: 22)
                TextField("", text: $name, prompt: Text("Your name").foregroundColor(Theme.ink3))
                    .font(.body)
                    .foregroundColor(Theme.ink)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.done)
                if !name.isEmpty {
                    Button {
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .frame(minHeight: 52)
        }
    }

    private var kindGroup: some View {
        SettingsGroup(title: "Avatar") {
            SettingsRow(title: "Initials", systemImage: "textformat", tint: Theme.ink) {
                avatar.kind = .initials
                Haptics.shared.select()
            } trailing: {
                checkmark(avatar.kind == .initials)
            }

            RowDivider()

            SettingsRow(title: "Icon", systemImage: "square.grid.2x2") {
                avatar.kind = .symbol
                Haptics.shared.select()
            } trailing: {
                checkmark(avatar.kind == .symbol)
            }

            RowDivider()

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                SettingsRow(
                    title: "Photo",
                    subtitle: avatars.hasPhoto ? "Chosen from your library" : nil,
                    systemImage: "photo"
                ) {
                    checkmark(avatar.kind == .photo)
                }
            }
            .buttonStyle(PressableButtonStyle())

            if avatars.hasPhoto {
                RowDivider()
                SettingsRow(title: "Remove photo", systemImage: "trash", tint: Theme.negative) {
                    avatars.removePhoto()
                    if avatar.kind == .photo { avatar.kind = .initials }
                }
            }
        }
    }

    private var symbolGroup: some View {
        SettingsGroup(title: "Icon") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 52), spacing: Theme.Space.s)],
                spacing: Theme.Space.s
            ) {
                ForEach(AvatarConfig.symbolChoices, id: \.self) { symbol in
                    let isOn = avatar.symbolName == symbol
                    Button {
                        avatar.symbolName = symbol
                        Haptics.shared.select()
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 19))
                            .foregroundColor(isOn ? avatar.tint.color : Theme.ink2)
                            .frame(width: 52, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .fill(isOn ? avatar.tint.color.opacity(0.16) : Theme.chipNeutral)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(Theme.Space.l)
        }
    }

    private var tintGroup: some View {
        SettingsGroup(title: "Colour") {
            HStack(spacing: Theme.Space.m) {
                ForEach(AvatarTint.allCases) { option in
                    Button {
                        avatar.tint = option
                        Haptics.shared.select()
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        avatar.tint == option ? Theme.ink : .clear,
                                        lineWidth: 2
                                    )
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue)
                }
                Spacer()
            }
            .padding(Theme.Space.l)
        }
    }

    private func checkmark(_ isOn: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundColor(isOn ? Theme.blue : Theme.track)
    }

    // MARK: - Actions

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            photoFailed = true
            return
        }
        if avatars.save(data) {
            avatar.kind = .photo
        } else {
            photoFailed = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let callsign = derivedCallsign
        store.updateProfile {
            $0.name = trimmed
            $0.callsign = callsign
            $0.avatar = avatar
        }
        store.saveNow()
        dismiss()
    }
}
