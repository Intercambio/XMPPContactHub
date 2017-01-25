//
//  FileRosterTests.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 25.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import XCTest
import XMPPFoundation
@testable import XMPPRoster

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
                XCTFail();
                return
        }
        do {
            let item = Item(account: JID("romeo@example.com")!,
                            counterpart: JID("juliet@example.com")!,
                            subscription: .both,
                            pending: .none,
                            name: "Juliet",
                            groups: ["Friends", "Lovers"])
            try roster.add(item, version: nil)
            let items = try roster.all()
            XCTAssertTrue(items.contains(item))
            if let item = items.first {
                XCTAssertEqual(item.subscription, .both)
                XCTAssertEqual(item.name, "Juliet")
                XCTAssertEqual(item.groups.count, 2)
                XCTAssertTrue(item.groups.contains("Friends"))
                XCTAssertTrue(item.groups.contains("Lovers"))
            }
            try roster.remove(item, version: nil)
            XCTAssertFalse(try roster.all().contains(item))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testReplace() {
        guard
            let roster = self.roster
            else {
                XCTFail();
                return
        }
        do {
            let itemA = Item(account: JID("romeo@example.com")!,
                            counterpart: JID("a@example.com")!,
                            subscription: .both,
                            pending: .none,
                            name: "A",
                            groups: ["Friends"])
            let itemB = Item(account: JID("romeo@example.com")!,
                             counterpart: JID("b@example.com")!,
                             subscription: .both,
                             pending: .none,
                             name: "B",
                             groups: ["Friends"])
            let itemC = Item(account: JID("romeo@example.com")!,
                             counterpart: JID("b@example.com")!,
                             subscription: .both,
                             pending: .none,
                             name: "B",
                             groups: ["Friends", "Lovers"])
            
            try roster.add(itemA, version: nil)
            try roster.add(itemB, version: nil)
            try roster.replace(with: [itemC], version: nil)
            let items = try roster.all()
            XCTAssertEqual(items.count, 1)
            XCTAssertTrue(items.contains(itemC))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testVersion() {
        guard
            let roster = self.roster
            else {
                XCTFail();
                return
        }
        do {
            let item = Item(account: JID("romeo@example.com")!,
                             counterpart: JID("a@example.com")!,
                             subscription: .both,
                             pending: .none,
                             name: "A",
                             groups: ["Friends"])
            try roster.add(item, version: "1534761")
            XCTAssertEqual(roster.version, "1534761")
        } catch {
            XCTFail("\(error)")
        }
    }
}
