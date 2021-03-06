//
//  FileRoster.swift
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
import SQLite

public class FileRoster: VersionedRoster {
    
    public let directory: URL
    public let account: JID
    
    private let queue: DispatchQueue
    
    public required init(directory: URL, account: JID) {
        queue = DispatchQueue(
            label: "Roster (\(account.stringValue))",
            attributes: [.concurrent]
        )
        
        self.directory = directory
        self.account = account.bare()
    }
    
    private var db: SQLite.Connection?
    
    // MARK: - Open & Close
    
    public func open(completion: @escaping (Error?) -> Void) {
        queue.async(flags: [.barrier]) {
            do {
                try self.open()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    public func close() {
        queue.sync(flags: [.barrier]) {
            self.db = nil
        }
    }
    
    private func open() throws {
        let setup = FileRosterSchema(directory: directory)
        db = try setup.run()
    }
    
    // MARK: - Roster
    
    public var version: String? {
        return queue.sync {
            guard
                let db = self.db
            else { return nil }
            do {
                let query = FileRosterSchema.option
                    .filter(FileRosterSchema.option_key == "version")
                    .select(FileRosterSchema.option_value)
                if let row = try db.pluck(query) {
                    return row[FileRosterSchema.option_value]
                } else {
                    return nil
                }
            } catch {
                return nil
            }
        }
    }
    
    public func add(_ item: Item) throws { try add(item, version: nil) }
    public func add(_ item: Item, version: String?) throws {
        try queue.sync {
            guard
                let db = self.db
            else { throw RosterError.notSetup }
            
            guard
                item.account == self.account
            else { throw RosterError.invalidItem }
            
            try db.transaction {
                _ = try db.run(
                    FileRosterSchema.item.insert(
                        or: .replace,
                        FileRosterSchema.item_jid <- item.counterpart,
                        FileRosterSchema.item_subscription <- item.subscription,
                        FileRosterSchema.item_pending <- item.pending,
                        FileRosterSchema.item_name <- item.name
                    )
                )
                _ = try db.run(
                    FileRosterSchema.group.filter(FileRosterSchema.group_jid == item.counterpart).delete()
                )
                for name in item.groups {
                    _ = try db.run(
                        FileRosterSchema.group.insert(
                            FileRosterSchema.group_jid <- item.counterpart,
                            FileRosterSchema.group_name <- name
                        )
                    )
                }
                
                if let value = version {
                    _ = try db.run(
                        FileRosterSchema.option.insert(
                            or: .replace,
                            FileRosterSchema.option_key <- "version",
                            FileRosterSchema.option_value <- value
                        )
                    )
                } else {
                    _ = try db.run(
                        FileRosterSchema.option.filter(FileRosterSchema.option_key == "version").delete()
                    )
                }
            }
            self.postChangeNotification()
        }
    }
    
    public func remove(_ item: Item) throws { try remove(item, version: nil) }
    public func remove(_ item: Item, version: String?) throws {
        try queue.sync {
            guard
                let db = self.db
            else { throw RosterError.notSetup }
            
            try db.transaction {
                _ = try db.run(
                    FileRosterSchema.item.filter(FileRosterSchema.item_jid == item.counterpart).delete()
                )
                _ = try db.run(
                    FileRosterSchema.group.filter(FileRosterSchema.group_jid == item.counterpart).delete()
                )
                if let value = version {
                    _ = try db.run(
                        FileRosterSchema.option.insert(
                            or: .replace,
                            FileRosterSchema.option_key <- "version",
                            FileRosterSchema.option_value <- value
                        )
                    )
                } else {
                    _ = try db.run(
                        FileRosterSchema.option.filter(FileRosterSchema.option_key == "version").delete()
                    )
                }
            }
            self.postChangeNotification()
        }
    }
    
    public func replace(with items: [Item]) throws { try replace(with: items, version: nil) }
    public func replace(with items: [Item], version: String?) throws {
        try queue.sync {
            guard
                let db = self.db
            else { throw RosterError.notSetup }
            
            try db.transaction {
                _ = try db.run(
                    FileRosterSchema.item.delete()
                )
                _ = try db.run(
                    FileRosterSchema.group.delete()
                )
                
                for item in items {
                    guard
                        item.account == self.account
                    else { throw RosterError.invalidItem }
                    
                    _ = try db.run(
                        FileRosterSchema.item.insert(
                            or: .replace,
                            FileRosterSchema.item_jid <- item.counterpart,
                            FileRosterSchema.item_subscription <- item.subscription,
                            FileRosterSchema.item_pending <- item.pending,
                            FileRosterSchema.item_name <- item.name
                        )
                    )
                    for name in item.groups {
                        _ = try db.run(
                            FileRosterSchema.group.insert(
                                FileRosterSchema.group_jid <- item.counterpart,
                                FileRosterSchema.group_name <- name
                            )
                        )
                    }
                }
                if let value = version {
                    _ = try db.run(
                        FileRosterSchema.option.insert(
                            or: .replace,
                            FileRosterSchema.option_key <- "version",
                            FileRosterSchema.option_value <- value
                        )
                    )
                } else {
                    _ = try db.run(
                        FileRosterSchema.option.filter(FileRosterSchema.option_key == "version").delete()
                    )
                }
            }
            self.postChangeNotification()
        }
    }
    
    public func item(for jid: JID) throws -> Item? {
        return try queue.sync {
            return try self.all().first(where: { (item) -> Bool in
                return item.counterpart == jid
            })
        }
    }
    
    public func items() throws -> [Item] {
        return try queue.sync {
            return try self.all()
        }
    }
    
    public func items(in group: String) throws -> [Item] {
        return try queue.sync {
            return try self.all().filter({ (item) -> Bool in
                item.groups.contains(group)
            })
        }
    }
    
    public func items(pending: Pending) throws -> [Item] {
        return try queue.sync {
            return try self.all().filter({ (item) -> Bool in
                item.pending == pending
            })
        }
    }
    
    public func groups() throws -> [String] {
        return try queue.sync {
            guard
                let db = self.db
            else { throw RosterError.notSetup }
            
            var groups: [String] = []
            try db.transaction {
                let groupQuery = FileRosterSchema.group.select(distinct: FileRosterSchema.group_name)
                for row in try db.prepare(groupQuery) {
                    let name = row.get(FileRosterSchema.group_name)
                    groups.append(name)
                }
            }
            return groups
        }
    }
    
    public func subscribe(to jid: JID) {}
    public func unsubscribe(from jid: JID) {}
    public func approveSubscription(of jid: JID) {}
    public func denySubscription(of jid: JID) {}
    
    private func all() throws -> [Item] {
        guard
            let db = self.db
        else { throw RosterError.notSetup }
        
        var items: [Item] = []
        try db.transaction {
            
            var groupsByCounterpart: [JID: [String]] = [:]
            
            let groupQuery = FileRosterSchema.group.select(
                FileRosterSchema.group_jid,
                FileRosterSchema.group_name
            )
            
            for row in try db.prepare(groupQuery) {
                let jid = row.get(FileRosterSchema.group_jid)
                let name = row.get(FileRosterSchema.group_name)
                var groups = groupsByCounterpart[jid] ?? []
                groups.append(name)
                groupsByCounterpart[jid] = groups
            }
            
            let itemQuery = FileRosterSchema.item.select(
                FileRosterSchema.item_jid,
                FileRosterSchema.item_subscription,
                FileRosterSchema.item_pending,
                FileRosterSchema.item_name
            )
            
            for row in try db.prepare(itemQuery) {
                let counterpart = row.get(FileRosterSchema.item_jid)
                let subscription = row.get(FileRosterSchema.item_subscription)
                let pending = row.get(FileRosterSchema.item_pending)
                let name = row.get(FileRosterSchema.item_name)
                let groups = groupsByCounterpart[counterpart] ?? []
                let item = Item(
                    account: self.account,
                    counterpart: counterpart,
                    subscription: subscription,
                    pending: pending,
                    name: name,
                    groups: groups
                )
                items.append(item)
            }
        }
        return items
    }
    
    private func postChangeNotification() {
        DispatchQueue.main.async {
            let center = NotificationCenter.default
            center.post(name: Notification.Name.RosterDidChange, object: self)
        }
    }
}

class FileRosterSchema {
    
    static let item = Table("item")
    static let item_jid = Expression<JID>("jid")
    static let item_subscription = Expression<Subscription>("subscription")
    static let item_pending = Expression<Pending>("pending")
    static let item_name = Expression<String?>("name")
    static let group = Table("group")
    static let group_jid = Expression<JID>("jid")
    static let group_name = Expression<String>("name")
    static let option = Table("option")
    static let option_key = Expression<String>("key")
    static let option_value = Expression<String>("value")
    
    static let version: Int = 1
    
    var version: Int {
        return readCurrentVersion()
    }
    
    var databaseLocation: URL {
        return directory.appendingPathComponent("db.sqlite", isDirectory: false)
    }
    
    let directory: URL
    required init(directory: URL) {
        self.directory = directory
    }
    
    func run() throws -> SQLite.Connection {
        let db = try createDatabase()
        if readCurrentVersion() == 0 {
            try setup(db)
            try writeCurrentVersion(FileRosterSchema.version)
        }
        return db
    }
    
    private func createDatabase() throws -> SQLite.Connection {
        let db = try Connection(databaseLocation.path)
        
        db.busyTimeout = 5
        db.busyHandler({ tries in
            if tries >= 3 {
                return false
            }
            return true
        })
        
        return db
    }
    
    private func setup(_ db: SQLite.Connection) throws {
        try db.run(FileRosterSchema.item.create { t in
            t.column(FileRosterSchema.item_jid, primaryKey: true)
            t.column(FileRosterSchema.item_subscription)
            t.column(FileRosterSchema.item_pending)
            t.column(FileRosterSchema.item_name)
        })
        try db.run(FileRosterSchema.group.create { t in
            t.column(FileRosterSchema.group_jid)
            t.column(FileRosterSchema.group_name)
            t.foreignKey(FileRosterSchema.group_jid, references: FileRosterSchema.item, FileRosterSchema.item_jid)
            t.unique([FileRosterSchema.group_jid, FileRosterSchema.group_name])
        })
        try db.run(FileRosterSchema.option.create { t in
            t.column(FileRosterSchema.option_key, primaryKey: true)
            t.column(FileRosterSchema.option_value)
        })
    }
    
    private func readCurrentVersion() -> Int {
        let url = directory.appendingPathComponent("version.txt")
        do {
            let versionText = try String(contentsOf: url)
            guard let version = Int(versionText) else { return 0 }
            return version
        } catch {
            return 0
        }
    }
    
    private func writeCurrentVersion(_ version: Int) throws {
        let url = directory.appendingPathComponent("version.txt")
        let versionData = String(version).data(using: .utf8)
        try versionData?.write(to: url)
    }
}

extension JID: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> JID {
        return JID(datatypeValue)!
    }
    public var datatypeValue: String {
        return self.stringValue
    }
}

extension Subscription: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> Subscription {
        return Subscription(rawValue: datatypeValue)!
    }
    public var datatypeValue: String {
        return self.rawValue
    }
}

extension Pending: Value {
    public static var declaredDatatype: String {
        return String.declaredDatatype
    }
    public static func fromDatatypeValue(_ datatypeValue: String) -> Pending {
        return Pending(rawValue: datatypeValue)!
    }
    public var datatypeValue: String {
        return self.rawValue
    }
}
