import Foundation

/// Bundle IDs we look up by hand across the UI layer. Centralized so a typo
/// in any one place doesn't silently break Chrome-profile or Safari-default
/// behavior.
enum BundleID {
    static let safari = "com.apple.Safari"
    static let chrome = "com.google.Chrome"
}
