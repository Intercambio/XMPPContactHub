//
//  RosterResult.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import PureXML
import XMPPFoundation

struct RosterResult {
    
    let version: String?
    let items: [Item]
    
    init(element: PXElement, account: JID) {
        guard
            element.qualifiedName == PXQName(name: "query", namespace: "jabber:iq:roster")
        else {
            self.version = nil
            self.items = []
            return
        }
        self.version = element.value(forAttribute: "ver") as? String
        var items: [Item] = []
        element.enumerateElements { element, _ in
            if element.qualifiedName == PXQName(name: "item", namespace: "jabber:iq:roster") {
                guard
                    let jidString = element.value(forAttribute: "jid") as? String,
                    let jid = JID(jidString),
                    let subscriptionString = element.value(forAttribute: "subscription") as? String,
                    let subscription = Subscription(rawValue: subscriptionString)
                else {
                    return
                }
                let name = element.value(forAttribute: "name") as? String
                let pending: Pending = element.value(forAttribute: "ask") as? String == "subscribe" ? .remote : .none
                var groups: [String] = []
                element.enumerateElements { group, _ in
                    if group.qualifiedName == PXQName(name: "group", namespace: "jabber:iq:roster") {
                        groups.append((group.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))!)
                    }
                }
                items.append(Item(
                    account: account,
                    counterpart: jid,
                    subscription: subscription,
                    pending: pending,
                    name: name,
                    groups: groups
                ))
                
            }
        }
        self.items = items
    }
}
