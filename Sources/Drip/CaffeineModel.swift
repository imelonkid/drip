import Foundation
import IOKit.pwr_mgt
import ServiceManagement

/// 持有一个 IOPMAssertion 来阻止系统空闲休眠。
/// 不轮询、不常驻定时器：只有定时模式下挂一个一次性 Timer 在到期时释放。
@MainActor
final class CaffeineModel: ObservableObject {
    /// 可选时长（分钟），0 表示无限期
    static let minuteOptions = [15, 30, 45]
    static let hourOptions = [60, 240, 480, 720]

    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?

    @Published private(set) var selectedMinutes: Int {
        didSet { defaults.set(selectedMinutes, forKey: Keys.duration) }
    }

    /// 开：屏幕也保持常亮；关：只阻止系统休眠，屏幕可按设置熄灭
    @Published var keepDisplayOn: Bool {
        didSet {
            defaults.set(keepDisplayOn, forKey: Keys.display)
            if isActive { acquireAssertion() }
        }
    }

    @Published var activateOnLaunch: Bool {
        didSet { defaults.set(activateOnLaunch, forKey: Keys.onLaunch) }
    }

    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let defaults = UserDefaults.standard
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    private enum Keys {
        static let duration = "duration"
        static let display = "keepDisplayOn"
        static let onLaunch = "activateOnLaunch"
    }

    init() {
        defaults.register(defaults: [Keys.duration: 0, Keys.display: true, Keys.onLaunch: false])
        selectedMinutes = defaults.integer(forKey: Keys.duration)
        keepDisplayOn = defaults.bool(forKey: Keys.display)
        activateOnLaunch = defaults.bool(forKey: Keys.onLaunch)
        if activateOnLaunch { start(minutes: selectedMinutes) }
    }

    func setActive(_ on: Bool) {
        on ? start(minutes: selectedMinutes) : stop()
    }

    /// 点选时长即刻按该时长开始（已开启时则重新计时）
    func select(minutes: Int) {
        selectedMinutes = minutes
        start(minutes: minutes)
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Drip: launch at login failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        releaseAssertion()
        isActive = false
    }

    private func start(minutes: Int) {
        timer?.invalidate()
        timer = nil
        guard acquireAssertion() else { return }
        isActive = true

        guard minutes > 0 else {
            endDate = nil
            return
        }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = end
        let t = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @discardableResult
    private func acquireAssertion() -> Bool {
        releaseAssertion()
        let type = keepDisplayOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Drip keeps your Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            NSLog("Drip: IOPMAssertionCreateWithName failed: \(result)")
            return false
        }
        assertionID = id
        return true
    }

    private func releaseAssertion() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
