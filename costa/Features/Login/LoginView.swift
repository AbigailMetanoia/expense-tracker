//
//  LoginView.swift
//  costa
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthController.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var googleStartURL: URL {
        var c = URLComponents(url: APIBaseURL.url.appending(path: "api/auth/oauth/google"), resolvingAgainstBaseURL: true)!
        c.queryItems = [URLQueryItem(name: "redirect_to", value: "\(GoogleOAuthSession.callbackScheme)://oauth")]
        return c.url!
    }

    var body: some View {
        ZStack {
            VStack {
                CostaImageBackground(imageName: "Gradient2", alignment: .bottom).padding(.top, 10)
            }

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    Image("white_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 62, height: 52)
                        .padding(.bottom, 20)

                    Text("Welcome back!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Please enter required details.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 20) {
                        StyledTextField(
                            title: "Email",
                            placeholder: "example@gmail.com",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            autocapitalization: .never,
                            autocorrectionDisabled: true
                        )

                        StyledTextField(
                            title: "Password",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            textContentType: .password
                        )

                        StyledGradientButton(
                            title: "Sign in",
                            isLoading: isBusy,
                            isDisabled: email.isEmpty || password.isEmpty
                        ) {
                            Task { await signInWithPassword() }
                        }
                        .padding(.top, 4)

                        HStack(spacing: 12) {
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                            Text("Or")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        }

                        Button {
                            errorMessage = nil
                            startGoogleSignIn()
                        } label: {
                            HStack(spacing: 8) {
                                // TODO: add a "google_logo" image asset (the
                                // multicolor "G" mark) for an exact match.
                                // Falls back to a plain globe glyph so this
                                // still compiles without that asset.
                                Image(systemName: "globe")
                                    .foregroundStyle(.blue)
                                Text("Sign in with Google")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                    .background(
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial)
                            Rectangle().fill(Color.black.opacity(0.55))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func startGoogleSignIn() {
        isBusy = true
        let api = AuthAPIClient()
        GoogleOAuthSession.perform(startURL: googleStartURL, api: api) { result in
            Task { @MainActor in
                isBusy = false
                switch result {
                case let .success(response):
                    do {
                        try auth.applyLoginResponse(response)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                case let .failure(err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    private func signInWithPassword() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await auth.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(AuthController())
}
