//
//  RosterHandler.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
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
import PureXML

class RosterHandler: NSObject, RosterManager, ConnectionHandler, IQHandler, RosterHandlerProxyDelegate {
    
    private let dispatcher: Dispatcher
    private let rosterManager: RosterManager
    private let queue: DispatchQueue
    
    required init(dispatcher: Dispatcher, rosterManager: RosterManager) {
        self.dispatcher = dispatcher
        self.rosterManager = rosterManager
        self.queue = DispatchQueue(
            label: "RosterHandler",
            attributes: []
        )
        super.init()
        dispatcher.add(self, withIQQueryQNames: [PXQName(name: "query", namespace: "jabber:iq:roster")], features: nil)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - Manage Roster
    
    private var rosters: [JID: Roster] = [:]
    
    private func addRoster(for account: JID, completion: ((Roster?, Error?) -> Void)?) {
        if let roster = rosters[account] {
            completion?(roster, nil)
        } else {
            rosterManager.roster(for: account, create: true) { roster, error in
                self.queue.async {
                    self.rosters[account] = roster
                    completion?(roster, error)
                }
            }
        }
    }
    
    private func removeRoster(for account: JID) {
        rosters[account] = nil
    }
    
    private func roster(for account: JID) -> Roster? {
        return rosters[account]
    }
    
    // MARK: - RosterManager
    
    func roster(for account: JID, create _: Bool, completion: @escaping (Roster?, Error?) -> Void) {
        queue.async {
            self.addRoster(for: account) { roster, error in
                if let roster = roster {
                    let proxy = RosterHandlerProxy(roster: roster)
                    proxy.delegate = self
                    completion(proxy, error)
                } else {
                    completion(nil, error)
                }
            }
        }
    }
    
    func deleteRoster(for account: JID, completion: @escaping ((Error?) -> Void)) {
        queue.async {
            self.removeRoster(for: account)
            self.rosterManager.deleteRoster(for: account, completion: completion)
        }
    }
    
    // MARK: - ConnectionHandler
    
    func didConnect(_ account: JID, resumed: Bool, features _: [Feature]?) {
        guard
            resumed == false
        else { return }
        
        queue.async {
            self.addRoster(for: account) { roster, error in
                guard
                    let roster = roster
                else {
                    NSLog("Failed to add roster for account '\(account)': \(error)")
                    return
                }
                
                self.update(roster) { error in
                    if error != nil {
                        NSLog("Failed to update roster for account '\(account)': \(error)")
                    }
                }
            }
        }
    }
    
    func didDisconnect(_ account: JID) {
        queue.async {
            self.removeRoster(for: account)
        }
    }
    
    // MARK: - IQHandler
    
    func handleIQRequest(_ stanza: IQStanza, timeout _: TimeInterval, completion: ((IQStanza?, Error?) -> Swift.Void)? = nil) {
        queue.async {
            guard
                let from = stanza.from,
                let roster = self.roster(for: from.bare()),
                stanza.type == .set
            else {
                NSLog("Did recevie invalid stanza:\n\(stanza.document)")
                completion?(nil, NSError(domain: StanzaErrorDomain, code: StanzaErrorCode.forbidden.rawValue, userInfo: nil))
                return
            }
            let namespaces = ["r": "jabber:iq:roster"]
            guard
                let query = stanza.nodes(forXPath: "./r:query", usingNamespaces: namespaces).first as? PXElement
            else {
                NSLog("Did recevie empty set request from '\(from)'")
                completion?(stanza.makeResponse(), nil)
                return
            }
            do {
                let result = RosterResult(element: query, account: roster.account)
                if let versinedRoster = roster as? VersionedRoster, result.version != nil {
                    if versinedRoster.version != result.version {
                        for item in result.items {
                            switch item.subscription {
                            case .remove:
                                try versinedRoster.remove(item, version: result.version)
                                NSLog("Did remove item '\(item.counterpart)' from roster '\(item.account)' (version: \(result.version))")
                            default:
                                try versinedRoster.add(item, version: result.version)
                                NSLog("Did add/update item '\(item.counterpart)' to/in roster '\(item.account)' (version: \(result.version))")
                            }
                        }
                    }
                } else {
                    for item in result.items {
                        switch item.subscription {
                        case .remove:
                            try roster.remove(item)
                            NSLog("Did remove item '\(item.counterpart)' from roster '\(item.account)'")
                        default:
                            try roster.add(item)
                            NSLog("Did add/update item '\(item.counterpart)' to/in roster '\(item.account)'")
                        }
                    }
                }
            } catch {
                NSLog("Failed to store roster update for account '\(roster.account)': \(error)")
            }
            completion?(stanza.makeResponse(), nil)
        }
    }
    
    // MARK: - RosterHandlerProxyDelegate
    
    func proxy(_ proxy: RosterHandlerProxy, didAdd item: Item) {
        queue.async {
            self.add(item)
        }
    }
    
    func proxy(_ proxy: RosterHandlerProxy, didRemove item: Item) {
        queue.async {
            self.remove(item)
        }
    }
    
    func proxy(_ proxy: RosterHandlerProxy, subscribeTo jid: JID) {
        queue.async {
            let presence = PresenceStanza(from: proxy.roster.account, to: jid.bare())
            presence.type = .subscribe
            self.dispatcher.handlePresence(presence) { (error) in
                NSLog("Failed to subscribe to '\(error)' (account: \(proxy.roster.account))")
            }
        }
    }
    
    func proxy(_ proxy: RosterHandlerProxy, unsubscribeFrom jid: JID) {
        queue.async {
            let presence = PresenceStanza(from: proxy.roster.account, to: jid.bare())
            presence.type = .unsubscribe
            self.dispatcher.handlePresence(presence) { (error) in
                NSLog("Failed to unsubscribe from '\(error)' (account: \(proxy.roster.account))")
            }
        }
    }
    
    func proxy(_ proxy: RosterHandlerProxy, approveSubscriptionOf jid: JID) {
        queue.async {
            let presence = PresenceStanza(from: proxy.roster.account, to: jid.bare())
            presence.type = .subscribed
            self.dispatcher.handlePresence(presence) { (error) in
                NSLog("Failed to approve subscription of '\(error)' (account: \(proxy.roster.account))")
            }
        }
    }
    
    func proxy(_ proxy: RosterHandlerProxy, denySubscriptionOf jid: JID) {
        queue.async {
            let presence = PresenceStanza(from: proxy.roster.account, to: jid.bare())
            presence.type = .unsubscribed
            self.dispatcher.handlePresence(presence) { (error) in
                NSLog("Failed to deny subscription of '\(error)' (account: \(proxy.roster.account))")
            }
        }
    }
    
    // MARK: - Update Roster
    
    private func update(_ roster: Roster, completion _: ((Error?) -> Void)?) {
        let stanza = IQStanza(type: .get, from: roster.account, to: roster.account)
        let query = stanza.add(withName: "query", namespace: "jabber:iq:roster", content: nil)
        if let versionedRoster = roster as? VersionedRoster {
            query.setValue(versionedRoster.version ?? "", forAttribute: "ver")
            NSLog("Requesting roster for account '\(roster.account)' (version: \(versionedRoster.version))")
        } else {
            NSLog("Requesting roster for account '\(roster.account)'")
        }
        dispatcher.handleIQRequest(stanza, timeout: 120.0) { stanza, error in
            self.queue.async {
                guard
                    let stanza = stanza
                else {
                    NSLog("Failed to request the roster for account '\(roster.account)': \(error)")
                    return
                }
                
                let namespaces = ["r": "jabber:iq:roster"]
                guard
                    let query = stanza.nodes(forXPath: "./r:query", usingNamespaces: namespaces).first as? PXElement
                else {
                    NSLog("Did recevie empty response for roster request for account '\(roster.account)'")
                    return
                }
                
                do {
                    let result = RosterResult(element: query, account: roster.account)
                    if let versinedRoster = roster as? VersionedRoster, result.version != nil {
                        if versinedRoster.version != result.version {
                            try versinedRoster.replace(with: result.items, version: result.version)
                            NSLog("Did update roster for account '\(roster.account)' (version: \(result.version))")
                        } else {
                            NSLog("Roster for account '\(roster.account)' is up to date (version: \(result.version)).")
                        }
                    } else if let replaceableRoster = roster as? ReplaceableRoster {
                        try replaceableRoster.replace(with: result.items)
                        NSLog("Did update roster for account '\(roster.account)'")
                    }
                } catch {
                    NSLog("Failed to store roster update for account '\(roster.account)': \(error)")
                }
            }
        }
    }
    
    private func add(_ item: Item) {
        let stanza = IQStanza(type: .set, from: item.account, to: item.account)
        let query = stanza.add(withName: "query", namespace: "jabber:iq:roster", content: nil)
        let itemElement = query.add(withName: "item", namespace: "jabber:iq:roster", content: nil)
        itemElement.setValue(item.counterpart.stringValue, forAttribute: "jid")
        itemElement.setValue(item.name ?? "", forAttribute: "name")
        for name in item.groups {
            itemElement.add(withName: "group", namespace: "jabber:iq:roster", content: name)
        }
        dispatcher.handleIQRequest(stanza, timeout: 120.0) { stanza, error in
            self.queue.async {
                if stanza == nil {
                    NSLog("Failed to add/update item to/in server roster for account '\(item.account)': \(error)")
                } else {
                    NSLog("Did add/update item to/in server roster for account '\(item.account)'")
                }
            }
        }
    }
    
    private func remove(_ item: Item) {
        let stanza = IQStanza(type: .set, from: item.account, to: item.account)
        let query = stanza.add(withName: "query", namespace: "jabber:iq:roster", content: nil)
        let itemElement = query.add(withName: "item", namespace: "jabber:iq:roster", content: nil)
        itemElement.setValue(item.counterpart.stringValue, forAttribute: "jid")
        itemElement.setValue("remove", forAttribute: "subscription")
        dispatcher.handleIQRequest(stanza, timeout: 120.0) { stanza, error in
            self.queue.async {
                if stanza == nil {
                    NSLog("Failed to remove item from server roster for account '\(item.account)': \(error)")
                } else {
                    NSLog("Did remove item from server roster for account '\(item.account)'")
                }
            }
        }
    }
}

protocol RosterHandlerProxyDelegate: class {
    func proxy(_ proxy: RosterHandlerProxy, didAdd item: Item) -> Void
    func proxy(_ proxy: RosterHandlerProxy, didRemove item: Item) -> Void
    func proxy(_ proxy: RosterHandlerProxy, subscribeTo jid: JID) -> Void
    func proxy(_ proxy: RosterHandlerProxy, unsubscribeFrom jid: JID) -> Void
    func proxy(_ proxy: RosterHandlerProxy, approveSubscriptionOf jid: JID) -> Void
    func proxy(_ proxy: RosterHandlerProxy, denySubscriptionOf jid: JID) -> Void
}

class RosterHandlerProxy: Roster {
    
    weak var delegate: RosterHandlerProxyDelegate?
    
    let roster: Roster
    init(roster: Roster) {
        self.roster = roster
    }
    
    var account: JID { return roster.account }
    
    func add(_ item: Item) throws {
        let pendingItem = Item(account: item.account,
                               counterpart: item.counterpart,
                               subscription: item.subscription,
                               pending: .local,
                               name: item.name,
                               groups: item.groups)
        try roster.add(pendingItem)
        delegate?.proxy(self, didAdd: pendingItem)
    }
    
    func remove(_ item: Item) throws {
        let pendingItem = Item(account: item.account,
                               counterpart: item.counterpart,
                               subscription: .remove,
                               pending: .local,
                               name: item.name,
                               groups: item.groups)
        try roster.remove(pendingItem)
        delegate?.proxy(self, didRemove: pendingItem)
    }
    
    func item(for jid: JID) throws -> Item? { return try roster.item(for: jid) }
    
    func items() throws -> [Item] { return try roster.items() }
    func items(in group: String) throws -> [Item] { return try roster.items(in: group) }
    func items(pending: Pending) throws -> [Item] { return try roster.items(pending: pending) }
    
    func groups() throws -> [String] { return try roster.groups() }
    
    func subscribe(to jid: JID) { delegate?.proxy(self, subscribeTo: jid) }
    func unsubscribe(from jid: JID) { delegate?.proxy(self, unsubscribeFrom: jid) }
    func approveSubscription(of jid: JID) { delegate?.proxy(self, approveSubscriptionOf: jid) }
    func denySubscription(of jid: JID) { delegate?.proxy(self, denySubscriptionOf: jid) }
}
