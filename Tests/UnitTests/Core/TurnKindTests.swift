import Testing
@testable import PlayCarTV

@Suite("Turn kind")
struct TurnKindTests {
    @Test(
        "The change of heading at a junction names the turn",
        arguments: [
            (0.0, 90.0, TurnKind.right),
            (0, 270, .left),
            (0, 30, .slightRight),
            (0, 330, .slightLeft),
            (0, 150, .sharpRight),
            (0, 210, .sharpLeft),
            (0, 180, .uTurn),
            (90, 270, .uTurn),
            (45, 50, .straight)
        ]
    )
    func turn(bearingIn: Double, bearingOut: Double, expected: TurnKind) {
        #expect(TurnKind(from: bearingIn, to: bearingOut) == expected)
    }

    @Test("Crossing north is a small change, not a full circle")
    func wrapsAroundNorth() {
        #expect(TurnKind(from: 350, to: 10) == .straight)
        #expect(TurnKind(from: 10, to: 350) == .straight)
        #expect(TurnKind(from: 300, to: 30) == .right)
    }

    @Test("Each turn has its own symbol, the arrival a chequered flag")
    func symbols() {
        let all: [TurnKind] = [
            .straight, .slightLeft, .left, .sharpLeft, .slightRight, .right, .sharpRight, .uTurn, .start
        ]
        #expect(Set(all.map(\.symbolName)).count == all.count)
        #expect(TurnKind.arrive.symbolName == "flag.checkered")
    }
}
