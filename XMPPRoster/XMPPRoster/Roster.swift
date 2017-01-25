//
//  Roster.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 25.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public enum RosterError: Error {
    case notSetup
    case invalidItem
    case doesNotExist
    case duplicateItem
}

public enum Subscription: String {
    case none = "none"
    case to = "to"
    case from = "from"
    case both = "both"
}

public enum Pending: String {
    case none = "none"
    case local = "locale"
    case remove = "remote"
}

public struct Item: Hashable, Equatable {
    public let account: JID
    public let counterpart: JID
    public let subscription: Subscription
    public let pending: Pending
    public let name: String?
    public let groups: [String]
    public var hashValue: Int {
        return account.hash + counterpart.hash
    }
    public static func ==(lhs: Item, rhs: Item) -> Bool {
        return rhs.account == lhs.account && rhs.counterpart == rhs.counterpart
    }
}

public protocol Roster {
    func add(_ item: Item) throws -> Void
    func remove(_ item: Item) throws -> Void
    func replace(with items: [Item]) throws -> Void
    
    func all() throws -> [Item]
}

public protocol VersionedRoster: Roster {
    func add(_ item: Item, version: String?) throws -> Void
    func remove(_ item: Item, version: String?) throws -> Void
    func replace(with items: [Item], version: String?) throws -> Void
    
    var version: String? { get }
}

extension Notification.Name {
    public static let RosterDidChange = Notification.Name("XMPPRosterDidChange")
}
