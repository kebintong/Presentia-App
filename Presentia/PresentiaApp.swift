import SwiftUI
import Supabase

let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseKey,
    options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
)

@main
struct PresentiaApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var signedIn: Bool?

    var body: some View {
        Group {
            switch signedIn {
            case nil: ProgressView()
            case true?: ClassesView()
            case false?: SignInView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task {
            // The stored session comes first even if expired; a refreshed one follows.
            for await (_, session) in supabase.auth.authStateChanges {
                signedIn = session.map { !$0.isExpired } ?? false
            }
        }
    }
}

struct SignInView: View {
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(.presentiaMark)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .padding(.top, 48)
                VStack(spacing: 6) {
                    Text("Presentia")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                    Text(codeSent ? "Enter the code sent to \(email)."
                                  : "Sign in with the same account as Presentia Desktop.")
                        .foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center)
                }
                if codeSent {
                    TextField("Code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .presentiaField()
                } else {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .presentiaField()
                }
                Button(codeSent ? "Sign in" : "Send code") { Task { await submit() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy || email.isEmpty || (codeSent && code.isEmpty))
                if codeSent {
                    Button("Use another email") { codeSent = false; code = "" }
                }
                if let error {
                    Text(error).foregroundStyle(Color.danger)
                }
            }
            .padding(24)
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        error = nil
        do {
            if codeSent {
                _ = try await supabase.auth.verifyOTP(email: email, token: code.trimmingCharacters(in: .whitespaces), type: .email)
            } else {
                try await supabase.auth.signInWithOTP(email: email)
                codeSent = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
