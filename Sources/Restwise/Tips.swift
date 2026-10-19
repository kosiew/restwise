import RestwiseCore

enum Tips {
    private static let micro = [
        "Look at something about 20 feet (6 m) away.",
        "Blink slowly ten times.",
        "Look out a window and let your eyes relax.",
        "Close your eyes and take three slow breaths.",
        "Roll your shoulders back a few times.",
        "Unclench your jaw and drop your shoulders.",
        "Trace a slow figure-eight with your eyes.",
    ]

    private static let long = [
        "Stand up and walk around for a few minutes.",
        "Refill your water and stretch your legs.",
        "Stretch your arms overhead and lean side to side.",
        "Step outside or go to a window for some daylight.",
        "Do a few slow neck rolls and wrist circles.",
        "Walk to another room and back. Leave your phone behind.",
    ]

    static func random(for kind: BreakKind) -> String {
        (kind == .micro ? micro : long).randomElement()!
    }
}
