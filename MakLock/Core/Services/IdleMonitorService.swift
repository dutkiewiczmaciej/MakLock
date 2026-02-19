import Foundation
import IOKit

/// Monitors system idle time and triggers auto-lock when the threshold is exceeded.
final class IdleMonitorService {
    static let shared = IdleMonitorService()

    /// Callback when idle timeout is reached.
    var onIdleTimeoutReached: (() -> Void)?

    private var timer: Timer?
    private let checkInterval: TimeInterval = 10

    private init() {}

    /// Start monitoring idle time with the given timeout in minutes.
    func startMonitoring() {
        stopMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }

        NSLog("[MakLock] Idle monitor started")
    }

    /// Stop monitoring.
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Whether monitoring is active.
    var isMonitoring: Bool {
        timer != nil
    }

    // MARK: - Private

    private func checkIdleTime() {
        let settings = Defaults.shared.appSettings
        guard settings.lockOnIdle else { return }

        let timeoutSeconds = TimeInterval(settings.idleTimeoutMinutes) * 60
        let idleSeconds = systemIdleTime()

        if idleSeconds >= timeoutSeconds {
            NSLog("[MakLock] Idle timeout reached (%.0fs idle, %.0fs threshold)", idleSeconds, timeoutSeconds)
            onIdleTimeoutReached?()
        }
    }

    /// Get system idle time in seconds using IOKit HIDIdleTime.
    private func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )

        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? Int64 else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return TimeInterval(idleTime) / 1_000_000_000
    }
}
