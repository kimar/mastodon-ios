//
//  StatusFetchedResultsController.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-30.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonUI

final class StatusFetchedResultsController: NSObject {

    var disposeBag = Set<AnyCancellable>()

    let fetchedResultsController: NSFetchedResultsController<Status>

    // input
    let domain = CurrentValueSubject<String?, Never>(nil)
    let statusIDs = CurrentValueSubject<[Mastodon.Entity.Status.ID], Never>([])
    
    // output
    let _objectIDs = CurrentValueSubject<[NSManagedObjectID], Never>([])
    @Published var records: [ManagedObjectRecord<Status>] = []
    
    init(managedObjectContext: NSManagedObjectContext, domain: String?, additionalTweetPredicate: NSPredicate?) {
        self.domain.value = domain ?? ""
        self.fetchedResultsController = {
            let fetchRequest = Status.sortedFetchRequest
            fetchRequest.predicate = Status.predicate(domain: domain ?? "", ids: [])
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.fetchBatchSize = 20
            let controller = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            return controller
        }()
        super.init()
        
        // debounce output to prevent UI update issues
        _objectIDs
            .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
            .map { objectIDs in objectIDs.map { ManagedObjectRecord(objectID: $0) } }
            .assign(to: &$records)
        
        fetchedResultsController.delegate = self
        
        Publishers.CombineLatest(
            self.domain.removeDuplicates(),
            self.statusIDs.removeDuplicates()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] domain, ids in
            guard let self = self else { return }
            var predicates = [Status.predicate(domain: domain ?? "", ids: ids)]
            if let additionalPredicate = additionalTweetPredicate {
                predicates.append(additionalPredicate)
            }
            self.fetchedResultsController.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            do {
                try self.fetchedResultsController.performFetch()
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }
        .store(in: &disposeBag)
    }
    
}

extension StatusFetchedResultsController {
    
    public func append(statusIDs: [Mastodon.Entity.Status.ID]) {
        var result = self.statusIDs.value
        for statusID in statusIDs where !result.contains(statusID) {
            result.append(statusID)
        }
        self.statusIDs.value = result
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate
extension StatusFetchedResultsController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        
        let indexes = statusIDs.value
        let objects = fetchedResultsController.fetchedObjects ?? []
        
        let items: [NSManagedObjectID] = objects
            .compactMap { object in
                indexes.firstIndex(of: object.id).map { index in (index, object) }
            }
            .sorted { $0.0 < $1.0 }
            .map { $0.1.objectID }
        self._objectIDs.value = items
    }
}
