import SwiftUI
import UIKit

/// §13.4: the keyboard must never get stuck on screen. Applied to every
/// screen with a text field (the meal editor, recipe line form,
/// new-ingredient form, ingredient detail, Add Shopping Item, and Settings →
/// Sharing). `.searchable` bars dismiss themselves already and don't need it.
enum KeyboardDismissal {
    static func dismissActiveField() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Tapping outside a text field dismisses the keyboard, and scrolling
    /// does too. `simultaneousGesture` lets the dismiss-tap coexist with
    /// whatever else is under it (buttons, rows, toggles, other fields)
    /// rather than swallowing that tap.
    func keyboardDismissible() -> some View {
        simultaneousGesture(TapGesture().onEnded { KeyboardDismissal.dismissActiveField() })
            .scrollDismissesKeyboard(.interactively)
    }

    /// A `Done` button in the keyboard's own toolbar, for keyboards with no
    /// Return key (`.phonePad`, `.decimalPad`, `.numberPad`).
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { KeyboardDismissal.dismissActiveField() }
            }
        }
    }
}
