//
//  FileRosterManager.swift
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
