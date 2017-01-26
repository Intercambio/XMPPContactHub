//
//  FileRosterManagerTests.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import XCTest
import XMPPFoundation
@testable import XMPPRoster

class FileRosterManagerTests: TestCase {
    
    var rosterManager: RosterManager?
    
    override func setUp() {
        super.setUp()
        guard let directory = self.directory else { return }
        self.rosterManager = FileRosterManager(directory: directory)
    }
    
    override func tearDown() {
        self.rosterManager = nil
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testOpenRoster() {
        guard let rosterManager = self.rosterManager else { XCTFail(); return }
        
        var expectation = self.expectation(description: "Open")
        rosterManager.roster(for: JID("romeo@example.com")!, create: false) {
            roster, error in
            XCTAssertNil(roster)
            XCTAssertEqual(error as? RosterManagerError, RosterManagerError.doesNotExist)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        rosterManager.roster(for: JID("romeo@example.com")!, create: true) {
            roster, error in
            XCTAssertNotNil(roster)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        rosterManager.roster(for: JID("romeo@example.com")!, create: false) {
            roster, error in
            XCTAssertNotNil(roster)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Delete")
        rosterManager.deleteRoster(for: JID("romeo@example.com")!) {
            error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        expectation = self.expectation(description: "Open")
        rosterManager.roster(for: JID("romeo@example.com")!, create: false) {
            roster, error in
            XCTAssertNil(roster)
            XCTAssertEqual(error as? RosterManagerError, RosterManagerError.doesNotExist)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
