//
//  RosterHandler.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import PureXML

class RosterHandler: NSObject, ConnectionHandler {
    
    private let dispatcher: Dispatcher
    private let rosterManager: RosterManager
    private let queue: DispatchQueue
    
    required init(dispatcher: Dispatcher, rosterManager: RosterManager) {
        self.dispatcher = dispatcher
        self.rosterManager = rosterManager
        self.queue = DispatchQueue(
            label: "RosterHandler",
            attributes: [.concurrent]
        )
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    // MARK: - Manage Roster
    
    private var rosters: [JID:Roster] = [:]
    
    private func addRoster(for account: JID, completion: ((Roster?, Error?)->Void)?) {
        if let roster = rosters[account] {
            completion?(roster, nil)
        } else {
            rosterManager.roster(for: account, create: true) { (roster, error) in
                self.queue.async {
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
    
    // MARK: - ConnectionHandler
    
    func didConnect(_ account: JID, resumed: Bool, features _: [Feature]?) {
        guard
            resumed == false
            else { return }
        
        queue.async {
            self.addRoster(for: account) { (roster, error) in
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
    
    // MARK: - Update Roster
    
    private func update(_ roster: Roster, completion: ((Error?)->Void)?)  {
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
                    } else {
                        try roster.replace(with: result.items)
                        NSLog("Did update roster for account '\(roster.account)'")
                    }
                } catch {
                    NSLog("Failed to store roster update for account '\(roster.account)': \(error)")
                }
            }
        }
    }
}
