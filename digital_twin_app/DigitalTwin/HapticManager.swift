import UIKit

// MARK: - Haptic Feedback Manager
/// Centralized haptic feedback for consistent tactile responses across the app.
enum HapticManager {
    
    // MARK: - Impact Feedback
    
    /// Light tap — selection changes, minor taps
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Medium tap — significant actions (start session, connect health)
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Soft tap — subtle phase transitions (breathing exercise)
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success — save, complete, finish
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// Warning — destructive confirmation prompt
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    /// Error — delete confirmed
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed — day picker, tab switch
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
