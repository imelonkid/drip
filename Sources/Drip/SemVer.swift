/// 语义化版本 X.Y.Z：比较 latest.json 的 version 和本机构建时注入的版本号。
/// 只用标准库，CI 在 Linux 上单独编译测试（scripts/ci-test.sh）。
struct SemVer: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// 接受 "1.2.3"、"v1.2.3"；忽略 "-" 或 "+" 之后的预发布 / 构建信息；不合法返回 nil
    init?(_ string: String) {
        var core = Substring(string)
        if core.hasPrefix("v") { core = core.dropFirst() }
        if let cut = core.firstIndex(where: { $0 == "-" || $0 == "+" }) { core = core[..<cut] }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]),
              major >= 0, minor >= 0, patch >= 0
        else { return nil }
        (self.major, self.minor, self.patch) = (major, minor, patch)
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}
