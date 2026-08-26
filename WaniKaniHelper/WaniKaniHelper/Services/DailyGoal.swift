// Tracks the user's daily review completion count using UserDefaults.
// Resets automatically at midnight each day. Used by HomeView to display
// the daily goal progress ring showing how many reviews have been completed today.
import Foundation

enum DailyGoal {
    private static let keyDate      = "dailyGoalDate"
    private static let keyCompleted = "dailyGoalCompleted"

    private static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func resetIfNewDay() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: keyDate) != todayString {
            defaults.set(todayString, forKey: keyDate)
            defaults.set(0, forKey: keyCompleted)
        }
    }

    static func increment(by count: Int) {
        resetIfNewDay()
        let prev = UserDefaults.standard.integer(forKey: keyCompleted)
        UserDefaults.standard.set(prev + count, forKey: keyCompleted)
    }

    static var completed: Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: keyCompleted)
    }
}
