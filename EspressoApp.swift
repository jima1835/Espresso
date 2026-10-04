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
    var duration: String  { self == .zh ? "时长" : "Duration" }
    var untilOff: String  { self == .zh ? "直到手动关闭" : "Until turned off" }
    func hours(_ h: Int) -> String { self == .zh ? "\(h) 小时" : (h == 1 ? "1 hour" : "\(h) hours") }
    // 时间跟随 app 界面语言,而不是系统区域(否则英文界面里会出现「上午12:30」)
    func clock(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
            .locale(Locale(identifier: self == .zh ? "zh_CN" : "en_US")))
    }
    func timeLeft(_ left: String, until: String) -> String {
        self == .zh ? "剩余 \(left) · \(until) 自动恢复睡眠" : "\(left) left · sleep returns at \(until)"
    }
    func toggleFailed(_ detail: String) -> String {
        self == .zh
            ? "切换失败:\(detail)\n可能还没配置 sudoers 免密规则,请运行 install.sh"
            : "Toggle failed: \(detail)\nThe sudoers rule may not be installed — run install.sh."
    }
}

// MARK: - 状态模型:读写 pmset disablesleep

final class SleepModel: ObservableObject {
    static let durations = [0, 60, 120, 240, 480, 720]   // 分钟;0 = 直到手动关闭

    @Published var sleepDisabled = false   // true = no-sleep(防休眠开启)
    @Published var deadline: Date?         // 定时模式的自动关闭时间
    @Published var busy = false
    @Published var lastError: String?
    @Published var uiLang: UILang {
        didSet { UserDefaults.standard.set(uiLang.rawValue, forKey: "uiLang") }
    }
    @Published var durationMinutes: Int {
        didSet { UserDefaults.standard.set(durationMinutes, forKey: "durationMinutes") }
    }

    // 定时逻辑全部在 CLI(app 内置一份)里:截止时间文件 + LaunchAgent,app 退出也照样到点关闭
    private let cli = Bundle.main.path(forResource: "espresso", ofType: nil) ?? "/usr/local/bin/espresso"
    private let deadlineFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Espresso/timer-deadline")
    private var pollTimer: Timer?

    init() {
        let saved = UserDefaults.standard.string(forKey: "uiLang")
        uiLang = saved.flatMap(UILang.init(rawValue:)) ?? .en
        let mins = UserDefaults.standard.integer(forKey: "durationMinutes")
        durationMinutes = Self.durations.contains(mins) ? mins : 0
        // CLI / 定时到点等外部变化:低频轮询,保证菜单栏图标不过期
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (code, out) = Self.run(["/usr/bin/pmset", "-g"])
            guard code == 0 else { return }
            let disabled = out.range(of: #"SleepDisabled\s+1"#,
                                     options: .regularExpression) != nil
            let deadline = (try? String(contentsOf: self.deadlineFile, encoding: .utf8))
                .flatMap { TimeInterval($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .map(Date.init(timeIntervalSince1970:))
            DispatchQueue.main.async {
                self.sleepDisabled = disabled
                self.deadline = disabled ? deadline : nil
            }
        }
    }

    func toggle() {
        apply(on: !sleepDisabled)
    }

    // 防休眠开着时改时长,立即按新时长生效(定时 <-> 一直开)
    func selectDuration(_ mins: Int) {
        guard mins != durationMinutes else { return }
        durationMinutes = mins
        if sleepDisabled { apply(on: true) }
    }

    private func apply(on: Bool) {
        guard !busy else { return }
        let args = !on ? ["off"] : durationMinutes > 0 ? ["for", "\(durationMinutes)m"] : ["on"]
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            // CLI 内部用 sudo -n:缺免密规则时立刻失败而不是挂起等密码
            let (code, out) = Self.run([self.cli] + args)
            DispatchQueue.main.async {
                self.busy = false
                self.lastError = code == 0 ? nil : self.uiLang.toggleFailed(out)
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

            if model.sleepDisabled, let deadline = model.deadline {
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    Label(model.uiLang.timeLeft(Self.formatLeft(deadline.timeIntervalSince(ctx.date)),
                                                until: model.uiLang.clock(deadline)),
                          systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Picker(model.uiLang.duration, selection: Binding(
                get: { model.durationMinutes }, set: { model.selectDuration($0) })) {
                ForEach(SleepModel.durations, id: \.self) { mins in
                    Text(mins == 0 ? model.uiLang.untilOff : model.uiLang.hours(mins / 60)).tag(mins)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
            .disabled(model.busy)

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

    // 剩余时间 -> "1h 23m" / "4m" / "<1m"
    static func formatLeft(_ seconds: TimeInterval) -> String {
        let mins = Int((seconds / 60).rounded(.up))
        guard mins > 0 else { return "<1m" }
        if mins < 60 { return "\(mins)m" }
        return mins % 60 == 0 ? "\(mins / 60)h" : "\(mins / 60)h \(mins % 60)m"
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
