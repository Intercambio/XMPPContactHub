//
//  RosterManager.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public enum RosterManagerError: Error {
    case doesNotExist
    case deleted
}

public protocol RosterManager: class {
    func roster(for account: JID, create: Bool, completion: @escaping (Roster?, Error?) -> Void) -> Void
    func deleteRoster(for account: JID, completion: @escaping ((Error?) -> Void)) -> Void
}
