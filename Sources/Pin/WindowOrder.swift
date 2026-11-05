import CoreGraphics

enum WindowOrder {
    // NSTableView drop rows are insertion points in the original list.
    static func moving(_ ids: [CGWindowID], id: CGWindowID, to row: Int) -> [CGWindowID] {
        guard let old = ids.firstIndex(of: id), (0...ids.count).contains(row) else { return ids }
        var result = ids
        result.remove(at: old)
        result.insert(id, at: row > old ? row - 1 : row)
        return result
    }
}
