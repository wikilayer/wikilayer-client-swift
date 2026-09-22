import Foundation

/// A page of a wiki, as the tree of pages is built from it.
///
/// `parentID` is the node the page hangs from, which is the wiki itself for a page at
/// the top. `sortKey` is the server's order among siblings, carried on every
/// ``SyncNode``; the tree reads it rather than trusting the order pages are handed in,
/// so two apps storing the same wiki draw the same tree.
public struct PageInTree: Equatable, Sendable {
    public let id: Int64
    public let parentID: Int64
    public let title: String
    public let sortKey: String
    public let isHome: Bool

    public init(id: Int64, parentID: Int64, title: String, sortKey: String, isHome: Bool = false) {
        self.id = id
        self.parentID = parentID
        self.title = title
        self.sortKey = sortKey
        self.isHome = isHome
    }
}

/// A page with the pages kept under it.
public struct PageBranch: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let title: String
    public let children: [PageBranch]

    public init(id: Int64, title: String, children: [PageBranch]) {
        self.id = id
        self.title = title
        self.children = children
    }
}

/// A page named as somewhere to go, without the pages kept under it.
public struct PageStep: Equatable, Sendable {
    public let id: Int64
    public let title: String

    public init(id: Int64, title: String) {
        self.id = id
        self.title = title
    }
}

/// The page before and the page after, in the order the wiki is read.
public struct PageNeighbours: Equatable, Sendable {
    public let previous: PageStep
    public let next: PageStep

    public init(previous: PageStep, next: PageStep) {
        self.previous = previous
        self.next = next
    }
}

/// A line of the tree as it is drawn: how deep it sits and whether it hides pages.
public struct PageOutlineRow: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let title: String
    public let depth: Int
    public let hasChildren: Bool

    public init(id: Int64, title: String, depth: Int, hasChildren: Bool) {
        self.id = id
        self.title = title
        self.depth = depth
        self.hasChildren = hasChildren
    }
}

extension [PageInTree] {
    /// Nests the pages of one wiki, in one language, into the tree their author made.
    ///
    /// Siblings come out in the server's order, by `sortKey` and then by id. The home
    /// page leads, whatever it sorts as, because that is where a wiki is read from;
    /// hand it in with the rest rather than filtering it out.
    ///
    /// Nothing handed in is dropped. A page whose parent is not among them is a root of
    /// its own, and so is one whose parents form a cycle: a tree missing a page is
    /// worse than a tree with a page at the wrong depth, because nothing on screen says
    /// it is missing. A repeated id is kept once, since a node that changes mid-sync
    /// arrives in two batches and a caller stitching them together has it twice.
    public var pageTree: [PageBranch] {
        var seen = Set<Int64>()
        let pages = filter { seen.insert($0.id).inserted }
            .sorted { left, right in
                if left.isHome != right.isHome { return left.isHome }
                return left.sortKey == right.sortKey
                    ? left.id < right.id : left.sortKey < right.sortKey
            }

        var childrenOf: [Int64: [PageInTree]] = [:]
        for page in pages where page.parentID != page.id {
            childrenOf[page.parentID, default: []].append(page)
        }

        var placed = Set<Int64>()
        func branch(_ page: PageInTree) -> PageBranch {
            placed.insert(page.id)
            return PageBranch(
                id: page.id,
                title: page.title,
                children: (childrenOf[page.id] ?? []).filter { !placed.contains($0.id) }
                    .map(branch)
            )
        }

        let held = Set(pages.map(\.id))
        var tree = pages.filter { !held.contains($0.parentID) }.map(branch)
        for page in pages where !placed.contains(page.id) {
            tree.append(branch(page))
        }
        return tree
    }
}

extension [PageBranch] {
    /// Reads the tree as one list, each row carrying how deep it sits.
    ///
    /// Only the branches named in `expanded` show what is under them, and a row says
    /// whether it hides pages, so a closed branch can be told from a page with nothing
    /// under it. Which branches stand open is the caller's to keep: the tree does not
    /// remember it between drawings.
    public func outline(expanded: Set<Int64>) -> [PageOutlineRow] {
        rows(expanded: expanded, depth: 0)
    }

    /// The page before and after the given one, walking the tree as a reader does.
    ///
    /// The walk closes into a ring, so the last page leads back to the first rather than
    /// to a dead end. Fewer than three pages answer `nil`: with two, both ways lead to
    /// the same page, which reads as a control that does not work. A page the tree does
    /// not hold answers `nil` as well, and both answers mean the same thing to a caller
    /// — there is nowhere to step from here.
    public func neighbours(of page: Int64) -> PageNeighbours? {
        let reading = inReadingOrder
        guard reading.count >= fewestPagesThatMakeAWalk,
            let here = reading.firstIndex(where: { $0.id == page })
        else {
            return nil
        }
        return PageNeighbours(
            previous: reading[(here + reading.count - 1) % reading.count],
            next: reading[(here + 1) % reading.count]
        )
    }

    /// The pages above the given one, outermost first, which have to stand open for it
    /// to show. A page at the top, and a page the tree does not hold, have none.
    public func ancestors(of page: Int64) -> [Int64] {
        for branch in self {
            if branch.id == page { return [] }
            let deeper = branch.children.ancestors(of: page)
            if !deeper.isEmpty || branch.children.contains(where: { $0.id == page }) {
                return [branch.id] + deeper
            }
        }
        return []
    }

    private func rows(expanded: Set<Int64>, depth: Int) -> [PageOutlineRow] {
        flatMap { branch -> [PageOutlineRow] in
            let row = PageOutlineRow(
                id: branch.id,
                title: branch.title,
                depth: depth,
                hasChildren: !branch.children.isEmpty
            )
            guard expanded.contains(branch.id) else { return [row] }
            return [row] + branch.children.rows(expanded: expanded, depth: depth + 1)
        }
    }

    private var inReadingOrder: [PageStep] {
        flatMap { [PageStep(id: $0.id, title: $0.title)] + $0.children.inReadingOrder }
    }
}

private let fewestPagesThatMakeAWalk = 3
