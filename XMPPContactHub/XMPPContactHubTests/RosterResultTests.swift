//
//  RosterResultTests.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import XCTest
import XMPPFoundation
import PureXML
@testable import XMPPContactHub

class RosterResultTests: TestCase {
    
    func testResultWithElement() {
        guard
            let account = JID("romeo@example.com"),
            let document = PXDocument(named: "roster.xml", in: Bundle(for: RosterResultTests.self))
        else { XCTFail(); return }
        
        let result = RosterResult(element: document.root, account: account)
        
        XCTAssertEqual(result.version, "ver7")
        XCTAssertEqual(result.items.count, 3)
    }
}
