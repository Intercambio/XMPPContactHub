//
//  FileRosterManager.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public class FileRosterManager: RosterManager {
    
    public let directory: URL
    
    private typealias CompletionHandler = (Roster?, Error?) -> Void
    
    private struct PendingRoster {
        let archvie: Roster
        var handler: [CompletionHandler]
    }
    
    private let queue: DispatchQueue
    private var rosterByAccount: [JID: FileRoster] = [:]
    private var pendingRosterByAccount: [JID: PendingRoster] = [:]
    
    public required init(directory: URL) {
        self.directory = directory
        queue = DispatchQueue(
            label: "RosterManager",
            attributes: []
        )
    }
    
    // MARK: - RosterManager
    
    public func roster(for account: JID, create: Bool, completion: @escaping (Roster?, Error?) -> Void) {
        queue.async {
            do {
                if let roster = self.rosterByAccount[account] {
                    completion(roster, nil)
                } else if var pendingRoster = self.pendingRosterByAccount[account] {
                    pendingRoster.handler.append(completion)
                } else {
                    let roster = try self.openRoster(for: account, create: create)
                    let pendingRoster = PendingRoster(archvie: roster, handler: [completion])
                    self.pendingRosterByAccount[account] = pendingRoster
                    self.open(roster)
                }
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func deleteRoster(for account: JID, completion: @escaping ((Error?) -> Void)) {
        queue.async {
            do {
                if let roster = self.rosterByAccount[account] {
                    self.rosterByAccount[account] = nil
                    roster.close()
                } else if let pendingRoster = self.pendingRosterByAccount[account] {
                    self.pendingRosterByAccount[account] = nil
                    for completion in pendingRoster.handler {
                        completion(nil, RosterManagerError.deleted)
                    }
                }
                try self.deleteRoster(for: account)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func open(_ roster: FileRoster) {
        roster.open { error in
            self.queue.async {
                if let pendingRoster = self.pendingRosterByAccount[roster.account] {
                    self.pendingRosterByAccount[roster.account] = nil
                    if error == nil {
                        self.rosterByAccount[roster.account] = roster
                    }
                    for completion in pendingRoster.handler {
                        completion(roster, error)
                    }
                }
            }
        }
    }
    
    private func openRoster(for account: JID, create: Bool) throws -> FileRoster {
        let location = rosterLocation(for: account)
        if create == false && FileManager.default.fileExists(atPath: location.path, isDirectory: nil) == false {
            throw RosterManagerError.doesNotExist
        }
        try FileManager.default.createDirectory(
            at: location,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return FileRoster(directory: location, account: account)
    }
    
    private func deleteRoster(for account: JID) throws {
        let location = rosterLocation(for: account)
        try FileManager.default.removeItem(at: location)
    }
    
    private func rosterLocation(for account: JID) -> URL {
        let name = account.stringValue
        return directory.appendingPathComponent(name, isDirectory: true)
    }
    
}
