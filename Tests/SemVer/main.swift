// SemVer 单测：scripts/ci-test.sh 用 swiftc 把它和 Sources/Drip/SemVer.swift 编在一起运行（Linux 上也能跑）
import Foundation

var failures = 0

func expect(_ ok: Bool, _ what: String) {
    if !ok { failures += 1; print("✗ \(what)") }
}

// 解析
expect(SemVer("1.2.3")?.description == "1.2.3", "解析 1.2.3")
expect(SemVer("v1.2.3")?.description == "1.2.3", "解析带 v 前缀")
expect(SemVer("1.1.0-3-gabc1234")?.description == "1.1.0", "忽略 git describe 后缀")
expect(SemVer("2.0.0+build.5")?.description == "2.0.0", "忽略构建信息")
for bad in ["", "1.2", "1.2.3.4", "a.b.c", "1..3", "-1.0.0", "v", "1.2.x"] {
    expect(SemVer(bad) == nil, "不合法的 \"\(bad)\" 应返回 nil")
}

// 比较：按数字，不按字符串
expect(SemVer("1.10.0")! > SemVer("1.9.9")!, "1.10.0 > 1.9.9")
expect(SemVer("2.0.0")! > SemVer("1.99.99")!, "2.0.0 > 1.99.99")
expect(SemVer("1.2.4")! > SemVer("1.2.3")!, "1.2.4 > 1.2.3")
expect(!(SemVer("1.2.3")! > SemVer("v1.2.3")!), "同版本不算更新")
expect(!(SemVer("1.2.3")! > SemVer("1.3.0")!), "旧版本不算更新")

if failures > 0 {
    print("SemVer：\(failures) 项失败")
    exit(1)
}
print("✓ SemVer：全部通过")
