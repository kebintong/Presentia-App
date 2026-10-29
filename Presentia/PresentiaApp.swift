import SwiftUI
import Supabase

let supabase = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseKey)

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
        .task {
            for await (_, session) in supabase.auth.authStateChanges {
                signedIn = session != nil
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
        Form {
            Section("Sign in to Presentia") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(codeSent)
                if codeSent {
                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }
            }
            Button(codeSent ? "Sign in" : "Send code") { Task { await submit() } }
                .disabled(busy || email.isEmpty || (codeSent && code.count != 6))
            if codeSent {
                Button("Use another email") { codeSent = false; code = "" }
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        error = nil
        do {
            if codeSent {
                _ = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
            } else {
                try await supabase.auth.signInWithOTP(email: email)
                codeSent = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
