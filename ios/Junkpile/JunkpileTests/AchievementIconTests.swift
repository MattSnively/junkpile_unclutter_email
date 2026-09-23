import XCTest
import UIKit
@testable import Junkpile

final class AchievementIconTests: XCTestCase {

    // Image(systemName:) renders nothing for an unknown symbol instead of
    // failing, which is how "First Step" shipped as a blank badge.
    func testEveryAchievementIconIsARealSymbol() {
        for achievement in Achievement.allCases {
            XCTAssertNotNil(
                UIImage(systemName: achievement.iconName),
                "\(achievement) uses missing SF Symbol '\(achievement.iconName)'"
            )
        }
    }
}
