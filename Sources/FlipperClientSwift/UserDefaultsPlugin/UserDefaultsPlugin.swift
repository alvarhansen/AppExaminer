import Foundation

public class UserDefaultsPlugin: FlipperPlugin {

    private let allUserDefaults: [String: UserDefaults] = [
        "Standard": .standard
    ]

    private var connection: FlipperConnection?
    private var observation: NSObjectProtocol?

    public init() {
        swizzleSelector(
            UserDefaults.self,
            #selector(UserDefaults.set(_:forKey:) as (UserDefaults) -> (Any?, String) -> Void),
            #selector(UserDefaults.swizzled_setValue(_:forKey:))
        )
    }

    public func didConnect(connection: FlipperConnection) {
        self.connection = connection

        connection.receive(method: "getAllSharedPreferences") { [weak self] (response: GetAllSharedPreferencesResponse, responder) in
            guard let self else { return }

            let allUserDefaultsDictionaryRepresentation = self.allUserDefaults
                .mapValues { defaults in
                defaults.dictionaryRepresentation()
            }

            try? responder.success(response: AnyCodable(allUserDefaultsDictionaryRepresentation))
        }

        connection.receive(method: "setSharedPreference") { [weak self] (response: SetSharedPreferenceResponse, responder) in
            guard let self else { return }

            let key = response.preferenceName
            let value = response.preferenceValue.value
            self.allUserDefaults[response.sharedPreferencesName]?
                .set(value, forKey: key)
        }

        userDefaultsDidChange = { [weak self] sender, value, key in
            guard let self else { return }

            let preferences = self.allUserDefaults.first { $0.value === sender }
            guard let preferences else { return }

            let request: Encodable
            if let value = value {
                request = SharedPreferencesChangeRequest(
                    preferences: preferences.key,
                    time: "\(Date().timeIntervalSince1970 * 1000)",
                    name: key,
                    value: AnyEncodable(value)
                )
            } else {
                request = SharedPreferencesDeleteRequest(
                    preferences: preferences.key,
                    time: "\(Date().timeIntervalSince1970 * 1000)",
                    name: key
                )
            }

            try? connection.send("sharedPreferencesChange", withParams: request)
        }
    }

    public func didDisconnect() {
        print(#fileID, #function)
        connection = nil
        observation = nil
    }

    public func identifier() -> String {
        "Preferences"
    }

    public func runInBackground() -> Bool {
        true
    }
}

private struct GetAllSharedPreferencesResponse: Decodable {}

private struct SetSharedPreferenceResponse: Decodable {
    let sharedPreferencesName: String
    let preferenceName: String
    let preferenceValue: AnyDecodable
}

private struct SharedPreferencesChangeRequest: Encodable {
    let preferences: String
    let time: String
    let name: String
    let value: AnyEncodable
}

private struct SharedPreferencesDeleteRequest: Encodable {
    let preferences: String
    let time: String
    let name: String
    private let deleted: String = "YES"
}

private func swizzleSelector(
    _ forClass: AnyClass,
    _ originalSelector: Selector,
    _ swizzledSelector: Selector
) {
    if let originalMethod = class_getInstanceMethod(forClass, originalSelector),
        let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector) {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

private var userDefaultsDidChange: ((UserDefaults, _ value: Any?, _ key: String) -> Void)?
private extension UserDefaults {
    @objc func swizzled_setValue(_ value: Any?, forKey key: String) {
        swizzled_setValue(value, forKey: key)
        userDefaultsDidChange?(self, value, key)
    }
}
