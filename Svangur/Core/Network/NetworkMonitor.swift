import Combine
import Foundation
import Network

protocol NetworkMonitorProtocol: Sendable {
    var isConnected: Bool { get }
    var connectionUpdates: AsyncStream<Bool> { get }
}

final class NetworkMonitor: NetworkMonitorProtocol, ObservableObject, @unchecked Sendable {
    // @unchecked Sendable: NWPathMonitor is thread-safe internally;
    // isConnected is mutated only from the monitor's serial queue → MainActor.
    @Published private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.svangur.networkmonitor")

    var connectionUpdates: AsyncStream<Bool> {
        AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                let connected = path.status == .satisfied
                continuation.yield(connected)
            }
            continuation.onTermination = { [weak self] _ in
                self?.monitor.cancel()
            }
        }
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
