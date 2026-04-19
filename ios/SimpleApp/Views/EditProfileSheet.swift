import SwiftUI

struct EditProfileSheet: View {
    let viewModel: MarketViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var avatarURL: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Color(.secondarySystemBackground)
                            .frame(width: 96, height: 96)
                            .overlay {
                                if let url = URL(string: avatarURL), !avatarURL.isEmpty {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .clipShape(Circle())
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Username") {
                    TextField("@yourname", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Bio") {
                    TextField("Tell others about you", text: $bio, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Avatar URL") {
                    TextField("https://…/avatar.png", text: $avatarURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(.body, design: .monospaced))
                }

                Section("Wallet") {
                    Text(viewModel.wallet.publicAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").bold()
                        }
                    }
                    .disabled(isSaving || username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                username = viewModel.profile.username
                bio = viewModel.profile.bio
                avatarURL = viewModel.profile.avatarURL
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await viewModel.saveProfile(
                    username: username.trimmingCharacters(in: .whitespaces),
                    bio: bio.trimmingCharacters(in: .whitespaces),
                    avatarURL: avatarURL.trimmingCharacters(in: .whitespaces)
                )
                dismiss()
            } catch {
                errorMessage = "Could not save profile. Please try again."
            }
            isSaving = false
        }
    }
}
