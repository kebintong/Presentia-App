import SwiftUI

// Colours live in Assets.xcassets, copied from the desktop's Normal Light / Normal Dark tokens
// (presentia-desktop/frontend/src/style.css); Xcode generates Color.surface, Color.ink, ...

/// The desktop's .btn-primary: flat cyan fill, deep navy text.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Color.onAccent)
            .background(Color.accentFill, in: .rect(cornerRadius: 8))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

extension View {
    /// The desktop's input: surface fill, 1px border, 8px corners.
    func presentiaField() -> some View {
        padding(12)
            .foregroundStyle(Color.ink)
            .background(Color.surface, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border))
    }

    /// A list on the app background with surface-coloured rows.
    func presentiaList() -> some View {
        scrollContentBackground(.hidden).background(Color.appBackground)
    }
}
