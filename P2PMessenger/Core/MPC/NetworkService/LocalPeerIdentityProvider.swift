//
//  LocalPeerIdentityProvider.swift
//  P2PMessenger
//

import Foundation
import MultipeerConnectivity
import UIKit

protocol LocalPeerIdentityDelegate: AnyObject {
    func identityProviderDidChangeIdentity()
}

enum LocalPeerIdentityUpdateResult {
    case invalidDisplayName
    case unchanged
    case changed
}

final class LocalPeerIdentityProvider: LocalPeerIdentityReading {
    weak var delegate: LocalPeerIdentityDelegate?

    private var profileStorage: UserProfileStorageProtocol

    let localUserID: String
    private(set) var userDisplayName: String
    private(set) var peerID: MCPeerID

    private(set) var groupEpoch: Int {
        didSet {
            profileStorage.groupEpoch = groupEpoch
        }
    }

    var displayName: String {
        userDisplayName
    }

    var localPeer: ChatPeer {
        ChatPeer(id: localUserID, displayName: displayName)
    }

    init(profileStorage: UserProfileStorageProtocol) {
        self.profileStorage = profileStorage
        self.localUserID = profileStorage.userID

        let initialDisplayName = Self.validatedDisplayName(
            profileStorage.displayName ?? UIDevice.current.name
        ) ?? "Sirius"

        self.groupEpoch = profileStorage.groupEpoch
        self.userDisplayName = initialDisplayName
        self.peerID = MCPeerID(
            displayName: Self.transportDisplayName(
                from: initialDisplayName,
                userID: localUserID
            )
        )
    }

    static func validatedDisplayName(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let collapsedWhitespace = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let shortened = String(collapsedWhitespace.prefix(MPCNetworkConstants.maxDisplayNameLength))
        guard !shortened.isEmpty else { return nil }
        return shortened
    }

    static func transportDisplayName(from userDisplayName: String, userID: String) -> String {
        let normalized = userDisplayName
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)

        var result = ""
        var previousWasSeparator = false

        for scalar in normalized.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
                continue
            }

            if scalar == " " || scalar == "-" || scalar == "_" {
                if !previousWasSeparator {
                    result.append("-")
                    previousWasSeparator = true
                }
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let base = String((trimmed.isEmpty ? "peer" : trimmed).prefix(18))
        let compactID = userID.replacingOccurrences(of: "-", with: "")
        let suffix = String(compactID.suffix(6))
        return "\(base)-\(suffix)"
    }

    func updateDisplayName(_ newName: String) -> LocalPeerIdentityUpdateResult {
        guard let validatedName = Self.validatedDisplayName(newName) else {
            return .invalidDisplayName
        }

        guard validatedName != userDisplayName else {
            return .unchanged
        }

        profileStorage.displayName = validatedName

        groupEpoch += 1
        userDisplayName = validatedName
        peerID = MCPeerID(
            displayName: Self.transportDisplayName(
                from: validatedName,
                userID: localUserID
            )
        )

        delegate?.identityProviderDidChangeIdentity()

        return .changed
    }
}
