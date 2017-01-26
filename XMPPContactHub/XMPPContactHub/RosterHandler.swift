//
//  RosterHandler.swift
//  XMPPContactHub
//
//  Created by Tobias Kraentzer on 26.01.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import XMPPFoundation
import PureXML

class RosterHandler: NSObject, ConnectionHandler, RosterRequestDelegate {
    
    private let dispatcher: Dispatcher
    private let rosterManager: RosterManager
    private let queue: DispatchQueue
    
    private var pendingRequests: [JID: PendingRequest] = [:]
    
    struct PendingRequest {
        typealias CompletionHandler = (Error?) -> Void
        var request: RosterRequest?
        var completionHandler: [CompletionHandler]
    }
    
    required init(dispatcher: Dispatcher, rosterManager: RosterManager) {
        self.dispatcher = dispatcher
        self.rosterManager = rosterManager
        self.queue = DispatchQueue(
            label: "RosterHandler",
            attributes: [.concurrent]
        )
        super.init()
        dispatcher.add(self)
    }
    
    deinit {
        dispatcher.remove(self)
    }
    
    func requestRoster(for account: JID, completion: ((Error?) -> Void)?) {
        queue.async {
            if var pendingRequest = self.pendingRequests[account] {
                if let handler = completion {
                    pendingRequest.completionHandler.append(handler)
                    self.pendingRequests[account] = pendingRequest
                }
            } else {
                var pendingRequest = PendingRequest(request: nil, completionHandler: [])
                if let handler = completion {
                    pendingRequest.completionHandler.append(handler)
                }
                self.pendingRequests[account] = pendingRequest
                self.rosterManager.roster(for: account, create: true) { roster, error in
                    self.queue.async {
                        if let accountRoster = roster {
                            if var pendingRequest = self.pendingRequests[account] {
                                let request = RosterRequest(dispatcher: self.dispatcher, roster: accountRoster)
                                request.delegate = self
                                pendingRequest.request = request
                                self.pendingRequests[account] = pendingRequest
                                request.run()
                            }
                        } else {
                            if let pendingRequest = self.pendingRequests[account] {
                                let error = error ?? RosterRequestError.invalidResponse
                                for handler in pendingRequest.completionHandler {
                                    handler(error)
                                }
                            }
                            self.pendingRequests[account] = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - ConnectionHandler
    
    func didConnect(_ JID: JID, resumed: Bool, features _: [Feature]?) {
        if resumed == false {
            requestRoster(for: JID, completion: nil)
        }
    }
    
    func didDisconnect(_: JID) {
    }
    
    // MARK: - RosterRequestDelegate
    
    func rosterRequest(_ request: RosterRequest, didFailWith error: Error?) {
        queue.async {
            let account = request.roster.account
            if let pendingRequest = self.pendingRequests[account] {
                for handler in pendingRequest.completionHandler {
                    handler(error ?? RosterRequestError.invalidResponse)
                }
            }
            self.pendingRequests[account] = nil
        }
    }
    
    func rosterRequestDidSuccess(_ request: RosterRequest) {
        queue.async {
            let account = request.roster.account
            if let pendingRequest = self.pendingRequests[account] {
                for handler in pendingRequest.completionHandler {
                    handler(nil)
                }
            }
            self.pendingRequests[account] = nil
        }
    }
}

protocol RosterRequestDelegate: class {
    func rosterRequest(_ request: RosterRequest, didFailWith error: Error?) -> Void
    func rosterRequestDidSuccess(_ request: RosterRequest) -> Void
}

enum RosterRequestError: Error {
    case alreadyRunning
    case invalidResponse
}

class RosterRequest {
    
    weak var delegate: RosterRequestDelegate?
    let dispatcher: Dispatcher
    let roster: Roster
    
    private let queue: DispatchQueue
    
    required init(dispatcher: Dispatcher, roster: Roster) {
        self.dispatcher = dispatcher
        self.roster = roster
        self.queue = DispatchQueue(
            label: "RosterRequest",
            attributes: [.concurrent]
        )
    }
    
    func run() {
        queue.sync {
            let stanza = IQStanza(type: .get, from: roster.account, to: roster.account)
            let query = stanza.add(withName: "query", namespace: "jabber:iq:roster", content: nil)
            if let versionedRoster = roster as? VersionedRoster {
                query.setValue(versionedRoster.version ?? "", forAttribute: "ver")
            }
            dispatcher.handleIQRequest(stanza, timeout: 120.0) { stanza, error in
                self.queue.async {
                    if let response = stanza {
                        self.handleResultResponse(stanza: response)
                    } else {
                        self.handleErrorResponse(error: error ?? RosterRequestError.invalidResponse)
                    }
                }
            }
        }
    }
    
    private func handleErrorResponse(error: Error) {
        self.delegate?.rosterRequest(self, didFailWith: error)
    }
    
    private func handleResultResponse(stanza: IQStanza) {
        let namespaces = ["r": "jabber:iq:roster"]
        guard
            let query = stanza.nodes(forXPath: "./r:query", usingNamespaces: namespaces).first as? PXElement
        else {
            self.delegate?.rosterRequestDidSuccess(self)
            return
        }
        
        do {
            let result = RosterResult(element: query, account: roster.account)
            if let versinedRoster = roster as? VersionedRoster, result.version != nil {
                if versinedRoster.version != result.version {
                    try versinedRoster.replace(with: result.items, version: result.version)
                }
            } else {
                try roster.replace(with: result.items)
            }
            self.delegate?.rosterRequestDidSuccess(self)
        } catch {
            self.handleErrorResponse(error: error)
        }
    }
}
