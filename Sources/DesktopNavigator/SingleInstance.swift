import AppKit
import Darwin

/// Guarantees one running copy of the app. Policy: newest wins. The copy that
/// just launched asks every older copy to quit, so `launchctl kickstart -k`,
/// `install.sh`, and double-clicking a fresh build all end with exactly one
/// instance — the one that just started.
enum SingleInstance {
    struct Instance: Equatable {
        let pid: pid_t
        let launchDate: Date?
    }

    /// Which of `others` should `me` terminate: every instance that launched
    /// earlier. Ties (same launch date, or no date) go to the higher PID, so
    /// two copies starting at the same instant leave exactly one, never zero.
    static func instancesToTerminate(me: Instance, others: [Instance]) -> [Instance] {
        others.filter { isOlder($0, than: me) }
    }

    private static func isOlder(_ a: Instance, than b: Instance) -> Bool {
        let aDate = a.launchDate ?? .distantPast
        let bDate = b.launchDate ?? .distantPast
        if aDate != bDate { return aDate < bDate }
        return a.pid < b.pid
    }

    /// Process start time from the kernel. NSRunningApplication.launchDate is
    /// nil for processes LaunchServices did not launch — which includes every
    /// copy launchd starts — so it cannot be used to order instances.
    static func startDate(pid: pid_t) -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0,
              size > 0, info.kp_proc.p_pid == pid else { return nil }
        let tv = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
    }

    static let forceTerminateGrace: TimeInterval = 2

    /// Call once at launch, before the run loop starts. No-op when running as a
    /// bare binary (`swift run`) because there is no bundle identifier to match.
    static func terminateOlderInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let myPID = getpid()
        let me = Instance(pid: myPID, launchDate: startDate(pid: myPID))

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
        let byPID = Dictionary(others.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        let victims = instancesToTerminate(
            me: me,
            others: others.map { Instance(pid: $0.processIdentifier, launchDate: startDate(pid: $0.processIdentifier)) }
        )

        for victim in victims {
            guard let app = byPID[victim.pid] else { continue }
            // Graceful first: a clean exit (status 0) keeps launchd from
            // respawning it, since KeepAlive only restarts on failure.
            app.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + forceTerminateGrace) {
                if !app.isTerminated { app.forceTerminate() }
            }
        }
    }
}
