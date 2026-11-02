import AppKit

/// 客户端更新（项目基线「桌面应用」）：启动 10 秒后、之后每 6 小时读一次版本清单 latest.json，
/// 版本比自己新才提示；点「下载」用浏览器打开安装包，不在 App 里下载安装。可以跳过某个版本；读失败静默，下次再试。
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// 版本清单（公开地址，发布流水线每次发版最后上传）
    private static let manifestURL = URL(string: "https://melon-download.oss-cn-beijing.aliyuncs.com/drip/desktop/latest.json")!
    private static let skippedKey = "skippedVersion"

    private struct Manifest: Decodable {
        let version: String
        let notes: String
        let files: [String: String]
    }

    private var timer: Timer?
    private var prompting = false

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in UpdateChecker.shared.check() }
        }
        t.fireDate = Date().addingTimeInterval(10)
        t.tolerance = 60
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func check() {
        let request = URLRequest(url: Self.manifestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
            else { return }
            Task { @MainActor in UpdateChecker.shared.offer(manifest) }
        }.resume()
    }

    private func offer(_ manifest: Manifest) {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard !prompting,
              let latest = SemVer(manifest.version), let mine = SemVer(current), latest > mine,
              UserDefaults.standard.string(forKey: Self.skippedKey) != latest.description,
              let download = manifest.files["arm64"].flatMap(URL.init(string:))
        else { return }

        prompting = true
        defer { prompting = false }
        let alert = NSAlert()
        alert.messageText = "Drip \(latest) 可以更新了"
        alert.informativeText = "当前版本 \(mine)\n\n\(manifest.notes)"
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "以后再说")
        alert.addButton(withTitle: "跳过这个版本")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(download)
        case .alertThirdButtonReturn: UserDefaults.standard.set(latest.description, forKey: Self.skippedKey)
        default: break
        }
    }
}
