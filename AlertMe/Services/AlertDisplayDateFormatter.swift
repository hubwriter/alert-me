import Foundation

enum AlertDisplayDateFormatter {
    static func dateString(
        from date: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date)
    }
}
