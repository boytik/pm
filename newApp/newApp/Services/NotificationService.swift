//
//  NotificationService.swift
//  Alpha Academy
//
//  Local notifications only. There is no Info.plist key for notification
//  permission — it is purely a runtime request.
//

import Foundation
import UserNotifications

enum NotificationService {

    private static let bodies: [String] = [
        "Three minutes keeps the chart fresh. Ready?",
        "A few weak letters are due for review.",
        "Can you still spell a booking code cold? Let's check.",
        "Two minutes on the air. Alpha, Bravo, Charlie…",
        "Your weakest letters are waiting."
    ]

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedules seven one-off reminders rather than one repeating trigger,
    /// so a day already practised can simply be skipped. Seven pending
    /// requests is far under the 64-request limit, and rescheduling on every
    /// launch makes the whole thing self-healing.
    static func reschedule(profile: UserProfile, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

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

            // Skip a slot that has already passed today.
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
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
