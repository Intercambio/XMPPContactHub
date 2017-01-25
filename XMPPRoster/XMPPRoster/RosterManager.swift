//
//  RosterManager.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 25.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import  XMPPFoundation

public protocol RosterManager {
    func roster(for account: JID) throws -> Roster
}
