//
//  Roster.swift
//  XMPPRoster
//
//  Created by Tobias Kraentzer on 25.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation

public enum Subscription {
    case none
    case to
    case from
    case both
}

public struct Item {
    let account: JID
    let counterpart: JID
    let subscription: Subscription
    let name: String?
    let groups: [String]
}

public protocol Roster {
    func items() -> [Item]
}

extension Notification.Name {
    public static let RosterDidChange = Notification.Name("XMPPRosterDidChange")
}
