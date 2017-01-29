//
//  RosterResult.swift
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
                    let jid = JID(jidString)
                else {
                    return
                }
                
                let subscriptionString = element.value(forAttribute: "subscription") as? String ?? ""
                let subscription = Subscription(rawValue: subscriptionString) ?? .none
                
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
