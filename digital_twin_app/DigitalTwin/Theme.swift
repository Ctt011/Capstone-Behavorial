import SwiftUI

// MARK: - Debug Logger
/// Replaces raw `print()` across the codebase. In Release builds this compiles
/// to nothing, so no health data leaks to the console and there's zero runtime
/// overhead. In Debug builds it forwards to `print()` as before.
@inline(__always)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

// MARK: - PhysioTwin Design Tokens
// Source: physiotwin-tokens.json + digital-twin-style-guide.html

extension Color {
    // Primary
    static let ptSage      = Color(red: 61/255, green: 139/255, blue: 110/255)  // #3D8B6E
    static let ptSageLight = Color(red: 90/255, green: 173/255, blue: 138/255)  // #5AAD8A
    static let ptSagePale  = Color(red: 234/255, green: 244/255, blue: 239/255) // #EAF4EF

    // Secondary
    static let ptMint      = Color(red: 168/255, green: 213/255, blue: 194/255) // #A8D5C2
    static let ptTeal      = Color(red: 27/255, green: 111/255, blue: 94/255)   // #1B6F5E
    static let ptTealLight = Color(red: 42/255, green: 157/255, blue: 143/255)  // #2A9D8F

    // Neutrals
    static let ptSlate     = Color(red: 30/255, green: 42/255, blue: 53/255)    // #1E2A35
    static let ptBody      = Color(red: 61/255, green: 76/255, blue: 89/255)    // #3D4C59
    static let ptMuted     = Color(red: 122/255, green: 143/255, blue: 160/255) // #7A8FA0
    static let ptBorder    = Color(red: 221/255, green: 230/255, blue: 236/255) // #DDE6EC
    static let ptSurface   = Color(red: 247/255, green: 250/255, blue: 251/255) // #F7FAFB

    // Semantic
    static let ptError     = Color(red: 214/255, green: 69/255, blue: 80/255)   // #D64550
    static let ptWarning   = Color(red: 212/255, green: 135/255, blue: 10/255)  // #D4870A
    static let ptInfo      = Color(red: 46/255, green: 126/255, blue: 189/255)  // #2E7EBD
}
