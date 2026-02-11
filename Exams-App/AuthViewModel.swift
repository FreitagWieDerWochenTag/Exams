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
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isBusy: Bool = false

    private let clientId = "e9150ef3-3c14-44ad-92b0-6b738e9e28c5"

    private var redirectUri: String {
        "msauth.\(Bundle.main.bundleIdentifier!)://auth"
    }

    private let authorityUrl = "https://login.microsoftonline.com/organizations"
    private let scopes = ["User.Read"]

    // UserDefaults Keys
    private let roleKey = "cachedUserRole"
    private let nameKey = "cachedUserName"
    private let emailKey = "cachedUserEmail"

    private var msalApp: MSALPublicClientApplication?
    private var interactiveLoginRunning = false
    private static var didSetupLogger = false

    // MARK: - MSAL Logging (nur 1x)
    private func enableMSALLoggingOnce() {
        guard !Self.didSetupLogger else { return }
        Self.didSetupLogger = true
        MSALGlobalConfig.loggerConfig.logLevel = .warning
        MSALGlobalConfig.loggerConfig.setLogCallback { level, message, containsPII in
#if DEBUG
            if let message = message {
                print("MSAL [\(level)]: \(message)")
            }
#endif
        }
    }

    // MARK: - Setup (nur 1x)
    func configure() {
        if msalApp != nil { return }
        enableMSALLoggingOnce()

        do {
            let authority = try MSALAuthority(url: URL(string: authorityUrl)!)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: authority
            )
            config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            msalApp = try MSALPublicClientApplication(configuration: config)
            print("=== MSAL CONFIGURE OK ===")
        } catch {
            print("=== MSAL CONFIGURE ERROR: \(error) ===")
            errorMessage = error.localizedDescription
            return
        }

        Task { await tryAutoLogin() }
    }

    // MARK: - Auto Login (Silent)
    private func tryAutoLogin() async {
        guard let msalApp else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let accounts = try msalApp.allAccounts()
            guard let account = accounts.first else {
                print("=== Kein gecachter Account ===")
                loadCachedUserInfo()
                loadCachedRole()
                return
            }

            let silentParams = MSALSilentTokenParameters(scopes: scopes, account: account)
            let result = try await msalApp.acquireTokenSilent(with: silentParams)
            print("=== Silent Login OK ===")

            isSignedIn = true
            userName = result.account.username ?? "Unbekannt"
            userEmail = result.account.username ?? ""

            // Profil + Rolle parallel laden
            async let profileTask: String = loadUserProfile(accessToken: result.accessToken)
            async let roleTask: AppRole = loadEducationRole(accessToken: result.accessToken)

            if let profile = try? await profileTask, !profile.isEmpty {
                userName = profile
            } else { loadCachedUserInfo() }

            if let detectedRole = try? await roleTask {
                role = detectedRole
                saveRole(detectedRole)
            } else { loadCachedRole() }

            saveUserInfo()

        } catch {
            print("=== Auto Login fehlgeschlagen: \(error) ===")
            loadCachedUserInfo()
            loadCachedRole()
        }
    }

    // MARK: - Interaktiver Login
    func signIn() async {
        if isBusy || interactiveLoginRunning { return }

        errorMessage = nil
        guard let msalApp else { return }

        guard let vc = topMostViewController() else {
            print("=== topMostViewController is nil ===")
            return
        }

        isBusy = true
        interactiveLoginRunning = true
        defer {
            interactiveLoginRunning = false
            isBusy = false
        }

        let webParams = MSALWebviewParameters(authPresentationViewController: vc)
        webParams.webviewType = .authenticationSession

        let params = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: webParams
        )

        do {
            let result = try await msalApp.acquireToken(with: params)
            isSignedIn = true

            userName = result.account.username ?? "Unbekannt"
            userEmail = result.account.username ?? ""

            // Profil + Rolle parallel laden
            async let profileTask: String = loadUserProfile(accessToken: result.accessToken)
            async let roleTask: AppRole = loadEducationRole(accessToken: result.accessToken)

            if let profile = try? await profileTask, !profile.isEmpty {
                userName = profile
            }

            if let detectedRole = try? await roleTask {
                role = detectedRole
                saveRole(detectedRole)
            } else { loadCachedRole() }

            saveUserInfo()

        } catch {
            let nsError = error as NSError
            print("=== MSAL SIGN IN ERROR: \(nsError.code) \(nsError.localizedDescription) ===")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Logout
    func signOut() {
        if let msalApp {
            for acc in (try? msalApp.allAccounts()) ?? [] {
                try? msalApp.remove(acc)
            }
        }
        isSignedIn = false
        role = .unknown
        userName = ""
        userEmail = ""
        UserDefaults.standard.removeObject(forKey: roleKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }

    // MARK: - Graph API
    private func loadUserProfile(accessToken: String) async throws -> String {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let mail = json?["mail"] as? String, !mail.isEmpty {
            userEmail = mail
        } else if let upn = json?["userPrincipalName"] as? String {
            userEmail = upn
        }

        return json?["displayName"] as? String ?? ""
    }

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

    // MARK: - Local storage
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

    private func saveUserInfo() {
        UserDefaults.standard.set(userName, forKey: nameKey)
        UserDefaults.standard.set(userEmail, forKey: emailKey)
    }

    private func loadCachedUserInfo() {
        userName = UserDefaults.standard.string(forKey: nameKey) ?? ""
        userEmail = UserDefaults.standard.string(forKey: emailKey) ?? ""
    }

    // MARK: - ViewController helper
    private func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? (
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        )
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
