import NonogramKit
import SwiftUI

/// Derslerin başlığı ve Muffin'in anlattığı kural (MuffinLessonBanner gösterir).
extension TutorialLesson {
    var title: LocalizedStringResource {
        switch self {
        case .firstSquare: "Your first square"
        case .tapToFill: "Zeros and crosses"
        case .fullLines: "Full lines"
        case .emptyLines: "Blocks side by side"
        case .markWithCross: "Your turn"
        case .multipleBlocks: "Several blocks"
        case .overlap: "Find the overlap"
        case .edges: "Use the edges"
        case .crossReference: "Rows meet columns"
        case .mistakesAndLives: "Mind your paws"
        case .difficulty: "Choose your difficulty"
        case .graduation: "Graduation"
        }
    }

    /// Muffin'in tek cümlelik anlatımı (uzun yazı okunmuyor; gerisini pati ve parlayan satır gösterir).
    var message: LocalizedStringResource {
        switch self {
        case .firstSquare:
            "Hi, I'm Muffin! Tap the square I'm pointing at."
        case .tapToFill:
            "0 means empty. Swipe X across the glowing line."
        case .fullLines:
            "If a clue is as long as the row, the whole row is filled. Starting there makes it easier."
        case .emptyLines:
            "0 means empty: swipe X across it."
        case .markWithCross:
            "One row is empty and one is completely full. Find those first and you won't get confused. Your turn!"
        case .multipleBlocks:
            "1 1 1 = three single squares with gaps. Solve the glowing line!"
        case .overlap:
            "A long block covers the middle of the line wherever it starts. Fill the squares every position shares."
        case .edges:
            "A filled square touching the edge tells you exactly where a block begins."
        case .crossReference:
            "Rows and columns help each other. Solve the glowing line!"
        case .mistakesAndLives:
            "From now on each wrong move costs a paw. Lose all three and the puzzle starts over."
        case .difficulty:
            "Each mistake costs a paw. The button by the timer switches Easy and Hard."
        case .graduation:
            "You know all the rules. Solve this one on your own!"
        }
    }
}
