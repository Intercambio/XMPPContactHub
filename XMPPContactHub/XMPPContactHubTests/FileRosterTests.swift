//
//  FileRosterTests.swift
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


import XCTest
import XMPPFoundation
@testable import XMPPContactHub

class FileRosterTests: TestCase {
    
    var roster: FileRoster?
    
    override func setUp() {
        super.setUp()
        
        guard
            let directory = self.directory,
            let account = JID("romeo@example.com")
        else { return }
        
        let roster = FileRoster(directory: directory, account: account)
        
        let wait = expectation(description: "Open Roster")
        roster.open {
            error in
            XCTAssertNil(error, "Failed to open the roster: \(error?.localizedDescription)")
            wait.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        self.roster = roster
    }
    
    override func tearDown() {
        roster = nil
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testAddAndRemoveItem() {
        guard
            let roster = self.roster
        else {
            XCTFail()
            return
        }
        do {
            let item = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("juliet@example.com")!,
                subscription: .both,
                pending: .none,
                name: "Juliet",
                groups: ["Friends", "Lovers"]
            )
            try roster.add(item, version: nil)
            let items = try roster.items()
            XCTAssertTrue(items.contains(item))
            if let item = items.first {
                XCTAssertEqual(item.subscription, .both)
                XCTAssertEqual(item.name, "Juliet")
                XCTAssertEqual(item.groups.count, 2)
                XCTAssertTrue(item.groups.contains("Friends"))
                XCTAssertTrue(item.groups.contains("Lovers"))
            }
            try roster.remove(item, version: nil)
            XCTAssertFalse(try roster.items().contains(item))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testReplace() {
        guard
            let roster = self.roster
        else {
            XCTFail()
            return
        }
        do {
            let itemA = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("a@example.com")!,
                subscription: .both,
                pending: .none,
                name: "A",
                groups: ["Friends"]
            )
            let itemB = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("b@example.com")!,
                subscription: .both,
                pending: .none,
                name: "B",
                groups: ["Friends"]
            )
            let itemC = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("b@example.com")!,
                subscription: .both,
                pending: .none,
                name: "B",
                groups: ["Friends", "Lovers"]
            )
            
            try roster.add(itemA, version: nil)
            try roster.add(itemB, version: nil)
            try roster.replace(with: [itemC], version: nil)
            let items = try roster.items()
            XCTAssertEqual(items.count, 1)
            XCTAssertTrue(items.contains(itemC))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testGroups() {
        guard
            let roster = self.roster
        else {
            XCTFail()
            return
        }
        do {
            let itemA = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("a@example.com")!,
                subscription: .both,
                pending: .none,
                name: "A",
                groups: ["Friends"]
            )
            let itemB = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("b@example.com")!,
                subscription: .both,
                pending: .none,
                name: "B",
                groups: ["Friends"]
            )
            let itemC = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("c@example.com")!,
                subscription: .both,
                pending: .none,
                name: "B",
                groups: ["Friends", "Lovers"]
            )
            
            try roster.add(itemA, version: nil)
            try roster.add(itemB, version: nil)
            try roster.add(itemC, version: nil)
            
            let groups = try roster.groups()
            XCTAssertEqual(groups.count, 2)
            XCTAssertTrue(groups.contains("Lovers"))
            XCTAssertTrue(groups.contains("Friends"))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testVersion() {
        guard
            let roster = self.roster
        else {
            XCTFail()
            return
        }
        do {
            let item = Item(
                account: JID("romeo@example.com")!,
                counterpart: JID("a@example.com")!,
                subscription: .both,
                pending: .none,
                name: "A",
                groups: ["Friends"]
            )
            try roster.add(item, version: "1534761")
            XCTAssertEqual(roster.version, "1534761")
        } catch {
            XCTFail("\(error)")
        }
    }
}
