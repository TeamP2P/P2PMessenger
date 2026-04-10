import Foundation
import Testing
@testable import P2PMessenger

final class MockKeyValueStorage: KeyValueStorageProtocol {
    private var storage: [String: Any] = [:]

    func string(forKey key: String) -> String? { storage[key] as? String }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func data(forKey key: String) -> Data? { storage[key] as? Data }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
    func removeAll() { storage.removeAll() }
}

struct StorageTests {

    @Test
    func testPermissionsStorage() {
        let mock = MockKeyValueStorage()
        let permissions = PermissionsStorage(storage: mock)

        // Initial state
        #expect(permissions.isLocalNetworkGranted == false)
        #expect(permissions.isNearbyGranted == false)

        // Set values
        permissions.isLocalNetworkGranted = true
        permissions.isNearbyGranted = true

        // Verify storage
        #expect(permissions.isLocalNetworkGranted == true)
        #expect(permissions.isNearbyGranted == true)
        
        // Reset and verify
        permissions.isLocalNetworkGranted = false
        #expect(permissions.isLocalNetworkGranted == false)
        #expect(permissions.isNearbyGranted == true)
    }

    @Test
    func testOnboardingStorage() {
        let mock = MockKeyValueStorage()
        let onboarding = OnboardingStorage(storage: mock)

        // Initial state
        #expect(onboarding.getIsOnboardingPassed() == false)

        // Set passed
        onboarding.setIsOnboardingPassed(true)
        #expect(onboarding.getIsOnboardingPassed() == true)

        // Reset
        onboarding.setIsOnboardingPassed(false)
        #expect(onboarding.getIsOnboardingPassed() == false)
    }
}
