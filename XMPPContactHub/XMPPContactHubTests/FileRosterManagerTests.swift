//
//  FileRosterManagerTests.swift
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


import XCTest
import XMPPFoundation
@testable import XMPPContactHub

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
