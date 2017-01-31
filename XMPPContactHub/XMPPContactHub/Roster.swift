//
//  Roster.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 25.01.17.
//  Copyright © 2017 Tobias Kräntzer.
//
//  This file is part of XMPPContactHub.
//
//  XMPPContactHub is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  XMPPContactHub is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  XMPPContactHub. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
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
        return account.hashValue ^ counterpart.hashValue
    }
    public static func ==(lhs: Item, rhs: Item) -> Bool {
        return lhs.account == rhs.account && lhs.counterpart == rhs.counterpart
    }
    public init(
        account: JID,
        counterpart: JID,
        subscription: Subscription,
        pending: Pending,
        name: String?,
        groups: [String]
    ) {
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
    
    func subscribe(to jid: JID) -> Void
    func unsubscribe(from jid: JID) -> Void
    func approveSubscription(of jid: JID) -> Void
    func denySubscription(of jid: JID) -> Void
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
