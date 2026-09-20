import AppKit
import SproutCore
import UniformTypeIdentifiers

actor TraeSessionReader {
    func activity() -> TraeActivity { TraeHookStorage.activity() }
}

extension HealthStore {
    var traeStatusText: String {
        guard traeAnimationEnabled else { return "已关闭" }
        switch traeActivity {
        case .unavailable: return "未收到近期事件"
        case .idle: return "已连接 · 待机"
        case .working: return "已连接 · 工作中"
        case .waiting: return "已连接 · 等待确认"
        }
    }

    func connectTrae() {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/SproutHook")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            flash("请使用完整安装包，并将芽伴放入应用程序文件夹。")
            return
        }
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") ||
                Bundle.main.bundleURL.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/") else {
            flash("请先把芽伴放入应用程序文件夹，再点击连接。")
            return
        }
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".trae-cn/hooks.json")
        do {
            let backup = try TraeConnection.connect(file: file, helperPath: helper.path)
            traeAnimationEnabled = true
            let alert = NSAlert()
            alert.messageText = "Trae 连接配置已就绪"
            alert.informativeText = "请在 Trae 中文版设置 → Hooks 中确认全局 Hook 已启用，再提交一个新任务。收到事件后，芽伴会自动显示工作状态。" +
                (backup == nil ? "" : "\n原配置已备份至：\n" + backup!.path)
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "未能连接 Trae"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }
    }

    func exportTraeHooks() {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/SproutHook")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            flash("请使用完整的芽伴安装包后再导出配置。")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "sprout-trae-hooks.json"
        panel.title = "导出 Trae 中文版 Hook 配置"
        panel.message = "请先将芽伴放入应用程序文件夹；将导出内容合并到 Trae 的 Hooks 设置，保留已有配置。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try TraeHookConfiguration.data(helperPath: helper.path).write(to: url, options: .atomic)
            flash("配置已导出，请在 Trae 中文版的 Hooks 设置中合并并启用。")
        } catch { flash("配置导出失败，请检查目标位置是否可写。") }
    }
}
