//
//  DataSourceFacade+Thread.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-17.
//

import Foundation
import CoreData
import CoreDataStack

extension DataSourceFacade {
    static func coordinateToStatusThreadScene(
        provider: DataSourceProvider,
        target: StatusTarget,
        status: ManagedObjectRecord<Status>
    ) async {
        let _root: StatusItem.Thread? = await {
            let _redirectRecord = await DataSourceFacade.status(
                managedObjectContext: provider.context.managedObjectContext,
                status: status,
                target: target
            )
            guard let redirectRecord = _redirectRecord else { return nil }

            let threadContext = StatusItem.Thread.Context(status: redirectRecord)
            return StatusItem.Thread.root(context: threadContext)
        }()
        guard let root = _root else {
            assertionFailure()
            return
        }
        
        await coordinateToStatusThreadScene(
            provider: provider,
            root: root
        )
    }
    
    @MainActor
    static func coordinateToStatusThreadScene(
        provider: DataSourceProvider,
        root: StatusItem.Thread
    ) async {
        let threadViewModel = ThreadViewModel(
            context: provider.context,
            optionalRoot: root
        )
        provider.coordinator.present(
            scene: .thread(viewModel: threadViewModel),
            from: provider,
            transition: .show
        )
    }
}
