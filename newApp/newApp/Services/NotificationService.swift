import Foundation
import UserNotifications
import UIKit

enum NotificationService {
    private static let bodies: [String] = [
        "Three minutes keeps the chart fresh. Ready?",
        "A few weak letters are due for review.",
        "Can you still spell a booking code cold? Let's check.",
        "Two minutes on the air. Alpha, Bravo, Charlie…",
        "Your weakest letters are waiting."
    ]

    private static var drillIdentifiers: [String] { (0..<7).map { "drill.\($0)" } }

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }

        UIApplication.shared.registerForRemoteNotifications()
        Task { await DeviceRegistrar.flushPendingToken() }
        return true
    }

    static func reschedule(profile: UserProfile, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: drillIdentifiers)

        guard profile.remindersEnabled else { return }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: profile.reminderTime)
        let today = calendar.startOfDay(for: now)
        let practisedToday = profile.lastPracticeDay.map { calendar.isDate($0, inSameDayAs: now) }
            ?? false

        for offset in 0..<7 {
            if offset == 0, practisedToday { continue }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = time.hour
            components.minute = time.minute

            if offset == 0, let fire = calendar.date(from: components), fire <= now { continue }

            let content = UNMutableNotificationContent()
            content.title = "Daily Drill"
            content.body = profile.streakDays > 0 && offset == 0
                ? "Your streak is at \(profile.streakDays) days. Keep it going."
                : bodies[offset % bodies.count]
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "drill.\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: drillIdentifiers)
    }
}
