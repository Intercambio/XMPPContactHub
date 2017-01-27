//
//  ContactHub.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public class ContactHub: NSObject, RosterManager {
    
    private let queue: DispatchQueue
    private let dispatcher: Dispatcher
    private let rosterManager: RosterManager
    private let rosterHandler: RosterHandler
    
    public required init(dispatcher: Dispatcher, directory: URL) {
        self.dispatcher = dispatcher
        
        let rosterDirectory = directory.appendingPathComponent("roster", isDirectory: true)
        self.rosterManager = FileRosterManager(directory: rosterDirectory)
        self.rosterHandler = RosterHandler(dispatcher: dispatcher, rosterManager: rosterManager)
        queue = DispatchQueue(label: "Contact Hub", attributes: [.concurrent])
    }
    
    // MARK: - RosterManager
    
    public func roster(for account: JID, create: Bool, completion: @escaping (Roster?, Error?) -> Void) {
        rosterHandler.roster(for: account, create: create, completion: completion)
    }
    
    public func deleteRoster(for account: JID, completion: @escaping ((Error?) -> Void)) {
        rosterHandler.deleteRoster(for: account, completion: completion)
    }
}
