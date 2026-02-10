import Foundation
import SwiftUI
import Combine
import MSAL

enum AppRole: String {
    case teacher
    case student
    case unknown
}

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var isSignedIn = false
    @Published var role: AppRole = .unknown
    @Published var errorMessage: String? = nil

    private let clientId = "e9150ef3-3c14-44ad-92b0-6b738e9e28c5"

    private var redirectUri: String {
        "msauth.\(Bundle.main.bundleIdentifier!)://auth"
    }

    private let authorityUrl = "https://login.microsoftonline.com/organizations"
    private let scopes = ["User.Read"]
    private let roleKey = "cachedUserRole"

    private var msalApp: MSALPublicClientApplication?

    // MARK: - MSAL LOGGING (DEBUG)
    private func enableMSALLogging() {
        print("BUNDLE:", Bundle.main.bundleIdentifier ?? "nil")
        print("REDIRECT:", redirectUri)

        MSALGlobalConfig.loggerConfig.logLevel = .verbose

        MSALGlobalConfig.loggerConfig.setLogCallback { level, message, containsPII in
            if let message = message {
#if DEBUG
                print("MSAL [\(level)] PII=\(containsPII): \(message)")
#endif
            }
        }
    }

    // MARK: - Setup
    func configure() {
        enableMSALLogging()

        do {
            let authority = try MSALAuthority(url: URL(string: authorityUrl)!)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: authority
            )
            msalApp = try MSALPublicClientApplication(configuration: config)
            print("=== MSAL CONFIGURE OK ===")
        } catch {
            let nsError = error as NSError
            print("=== MSAL CONFIGURE ERROR ===")
            print("Domain:", nsError.domain)
            print("Code:", nsError.code)
            print("Description:", nsError.localizedDescription)
            print("UserInfo:", nsError.userInfo)
            print("============================")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Login
    func signIn() async {
        errorMessage = nil
        guard let msalApp else {
            print("=== msalApp is nil, configure() failed ===")
            return
        }
        guard let vc = UIApplication.shared.topMostViewController() else {
            print("=== topMostViewController is nil ===")
            return
        }

        let webParams = MSALWebviewParameters(authPresentationViewController: vc)
        let params = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: webParams
        )

        do {
            let result = try await msalApp.acquireToken(with: params)
            isSignedIn = true

            do {
                let detectedRole = try await loadEducationRole(accessToken: result.accessToken)
                role = detectedRole
                saveRole(detectedRole)
            } catch {
                loadCachedRole()
            }

        } catch {
            let nsError = error as NSError
            print("=== MSAL SIGN IN ERROR ===")
            print("Domain:", nsError.domain)
            print("Code:", nsError.code)
            print("Description:", nsError.localizedDescription)
            print("UserInfo:", nsError.userInfo)
            print("==========================")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Education API (best effort)
    private func loadEducationRole(accessToken: String) async throws -> AppRole {
        let url = URL(string: "https://graph.microsoft.com/v1.0/education/me")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let role = (json?["primaryRole"] as? String)?.lowercased()

        if role == "teacher" { return .teacher }
        if role == "student" { return .student }
        return .unknown
    }

    // MARK: - Local role storage
    func setRoleManually(_ newRole: AppRole) {
        role = newRole
        saveRole(newRole)
    }

    private func saveRole(_ role: AppRole) {
        UserDefaults.standard.set(role.rawValue, forKey: roleKey)
    }

    private func loadCachedRole() {
        guard let raw = UserDefaults.standard.string(forKey: roleKey),
              let saved = AppRole(rawValue: raw) else {
            role = .unknown
            return
        }
        role = saved
    }
}

// MARK: - UIKit Helper
extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ??
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = baseVC as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = baseVC?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return baseVC
    }
}
