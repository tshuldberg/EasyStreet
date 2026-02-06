import Foundation

struct DisclaimerManager {
    private static let hasSeenDisclaimerKey = "hasSeenDisclaimer_v1"

    static var hasSeenDisclaimer: Bool {
        UserDefaults.standard.bool(forKey: hasSeenDisclaimerKey)
    }

    static func markDisclaimerSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenDisclaimerKey)
    }

    static let disclaimerTitle = "Important Notice"

    static let disclaimerBody = """
    EasyStreet provides street sweeping schedule information based on data \
    from the City of San Francisco's open data portal. This information is \
    provided for convenience only and may not reflect the most current schedules.

    Always check posted street signs for the official sweeping schedule at \
    your parking location. EasyStreet is not responsible for parking tickets \
    or towing resulting from reliance on information displayed in this app.
    """

    static let attributionText = "Data: City of San Francisco (data.sfgov.org)"
}
