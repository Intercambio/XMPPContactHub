//
//  Roster.swift
//  XMPPContactHub
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
    case none
    case to
    case from
    case both
    case remove
}

public enum Pending: String {
    case none
    case local
    case remote
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
    public init(account: JID,
                counterpart: JID,
                subscription: Subscription,
                pending: Pending,
                name: String?,
                groups: [String]) {
        self.account = account
        self.counterpart = counterpart
        self.subscription = subscription
        self.pending = pending
        self.name = name
        self.groups = groups
    }
}

public protocol Roster {
    
    var account: JID { get }
    
    func add(_ item: Item) throws -> Void
    func remove(_ item: Item) throws -> Void
    
    func item(for jid: JID) throws -> Item?
    
    func items() throws -> [Item]
    func items(in group: String) throws -> [Item]
    func items(pending: Pending) throws -> [Item]
    
    func groups() throws -> [String]
}

extension Notification.Name {
    public static let RosterDidChange = Notification.Name("XMPPContactHubDidChange")
}

protocol ReplaceableRoster: Roster {
    func replace(with items: [Item]) throws -> Void
}

protocol VersionedRoster: ReplaceableRoster {
    func add(_ item: Item, version: String?) throws -> Void
    func remove(_ item: Item, version: String?) throws -> Void
    func replace(with items: [Item], version: String?) throws -> Void
    
    var version: String? { get }
}
