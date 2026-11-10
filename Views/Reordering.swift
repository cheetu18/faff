//
//  Reordering.swift
//  faff
//
//  Shared plumbing for drag-to-reorder (SDK 27 `reorderable()` /
//  `reorderContainer(for:)`), which hands back a description of the move and
//  leaves applying it to the model up to us.
//

import SwiftUI

extension ReorderDifference where CollectionID == ReorderableSingleCollectionIdentifier {
    /// Rewrite `collection` in place to reflect this drag.
    ///
    /// Note this is applied to the *full* collection, not just the items that
    /// happened to be visible. Dragging inside a filtered view still resolves
    /// to a well-defined global position, because the anchor in
    /// `.before(_:)` is a real element of the full collection.
    func apply<C>(to collection: inout C)
        where C: RangeReplaceableCollection,
              C.Element: Identifiable,
              C.Element.ID == ItemID
    {
        let moving = Set(sources)
        guard !moving.isEmpty else { return }

        // One in-place pass: drop the moved items and capture them in order.
        var moved: [C.Element] = []
        moved.reserveCapacity(moving.count)
        collection.removeAll { element in
            guard moving.contains(element.id) else { return false }
            moved.append(element)
            return true
        }

        switch destination.position {
        case .before(let id):
            let index = collection.firstIndex { $0.id == id } ?? collection.endIndex
            collection.insert(contentsOf: moved, at: index)
        case .end:
            collection.append(contentsOf: moved)
        }
    }
}
