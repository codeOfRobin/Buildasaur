//
//  SyncerConfig.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/3/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils

public typealias RefType = String

public struct Ref {
    static func new() -> RefType {
        #if TESTING
            let ref = testIds[counter % testIds.count]
            counter += 1
            return ref
        #else
            return NSUUID().uuidString
        #endif
    }
    
    #if TESTING
    static func reset() {
        counter = 0
    }
    
    static var counter: Int = 0
    static let testIds: [RefType] = [
        "D143B09C-CB1B-4831-8BA1-E2F8AB039B56",
        "4E8E7708-01FB-448A-B929-A54887CC5857",
        "564C267D-FF06-4008-9EF6-66B3AC1A3BDE",
        "E8F5285A-A262-4630-AF7B-236772B75760",
        "4E66D0D5-D5CC-417E-A40E-73B513CE4E10",
        "EF4B87DC-5B08-4D3B-8DE8-EC7A6F25DDBC",
        "91938FA7-16BB-416F-B270-8B4E11361FB6",
        "130D38FC-2599-485D-9DD4-A1E3622728B4",
        "D8E3766E-922A-4B9B-A3C9-71FE77A2CB0C",
        "EADFC401-1164-4771-85E8-E473E95221FA"
    ]
    #endif
}

public struct SyncerConfig {
    
    public let id: RefType
    public var preferredTemplateRef: RefType
    public var projectRef: RefType
    public var xcodeServerRef: RefType
    
    public var postStatusComments: Bool
    public var syncInterval: TimeInterval
    public var waitForLttm: Bool
    public var watchedBranchNames: [String]
    
    //creates a default syncer config
    public init() {
        self.id = Ref.new()
        self.preferredTemplateRef = ""
        self.projectRef = ""
        self.xcodeServerRef = ""
        self.postStatusComments = true
        self.syncInterval = 15
        self.waitForLttm = false
        self.watchedBranchNames = []
    }
}

private struct Keys {
    
    static let Id = "id"
    static let PreferredTemplateRef = "preferred_template_ref"
    static let ProjectRef = "project_ref"
    static let ServerRef = "server_ref"
    
    static let PostStatusComments = "post_status_comments"
    static let SyncInterval = "sync_interval"
    static let WaitForLttm = "wait_for_lttm"
    static let WatchedBranches = "watched_branches"
}

extension SyncerConfig: JSONSerializable {
    
    public func jsonify() -> [String : Any] {
        return [
            Keys.Id: self.id,
            Keys.PreferredTemplateRef: self.preferredTemplateRef,
            Keys.ProjectRef: self.projectRef,
            Keys.ServerRef: self.xcodeServerRef,
            Keys.PostStatusComments: self.postStatusComments,
            Keys.SyncInterval: self.syncInterval,
            Keys.WaitForLttm: self.waitForLttm,
            Keys.WatchedBranches: self.watchedBranchNames
        ]
    }
    
    public init(json: [String : Any]) throws {
        self.preferredTemplateRef = json[Keys.PreferredTemplateRef] as! String
        self.projectRef = json[Keys.ProjectRef] as! String
        self.xcodeServerRef = json[Keys.ServerRef] as! String
        self.postStatusComments = json[Keys.PostStatusComments] as! Bool
        self.syncInterval = json[Keys.SyncInterval] as! TimeInterval
        self.waitForLttm = json[Keys.WaitForLttm] as! Bool
        self.watchedBranchNames = json[Keys.WatchedBranches] as! [String]
        self.id = (json[Keys.Id] as? RefType) ?? Ref.new()
    }
}
