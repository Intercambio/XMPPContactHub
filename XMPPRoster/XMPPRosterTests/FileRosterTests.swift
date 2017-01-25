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

    func testAddItem() {
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
                            name: "Juliet",
                            groups: ["Friends", "Lovers"])
            try roster.add(item)
            let items = try roster.all()
            XCTAssertTrue(items.contains(item))
            if let item = items.first {
                XCTAssertEqual(item.subscription, .both)
                XCTAssertEqual(item.name, "Juliet")
                XCTAssertEqual(item.groups.count, 2)
                XCTAssertTrue(item.groups.contains("Friends"))
                XCTAssertTrue(item.groups.contains("Lovers"))
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
