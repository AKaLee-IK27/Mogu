import Foundation
import LocalAuthentication

// Touch ID *confirmation* gate for the optional admin escalation.
//
// This is a confirmation only — it does NOT grant privileges. After it passes,
// the admin password (via osascript "with administrator privileges") still
// performs the actual elevation. We deliberately do not use pam_tid / a
// privileged helper, so this never blocks system-level features on a managed
// device: when biometrics are unavailable, or an unexpected error occurs, the
// gate falls through (returns `true`) and the existing password flow handles
// authorization. Only an explicit user cancel returns `false`.
enum BiometricGate {
    static func confirm(reason: String) async -> Bool {
        let context = LAContext()
        var policyError: NSError?
        // No Touch ID hardware / not enrolled / policy unavailable: do not block.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: true)
                    return
                }
                // Explicit user back-out aborts the escalation; anything else
                // (lockout, biometry-not-available at eval time, etc.) falls
                // through to the password flow rather than dead-ending.
                if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel, .appCancel, .userFallback:
                        continuation.resume(returning: false)
                    default:
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
}
