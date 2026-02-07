import Foundation
import Network

extension Notification.Name {
    static let connectivityDidChange = Notification.Name("connectivityDidChange")
}

final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.easystreet.connectivity", qos: .utility)

    private(set) var isConnected: Bool = true
    private(set) var isExpensive: Bool = false

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let wasConnected = self.isConnected
            self.isConnected = path.status == .satisfied
            self.isExpensive = path.isExpensive
            if wasConnected != self.isConnected {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .connectivityDidChange, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
