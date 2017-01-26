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
    
    public required init(dispatcher: Dispatcher, directory: URL) {
        self.dispatcher = dispatcher
        
        let rosterDirectory = directory.appendingPathComponent("roster", isDirectory: true)
        self.rosterManager = FileRosterManager(directory: rosterDirectory)
        
        queue = DispatchQueue(label: "Contact Hub", attributes: [.concurrent])
    }
    
    // MARK: - RosterManager
    
    public func roster(for account: JID, create: Bool, completion: @escaping (Roster?, Error?) -> Void) {
        rosterManager.roster(for: account, create: create, completion: completion)
    }
    
    public func deleteRoster(for account: JID, completion: @escaping ((Error?) -> Void)) {
        deleteRoster(for: account, completion: completion)
    }
}
