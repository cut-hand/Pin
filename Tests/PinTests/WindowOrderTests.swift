import Testing
@testable import Pin


@Test func draggingWindowsPreservesRelativeOrder() {
    #expect(WindowOrder.moving([1, 2, 3], id: 3, to: 0) == [3, 1, 2])
    #expect(WindowOrder.moving([1, 2, 3], id: 1, to: 3) == [2, 3, 1])
    #expect(WindowOrder.moving([1, 2, 3], id: 2, to: 2) == [1, 2, 3])
    #expect(WindowOrder.moving([1, 2, 3], id: 2, to: 1) == [1, 2, 3])
    #expect(WindowOrder.moving([1, 2, 3], id: 9, to: 0) == [1, 2, 3])
    #expect(WindowOrder.moving([1, 2, 3], id: 1, to: 4) == [1, 2, 3])
    #expect(WindowOrder.moving([], id: 1, to: 0).isEmpty)
}
