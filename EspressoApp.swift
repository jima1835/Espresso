import SwiftUI
import AppKit

// MARK: - 界面语言(默认英文,选择持久化到 UserDefaults)

enum UILang: String, CaseIterable, Identifiable {
    case en, zh
    var id: String { rawValue }

    var statusOn: String  { self == .zh ? "防休眠已开启" : "No-Sleep ON" }
    var statusOff: String { self == .zh ? "正常睡眠模式" : "Normal Sleep" }
    var descOn: String    { self == .zh ? "Mac 将保持唤醒,合盖也不睡"
                                        : "Mac stays awake — even with the lid closed" }
    var descOff: String   { self == .zh ? "Mac 会按系统设置正常休眠"
                                        : "Mac sleeps according to system settings" }
    var quit: String      { self == .zh ? "退出" : "Quit" }
    func toggleFailed(_ detail: String) -> String {
        self == .zh
            ? "切换失败:\(detail)\n可能还没配置 sudoers 免密规则,请运行 install.sh"
            : "Toggle failed: \(detail)\nThe sudoers rule may not be installed — run install.sh."
    }
}

// MARK: - 状态模型:读写 pmset disablesleep

final class SleepModel: ObservableObject {
    @Published var sleepDisabled = false   // true = no-sleep(防休眠开启)
    @Published var busy = false
    @Published var lastError: String?
    @Published var uiLang: UILang {
        didSet { UserDefaults.standard.set(uiLang.rawValue, forKey: "uiLang") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "uiLang")
        uiLang = saved.flatMap(UILang.init(rawValue:)) ?? .en
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (code, out) = Self.run(["/usr/bin/pmset", "-g"])
            guard code == 0 else { return }
            let disabled = out.range(of: #"SleepDisabled\s+1"#,
                                     options: .regularExpression) != nil
            DispatchQueue.main.async { self.sleepDisabled = disabled }
        }
    }

    func toggle() {
        guard !busy else { return }
        let target = sleepDisabled ? "0" : "1"
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            // -n:非交互,缺免密规则时立刻失败而不是挂起等密码
            let (code, out) = Self.run(["/usr/bin/sudo", "-n",
                                        "/usr/bin/pmset", "-a", "disablesleep", target])
            DispatchQueue.main.async {
                self.busy = false
                if code == 0 {
                    self.lastError = nil
                    self.sleepDisabled = (target == "1")
                } else {
                    self.lastError = self.uiLang.toggleFailed(out)
                }
                self.refresh()
            }
        }
    }

    @discardableResult
    static func run(_ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}

// MARK: - 主界面:Warp(1.1.1.1) 风格大圆钮

struct ContentView: View {
    @ObservedObject var model: SleepModel

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: model.sleepDisabled
                ? [Color.orange, Color.red]
                : [Color(white: 0.62), Color(white: 0.42)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Espresso")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Picker(selection: $model.uiLang, label: EmptyView()) {
                    Text("EN").tag(UILang.en)
                    Text("中文").tag(UILang.zh)
                }
                .pickerStyle(.segmented)
                .frame(width: 96)
                .labelsHidden()
            }

            Button(action: model.toggle) {
                ZStack {
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: 112, height: 112)
                        .shadow(color: model.sleepDisabled ? .orange.opacity(0.55) : .clear,
                                radius: 20)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(model.busy)
            .opacity(model.busy ? 0.6 : 1)

            Text(model.sleepDisabled ? model.uiLang.statusOn : model.uiLang.statusOff)
                .font(.title3).bold()
            Text(model.sleepDisabled ? model.uiLang.descOn : model.uiLang.descOff)
                .font(.caption)
                .foregroundColor(.secondary)

            if let err = model.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                Text("SleepDisabled = \(model.sleepDisabled ? 1 : 0)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(model.uiLang.quit) { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 14, trailing: 20))
        .frame(width: 260)
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }
}

// MARK: - App 入口:菜单栏常驻

@main
struct EspressoApp: App {
    @StateObject private var model = SleepModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            Image(systemName: model.sleepDisabled ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}
