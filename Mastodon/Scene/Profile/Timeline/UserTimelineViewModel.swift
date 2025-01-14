//
//  UserTimelineViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-29.
//

import os.log
import UIKit
import GameplayKit
import Combine
import CoreData
import CoreDataStack
import MastodonSDK

final class UserTimelineViewModel {
    
    var disposeBag = Set<AnyCancellable>()

    // input
    let context: AppContext
    @Published var domain: String?
    @Published var userID: String?
    @Published var queryFilter: QueryFilter
    let statusFetchedResultsController: StatusFetchedResultsController
    let listBatchFetchViewModel = ListBatchFetchViewModel()

    let isBlocking = CurrentValueSubject<Bool, Never>(false)
    let isBlockedBy = CurrentValueSubject<Bool, Never>(false)
    let isSuspended = CurrentValueSubject<Bool, Never>(false)
    let userDisplayName = CurrentValueSubject<String?, Never>(nil)  // for suspended prompt label
    var dataSourceDidUpdate = PassthroughSubject<Void, Never>()

    // output
    var diffableDataSource: UITableViewDiffableDataSource<StatusSection, StatusItem>?
    private(set) lazy var stateMachine: GKStateMachine = {
        let stateMachine = GKStateMachine(states: [
            State.Initial(viewModel: self),
            State.Reloading(viewModel: self),
            State.Fail(viewModel: self),
            State.Idle(viewModel: self),
            State.Loading(viewModel: self),
            State.NoMore(viewModel: self),
        ])
        stateMachine.enter(State.Initial.self)
        return stateMachine
    }()

    init(
        context: AppContext,
        domain: String?,
        userID: String?,
        queryFilter: QueryFilter
    ) {
        self.context = context
        self.statusFetchedResultsController = StatusFetchedResultsController(
            managedObjectContext: context.managedObjectContext,
            domain: domain,
            additionalTweetPredicate: Status.notDeleted()
        )
        self.domain = domain
        self.userID = userID
        self.queryFilter = queryFilter
        // super.init()

        $domain
            .assign(to: \.value, on: statusFetchedResultsController.domain)
            .store(in: &disposeBag)
        
        
    }

    deinit {
        os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }

}

extension UserTimelineViewModel {
    struct QueryFilter {
        let excludeReplies: Bool?
        let excludeReblogs: Bool?
        let onlyMedia: Bool?
        
        init(
            excludeReplies: Bool? = nil,
            excludeReblogs: Bool? = nil,
            onlyMedia: Bool? = nil
        ) {
            self.excludeReplies = excludeReplies
            self.excludeReblogs = excludeReblogs
            self.onlyMedia = onlyMedia
        }
    }

}
