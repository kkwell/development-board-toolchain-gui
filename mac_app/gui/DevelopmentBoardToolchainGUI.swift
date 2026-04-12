import AppKit
import Combine
import Foundation
import IOKit
import SceneKit
import SwiftUI
import SystemConfiguration
import UserNotifications

struct ToolkitStatus: Decodable {
    struct Service: Decodable {
        let host: String?
        let port: Int?
        let interval: Int?
        let auto_usbnet_repair: Bool?
        let api_version: Int?
    }

    struct USB: Decodable {
        let mode: String?
        let product: String?
        let pid: String?
    }

    struct USBNet: Decodable {
        let iface: String?
        let current_ip: String?
        let expected_ip: String?
        let board_ip: String?
        let configured: Bool?
    }

    struct Board: Decodable {
        let ping: Bool?
        let ssh_port_open: Bool?
        let control_service: Bool?
    }

    struct Host: Decodable {
        let docker_daemon: Bool?
        let dev_image: Bool?
        let official_image: Bool?
        let rkflashtool_built: Bool?
        let usbnet_helper_installed: Bool?
    }

    struct Device: Decodable {
        let board_id: String?
        let variant_id: String?
        let connected: Bool?
        let display_name: String?
        let manufacturer: String?
        let interface_name: String?
        let transport_name: String?
        let source_name: String?
    }

    let repo_root: String?
    let service: Service?
    let updated_at: String?
    let usb: USB?
    let usbnet: USBNet?
    let board: Board?
    let host: Host?
    let device: Device?
    let summary: String?
    let device_summary: String?
}

enum BoardCapability: String, CaseIterable {
    case usbProbe
    case usbLoader
    case usbECM
    case networkReachability
    case sshAccess
    case controlService
    case flashAll
    case flashPartition
    case boardReboot
    case sshAuthorizeKey
    case uf2MassStorage
    case uf2Deploy
    case serialConsole

    var displayName: String {
        switch self {
        case .usbProbe:
            return "USB 探测"
        case .usbLoader:
            return "Loader 模式"
        case .usbECM:
            return "USB 网口"
        case .networkReachability:
            return "网络可达性"
        case .sshAccess:
            return "SSH 连接"
        case .controlService:
            return "控制服务"
        case .flashAll:
            return "整机刷写"
        case .flashPartition:
            return "分区刷写"
        case .boardReboot:
            return "设备重启"
        case .sshAuthorizeKey:
            return "SSH 授权"
        case .uf2MassStorage:
            return "UF2 存储盘"
        case .uf2Deploy:
            return "UF2 下载"
        case .serialConsole:
            return "串口控制台"
        }
    }
}

struct SupportedBoard: Identifiable {
    let id: String
    let englishName: String
    let displayName: String
    let manufacturer: String
    let modelDirectoryName: String?
    let variantDisplayNames: [String]
    let shortSummary: String
    let detailSummary: String
    let integrationStatus: String
    let integrationReady: Bool
    let thumbnailLabel: String
    let thumbnailSymbol: String
    let accentStart: Color
    let accentEnd: Color
    let capabilities: [BoardCapability]
    let searchableTerms: [String]

    static let taishanPi = SupportedBoard(
        id: "TaishanPi",
        englishName: "TaishanPi",
        displayName: "TaishanPi",
        manufacturer: "嘉立创",
        modelDirectoryName: "1M-RK3566",
        variantDisplayNames: ["泰山派（1M-RK3566）", "泰山派（1F-RK3566）", "泰山派（3M-RK3576）"],
        shortSummary: "泰山派系列插件，统一收敛 RK 平台的识别、USB 网口、SSH、控制服务与镜像刷写能力。",
        detailSummary: "TaishanPi 插件作为泰山派系列的统一入口，内部再细分不同板型。当前首个已接入的板型为泰山派（1M-RK3566），后续会继续追加 1F-RK3566 和 3M-RK3576，并复用同一组能力模块。",
        integrationStatus: "插件架构已预留，当前优先支持泰山派（1M-RK3566）的识别和控制链路。",
        integrationReady: true,
        thumbnailLabel: "TAISHAN",
        thumbnailSymbol: "cpu.fill",
        accentStart: Color(red: 0.16, green: 0.43, blue: 0.88),
        accentEnd: Color(red: 0.08, green: 0.70, blue: 0.54),
        capabilities: [.usbProbe, .usbLoader, .usbECM, .networkReachability, .sshAccess, .controlService, .flashAll, .flashPartition, .boardReboot, .sshAuthorizeKey],
        searchableTerms: ["taishan", "rk3566", "rk3576", "rockchip", "泰山派", "1m-rk3566", "1f-rk3566", "3m-rk3576", "jlc", "嘉立创"]
    )

    static let colorEasyPICO2 = SupportedBoard(
        id: "ColorEasyPICO2",
        englishName: "ColorEasyPICO2",
        displayName: "ColorEasyPICO2",
        manufacturer: "嘉立创",
        modelDirectoryName: "ColorEasyPICO2",
        variantDisplayNames: ["ColorEasyPICO2"],
        shortSummary: "面向 RP2350A 的轻量开发板，规划先接入 UF2 下载和基础串口能力。",
        detailSummary: "ColorEasyPICO2 将按独立 BoardProfile 接入，但底层继续复用 USB 探测、UF2 存储盘识别和下载能力模块。第一阶段先完成设备目录收录和占位说明，后续再补实际下载控制链路。",
        integrationStatus: "已纳入设备目录，控制链路将在后续阶段接入。",
        integrationReady: false,
        thumbnailLabel: "PICO2",
        thumbnailSymbol: "memorychip.fill",
        accentStart: Color(red: 0.98, green: 0.53, blue: 0.22),
        accentEnd: Color(red: 0.90, green: 0.24, blue: 0.33),
        capabilities: [.usbProbe, .uf2MassStorage, .uf2Deploy, .serialConsole],
        searchableTerms: ["pico", "pico2", "coloreasy", "rp2350a", "coloreasypico2", "嘉立创", "jlc"]
    )

    static let catalog: [SupportedBoard] = [
        .taishanPi,
        .colorEasyPICO2,
    ]
}

enum BoardCatalogLayout {
    static let indexWidth: CGFloat = 40
    static let nameWidth: CGFloat = 220
    static let manufacturerWidth: CGFloat = 76
    static let versionWidth: CGFloat = 96
    static let actionWidth: CGFloat = 170
    static let columnSpacing: CGFloat = 14
    static let rowHorizontalPadding: CGFloat = 12
    static let thumbnailSize = CGSize(width: 180, height: 120)
    static let popoverSize = NSSize(width: 720, height: 650)
}

struct RemoteBoardPluginIndex: Codable {
    let generated_at: String?
    let boards: [RemoteBoardPluginEntry]
}

struct RemoteBoardPluginEntry: Codable {
    let id: String
    let version: String?
    let display_name: String?
    let manufacturer: String?
    let variants: [String]?
    let download_url: String?
    let checksum_url: String?
}

struct CachedBoardPluginCatalog: Codable {
    let checked_at: String
    let boards: [RemoteBoardPluginEntry]
}

struct BoardPluginManifest: Codable {
    let id: String
    let version: String
    let display_name: String?
    let manufacturer: String?
    let variants: [String]?
    let capabilities: [String]?
    let profile_path: String?
    let tooling_config_path: String?
}

struct BoardPluginProfile: Codable {
    let board_id: String?
    let display_name: String?
    let manufacturer: String?
    let variants: [String]?
    let capabilities: [String]?
    let tooling_config_path: String?
}

struct BoardPluginToolingVariant: Codable, Equatable {
    let variant_id: String
    let display_name: String?
    let status: String?
    let supports: [String]?
}

struct BoardPluginToolingDevelopmentEnvironment: Codable, Equatable {
    let enabled: Bool?
}

struct BoardPluginToolingConfig: Codable, Equatable {
    let standard_version: String?
    let board_id: String?
    let require_explicit_variant_confirmation: Bool?
    let development_environment: BoardPluginToolingDevelopmentEnvironment?
    let variants: [BoardPluginToolingVariant]?
}

struct InstalledBoardPluginMetadata: Codable, Equatable {
    let id: String
    let version: String
    let display_name: String
    let manufacturer: String
    let variants: [String]
    let capabilities: [String]
    let manifest_path: String
    let profile_path: String
    let tooling_config_path: String?
    let require_explicit_variant_confirmation: Bool
    let development_environment_enabled: Bool
    let tooling_variants: [BoardPluginToolingVariant]
    let installed_at: String
    let plugin_source: String

    var isBuiltin: Bool {
        plugin_source == "builtin"
    }
}

struct DetectedBoardCandidate: Identifiable, Equatable {
    let id: String
    let boardID: String
    let variantID: String?
    let displayName: String
    let manufacturer: String
    let interfaceName: String
    let transportName: String
    let sourceName: String
    let priority: Int
}

struct DeviceSelectionPrompt: Identifiable, Equatable {
    let id = UUID()
    let candidates: [DetectedBoardCandidate]
}

enum ToolkitHeroState {
    case pluginHub
    case deviceReady
    case deviceClose
}

struct ActionResponse: Decodable {
    let ok: Bool?
    let action: String?
    let output: String?
    let output_tail: String?
    let log_path: String?
    let returncode: Int?
    let error: String?
}

struct AgentStatusSummaryResponse: Decodable {
    let service_state: String?
    let status_source: String?
    let connected_device: Bool?
    let board_id: String?
    let variant_id: String?
    let usb_ecm_ready: Bool?
    let ssh_ready: Bool?
    let control_service_ready: Bool?
    let installed_plugin_ids: [String]?
    let available_plugin_count: Int?
    let runtime_command: String?
    let runtime_probe_error: String?
    let summary: String?
    let device_summary: String?
    let updated_at: String?
    let runtime_status: ToolkitStatus?
    let last_reconcile_at: String?
    let staleness_ms: Int?
}

struct ToolkitTask: Decodable {
    let id: String?
    let action: String?
    let status: String?
    let created_at: String?
    let updated_at: String?
    let log_path: String?
    let output_tail: String?
    let returncode: Int?
    let ok: Bool?
}

struct TaskResponse: Decodable {
    let ok: Bool?
    let action: String?
    let task: ToolkitTask?
    let error: String?
}

struct RunActionServiceResponse: Decodable {
    let ok: Bool?
    let action: String?
    let output: String?
    let returncode: Int?
    let task: ToolkitTask?
    let error: String?
}

struct ServiceEvent: Decodable {
    let event: String?
    let sequence: Int?
    let changes: [String]?
    let state: ToolkitStatus?
}

struct TaskServiceEvent: Decodable {
    let event: String?
    let task: ToolkitTask?
}

enum WorkspaceMode: String {
    case release
    case development

    var displayName: String {
        switch self {
        case .release:
            return "发布版"
        case .development:
            return "开发版"
        }
    }

    var symbolName: String {
        switch self {
        case .release:
            return "shippingbox.fill"
        case .development:
            return "hammer.fill"
        }
    }
}

enum ActionPrecondition: Hashable {
    case checkHost
    case ensureUSBNet
    case authorizeKey
    case rebootLoader
    case rebootDevice
    case flash(String)
    case buildSync
    case buildSyncFlash
    case updateLogo(flashAfter: Bool)
    case updateDTB(flashAfter: Bool)
}

struct BoardOperationPreflightResponse: Decodable {
    let ok: Bool
    let ready: Bool
    let operation_id: String
    let board_id: String?
    let variant_id: String?
    let message: String
}

struct ActionAvailabilityState: Equatable {
    let enabled: Bool
    let reason: String?

    static let enabledState = ActionAvailabilityState(enabled: true, reason: nil)
}

enum FlashImageSource {
    case custom
    case factory

    var displayName: String {
        switch self {
        case .custom:
            return "用户镜像"
        case .factory:
            return "初始镜像"
        }
    }
}

enum ActivityLevel: String {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var symbol: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct ActivityEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: ActivityLevel
    let title: String
    let message: String
    let detail: String?
}

enum DeviceRecoveryContext {
    case flash
    case reboot

    var activityTitle: String {
        switch self {
        case .flash:
            return "刷写恢复"
        case .reboot:
            return "设备重启恢复"
        }
    }

    var initialLine: String {
        switch self {
        case .flash:
            return "刷写已完成，等待设备退出 Loader 并重启"
        case .reboot:
            return "已请求设备重启，等待设备重新枚举为 USB ECM"
        }
    }
}

struct StatusSnapshot: Equatable {
    let usbMode: String
    let usbProduct: String
    let usbPid: String
    let usbIface: String
    let hostIP: String
    let usbConfigured: Bool
    let ping: Bool
    let ssh: Bool
    let controlService: Bool
    let dockerReady: Bool
    let usbnetHelperInstalled: Bool
}

struct DevelopmentInstallStatus: Equatable {
    var dockerReady = false
    var officialImageReady = false
    var releaseVolumeReady = false
    var hostImagesReady = false
    var rkflashtoolReady = false
    var codexAvailable = false
    var codexPluginInstalled = false
    var openCodeAvailable = false
    var npmReady = false
    var openCodePluginInstalled = false
    var updatedAt = ""
}

struct LocalArtifactValidationItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let ok: Bool
    let optional: Bool
}

struct LocalArtifactValidationState: Equatable {
    var checking = false
    var checked = false
    var ready = false
    var summary = "未选择本地安装包目录"
    var items: [LocalArtifactValidationItem] = []
    var failureDetail = ""
}

struct ToolkitUpdateStatus: Equatable {
    var currentVersion = "unknown"
    var remoteVersion = ""
    var configured = false
    var updateAvailable = false
    var checkedAt = ""
}

struct InstalledBoardPluginsRegistry: Codable {
    var installed: [String: String]
}

struct BoardPluginOperationState: Equatable {
    enum Kind: Equatable {
        case idle
        case installing
        case deleting
        case failed
    }

    var kind: Kind = .idle
    var progress: Double?
    var message = ""

    var isBusy: Bool {
        kind == .installing || kind == .deleting
    }
}

struct BoardPluginAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

enum ToolkitGUIError: LocalizedError {
    case repoRootNotFound
    case cliNotFound(String)
    case invalidJSON(String)
    case commandFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .repoRootNotFound:
            return "未找到可用工具工作区。请安装发布版；如需开发版，请先准备开发目录后再切换。"
        case let .cliNotFound(path):
            return "未找到 dbtctl：\(path)"
        case let .invalidJSON(output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "命令未返回可解析结果。请查看活动日志中的详细输出。"
            }
            return "返回结果无法解析。详细输出请查看活动日志。"
        case let .commandFailed(message):
            return message
        case let .timeout(message):
            return message
        }
    }
}

enum ProcessExecutor {
    static func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        environment: [String: String]
    ) async throws -> (Int32, String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectoryURL
                process.environment = environment

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = stdout.fileHandleForReading.readDataToEndOfFile() +
                        stderr.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (
                        process.terminationStatus,
                        output.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func runSync(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        environment: [String: String]
    ) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile() +
            stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (
            process.terminationStatus,
            output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

final class SystemEventMonitor {
    private let onEvent: @MainActor (String) -> Void
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var dynamicStore: SCDynamicStore?
    private var dynamicStoreSource: CFRunLoopSource?
    private let rockchipVendorID: UInt16 = 0x2207
    private let usbECMPID: UInt16 = 0x3606
    private let loaderPID: UInt16 = 0x350a

    init(onEvent: @escaping @MainActor (String) -> Void) {
        self.onEvent = onEvent
    }

    deinit {
        stop()
    }

    func start() {
        startUSBMonitoring()
        startNetworkMonitoring()
    }

    func stop() {
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }
        if let source = dynamicStoreSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            dynamicStoreSource = nil
        }
        if let port = notificationPort {
            if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        dynamicStore = nil
    }

    private func emit(_ reason: String) {
        Task { @MainActor in
            self.onEvent(reason)
        }
    }

    private func drain(iterator: io_iterator_t, reason: String) {
        var sawEvent = false
        while true {
            let service = IOIteratorNext(iterator)
            if service == IO_OBJECT_NULL {
                break
            }
            if reason == "network" || isRelevantUSBDevice(service) {
                sawEvent = true
            }
            IOObjectRelease(service)
        }
        if sawEvent {
            emit(reason)
        }
    }

    private func isRelevantUSBDevice(_ service: io_registry_entry_t) -> Bool {
        let vendorID = registryUInt16(service: service, keys: ["idVendor", "kUSBVendorID"]) ?? 0
        let productID = registryUInt16(service: service, keys: ["idProduct", "kUSBProductID"]) ?? 0
        let product = (registryString(service: service, keys: ["USB Product Name", "product", "kUSBProductString"]) ?? "").lowercased()
        if vendorID == rockchipVendorID {
            return true
        }
        if productID == usbECMPID || productID == loaderPID {
            return true
        }
        return product.contains("rockchip") ||
            product.contains("download gadget") ||
            product.contains("usb ecm") ||
            product.contains("tspi")
    }

    private func registryUInt16(service: io_registry_entry_t, keys: [String]) -> UInt16? {
        for key in keys {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if CFGetTypeID(value) == CFNumberGetTypeID() {
                    var raw: Int32 = 0
                    if CFNumberGetValue((value as! CFNumber), .sInt32Type, &raw) {
                        return UInt16(truncatingIfNeeded: raw)
                    }
                } else if CFGetTypeID(value) == CFDataGetTypeID(), let data = value as? Data, data.count >= 2 {
                    let raw = data.withUnsafeBytes { pointer -> UInt16 in
                        pointer.load(as: UInt16.self)
                    }
                    return UInt16(littleEndian: raw)
                }
            }
        }
        return nil
    }

    private func registryString(service: io_registry_entry_t, keys: [String]) -> String? {
        for key in keys {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if let string = value as? String {
                    return string
                }
                if let data = value as? Data, let string = String(data: data, encoding: .utf8) {
                    return string.trimmingCharacters(in: .controlCharacters)
                }
            }
        }
        return nil
    }

    private func startUSBMonitoring() {
        guard notificationPort == nil else {
            return
        }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            return
        }
        notificationPort = port
        if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        let addedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else {
                return
            }
            let monitor = Unmanaged<SystemEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.drain(iterator: iterator, reason: "usb-added")
        }

        let removedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else {
                return
            }
            let monitor = Unmanaged<SystemEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.drain(iterator: iterator, reason: "usb-removed")
        }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let match = IOServiceMatching("IOUSBHostDevice") {
            IOServiceAddMatchingNotification(
                port,
                kIOFirstMatchNotification,
                match,
                addedCallback,
                context,
                &matchedIterator
            )
            drain(iterator: matchedIterator, reason: "usb-added")
        }
        if let match = IOServiceMatching("IOUSBHostDevice") {
            IOServiceAddMatchingNotification(
                port,
                kIOTerminatedNotification,
                match,
                removedCallback,
                context,
                &terminatedIterator
            )
            drain(iterator: terminatedIterator, reason: "usb-removed")
        }
    }

    private func startNetworkMonitoring() {
        guard dynamicStore == nil else {
            return
        }

        var context = SCDynamicStoreContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else {
                return
            }
            let monitor = Unmanaged<SystemEventMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.emit("network")
        }

        guard let store = SCDynamicStoreCreate(nil, "DevelopmentBoardToolchain" as CFString, callback, &context) else {
            return
        }
        dynamicStore = store
        let patterns = [
            "State:/Network/Interface/.*/IPv4" as CFString,
            "State:/Network/Interface/.*/Link" as CFString,
            "State:/Network/Global/IPv4" as CFString,
        ] as CFArray
        SCDynamicStoreSetNotificationKeys(store, nil, patterns)
        if let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) {
            dynamicStoreSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}

@MainActor
final class ToolkitViewModel: ObservableObject {
    private let requiredServiceAPIVersion = 1
    private let preferredCLIName = "dbtctl"
    private let fallbackCLIName = "dbtctl-swift"
    private let localAgentPort = 18082
    private let releaseRepoRoot: String
    @Published var repoRoot: String
    @Published var workspaceMode: WorkspaceMode
    @Published var developmentRepoRoot: String?
    @Published var status: ToolkitStatus?
    @Published var localAgentRunning = false
    @Published private(set) var eventStreamConnected = false
    @Published var busy = false
    @Published var lastError = ""
    @Published var lastActionSummary = "等待操作"
    @Published var boardCatalog: [SupportedBoard] = SupportedBoard.catalog
    @Published var activities: [ActivityEntry] = []
    @Published var logoPath = ""
    @Published var logoRotate = "-90"
    @Published var logoScale = "100"
    @Published var logoFlashAfter = true
    @Published var dtsFilePath = ""
    @Published var dtsFlashAfter = true
    @Published var localArtifactsDir = ""
    @Published var localArtifactValidation = LocalArtifactValidationState()
    @Published var inlineErrorMessage = ""
    @Published var footerFlashOn = false
    @Published var pendingTaskTitle = ""
    @Published var selectedActivityEntry: ActivityEntry?
    @Published var currentTask: ToolkitTask?
    @Published var fileDialogActive = false
    @Published var remoteBoardPluginEntries: [String: RemoteBoardPluginEntry] = [:]
    @Published var boardPluginCatalogVersions: [String: String] = [:]
    @Published var installedBoardPlugins: [String: String] = [:]
    @Published var installedBoardPluginMetadata: [String: InstalledBoardPluginMetadata] = [:]
    @Published var boardPluginOperations: [String: BoardPluginOperationState] = [:]
    @Published var boardPluginAlert: BoardPluginAlert?
    @Published var boardPluginCatalogCheckedAt = ""
    @Published var detectedBoardCandidates: [DetectedBoardCandidate] = []
    @Published var connectedBoardID: String?
    @Published var connectedBoardVariantID: String?
    @Published var connectedBoardDisplayName: String?
    @Published var preferredControlBoardID: String?
    @Published var showingSupportedBoardCatalog = true
    @Published var deviceSelectionPrompt: DeviceSelectionPrompt?
    @Published var developmentInstallStatus = DevelopmentInstallStatus()
    @Published var installerLastDetail = "等待检查"
    @Published var toolkitUpdateStatus = ToolkitUpdateStatus()
    @Published var updaterLastDetail = "等待检查"
    @Published var actionAvailability: [ActionPrecondition: ActionAvailabilityState] = [:]
    @Published var automaticToolkitUpdateInProgress = false
    @Published var postFlashRecoveryActive = false
    @Published var postFlashRecoveryFinished = false
    @Published var postFlashRecoverySucceeded = false
    @Published var postFlashRecoveryTitle = "设备恢复"
    @Published var postFlashRecoveryStatus = ""
    @Published var postFlashRecoveryProgress = ""
    @Published var postFlashRecoveryProgressValue: Double?
    @Published var postFlashRecoveryLines: [String] = []

    private var didBootstrapLocalAgent = false
    private var localAgentStartInProgress = false
    private var lastRefreshErrorSignature = ""
    private var lastSnapshot: StatusSnapshot?
    private var eventTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var transportMonitorTask: Task<Void, Never>?
    private var boardMonitorTask: Task<Void, Never>?
    private var hostMonitorTask: Task<Void, Never>?
    private var serviceMonitorTask: Task<Void, Never>?
    private var localAgentMonitorTask: Task<Void, Never>?
    private var inlineErrorDismissTask: Task<Void, Never>?
    private var inlineErrorFlashTask: Task<Void, Never>?
    private var systemMonitor: SystemEventMonitor?
    private var pendingSystemRefreshTask: Task<Void, Never>?
    private var transitionWatchTask: Task<Void, Never>?
    private var taskPollTask: Task<Void, Never>?
    private var automaticToolkitUpdateTask: Task<Void, Never>?
    private var automaticUSBNetRepairTask: Task<Void, Never>?
    private var postFlashRecoveryTask: Task<Void, Never>?
    private var boardPluginCatalogSyncTask: Task<Void, Never>?
    private var actionAvailabilityTask: Task<Void, Never>?
    private var dismissedFinishedTaskIDs: Set<String> = []
    private var monitoringStarted = false
    private var lastEventAt = Date()
    private var lastIncompatibleServiceRecoveryAt: Date?
    private var refreshSequence = 0
    private var boardStateGraceUntil: Date?
    private var boardPingFalseCount = 0
    private var boardSSHFalseCount = 0
    private var boardControlFalseCount = 0
    private let boardFalseThreshold = 3
    private var selectedDetectedCandidateID: String?
    private var boardCatalogBaselineSignature: String?
    private var shouldRelaunchAfterToolkitUpdate = false
    private var lastAutomaticUSBNetRepairAt: Date?
    private var lastAutomaticUSBNetRepairSignature = ""

    private var usesEventDrivenStatus: Bool {
        false
    }

    private var boardLinkLooksHealthy: Bool {
        guard status?.usb?.mode == "usb-ecm", status?.usbnet?.configured == true else {
            return false
        }
        return status?.board?.ping == true ||
            status?.board?.ssh_port_open == true ||
            status?.board?.control_service == true
    }

    init() {
        let release = Self.detectReleaseRepoRoot() ?? Self.detectRepoRoot() ?? ""
        let development = Self.detectDevelopmentRepoRoot(excluding: release)
        let savedMode = WorkspaceMode(rawValue: UserDefaults.standard.string(forKey: "workspaceMode") ?? "") ?? .release
        let initialMode: WorkspaceMode = (savedMode == .development && development != nil) ? .development : .release
        releaseRepoRoot = release
        developmentRepoRoot = development
        workspaceMode = initialMode
        repoRoot = Self.resolveRepoRoot(mode: initialMode, releaseRoot: release, developmentRoot: development)
        preferredControlBoardID = UserDefaults.standard.string(forKey: "preferredControlBoardID")
        loadInstalledBoardPlugins()
        requestNotificationPermission()
    }

    static func detectRepoRoot() -> String? {
        let fm = FileManager.default
        let defaults = UserDefaults.standard.string(forKey: "repoRoot")
        let environment = ProcessInfo.processInfo.environment
        let env = environment["DBT_TOOLKIT_REPO_ROOT"] ?? environment["RK356X_TOOLKIT_REPO_ROOT"]
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let bundle = Bundle.main.bundleURL

        var candidates: [URL] = []
        [defaults, env].compactMap { $0 }.forEach { candidates.append(URL(fileURLWithPath: $0)) }
        candidates.append(sharedRuntimeRootURLStatic())

        var current = bundle
        for _ in 0..<8 {
            candidates.append(current)
            current.deleteLastPathComponent()
        }

        current = cwd
        for _ in 0..<8 {
            candidates.append(current)
            current.deleteLastPathComponent()
        }

        for candidate in candidates {
            let normalized = candidate.standardizedFileURL
            if Self.isValidRepoRoot(normalized.path) {
                return normalized.path
            }
            let nested = normalized.appendingPathComponent("docker_mac_env")
            if Self.isValidRepoRoot(nested.path) {
                return nested.path
            }
        }
        return nil
    }

    static func detectReleaseRepoRoot() -> String? {
        let runtime = sharedRuntimeRootURLStatic()
        if isValidRepoRoot(runtime.path) {
            return runtime.standardizedFileURL.path
        }
        return detectRepoRoot()
    }

    static func sharedRuntimeRootURLStatic() -> URL {
        let fileManager = FileManager.default
        let generic = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("development-board-toolchain", isDirectory: true))
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/development-board-toolchain", isDirectory: true)
        return generic.appendingPathComponent("runtime", isDirectory: true)
    }

    static func detectDevelopmentRepoRoot(excluding releaseRoot: String) -> String? {
        let fm = FileManager.default
        let defaults = UserDefaults.standard.string(forKey: "developmentRepoRoot") ?? UserDefaults.standard.string(forKey: "repoRoot")
        let env = ProcessInfo.processInfo.environment["RK356X_TOOLKIT_DEV_ROOT"]
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let bundle = Bundle.main.bundleURL
        let releasePath = URL(fileURLWithPath: releaseRoot).standardizedFileURL.path

        var candidates: [URL] = []
        [defaults, env].compactMap { $0 }.forEach { candidates.append(URL(fileURLWithPath: $0)) }

        var current = bundle
        for _ in 0..<8 {
            candidates.append(current)
            current.deleteLastPathComponent()
        }

        current = cwd
        for _ in 0..<8 {
            candidates.append(current)
            current.deleteLastPathComponent()
        }

        for candidate in candidates {
            let normalized = candidate.standardizedFileURL
            for probe in [normalized, normalized.appendingPathComponent("docker_mac_env")] {
                let path = probe.standardizedFileURL.path
                guard path != releasePath else {
                    continue
                }
                if isValidRepoRoot(path) {
                    return path
                }
            }
        }
        return nil
    }

    static func resolveRepoRoot(mode: WorkspaceMode, releaseRoot: String, developmentRoot: String?) -> String {
        switch mode {
        case .release:
            return releaseRoot
        case .development:
            return developmentRoot ?? releaseRoot
        }
    }

    static func isValidRepoRoot(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("dbtctl").path) ||
            FileManager.default.fileExists(atPath: url.appendingPathComponent("dbtctl-swift").path) ||
            FileManager.default.fileExists(atPath: url.appendingPathComponent("mac_app/swift-cli/build/dbtctl-swift").path)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func loadInstalledBoardPlugins() {
        ensureBuiltinBoardPlugins()
        let url = boardPluginRegistryURL()
        guard let data = try? Data(contentsOf: url),
              let registry = try? JSONDecoder().decode(InstalledBoardPluginsRegistry.self, from: data) else {
            installedBoardPlugins = [:]
            reloadInstalledBoardPluginMetadata()
            updateBoardRoutingFromCurrentState()
            return
        }
        installedBoardPlugins = registry.installed
        reloadInstalledBoardPluginMetadata()
    }

    func persistInstalledBoardPlugins() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: boardPluginsRootURL(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(InstalledBoardPluginsRegistry(installed: installedBoardPlugins))
        try data.write(to: boardPluginRegistryURL(), options: .atomic)
    }

    func reloadInstalledBoardPluginMetadata() {
        var validInstalled = installedBoardPlugins
        var metadata: [String: InstalledBoardPluginMetadata] = [:]

        for (boardID, version) in installedBoardPlugins {
            do {
                let installRoot = boardPluginInstallRootURL(for: boardID)
                let validated = try validateInstalledBoardPlugin(at: installRoot, expectedBoardID: boardID, expectedVersion: version, pluginSource: "user")
                metadata[boardID] = validated
            } catch {
                validInstalled.removeValue(forKey: boardID)
            }
        }

        let fm = FileManager.default
        let builtinRoot = builtinBoardPluginsRootURL()
        if fm.fileExists(atPath: builtinRoot.path) {
            let entries = (try? fm.contentsOfDirectory(at: builtinRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                let boardID = entry.lastPathComponent
                do {
                    let manifestURL = try findBoardPluginFile(named: "manifest.json", under: entry)
                    let manifest = try JSONDecoder().decode(BoardPluginManifest.self, from: Data(contentsOf: manifestURL))
                    let version = manifest.version
                    let validated = try validateInstalledBoardPlugin(at: entry, expectedBoardID: boardID, expectedVersion: version, pluginSource: "builtin")
                    metadata[boardID] = validated
                } catch {
                    continue
                }
            }
        }

        installedBoardPlugins = validInstalled
        installedBoardPluginMetadata = metadata
        try? persistInstalledBoardPlugins()
        updateBoardRoutingFromCurrentState()
    }

    deinit {
        eventTask?.cancel()
        watchdogTask?.cancel()
        transportMonitorTask?.cancel()
        boardMonitorTask?.cancel()
        hostMonitorTask?.cancel()
        serviceMonitorTask?.cancel()
        inlineErrorDismissTask?.cancel()
        inlineErrorFlashTask?.cancel()
        pendingSystemRefreshTask?.cancel()
        transitionWatchTask?.cancel()
        taskPollTask?.cancel()
        postFlashRecoveryTask?.cancel()
        boardPluginCatalogSyncTask?.cancel()
        actionAvailabilityTask?.cancel()
        systemMonitor?.stop()
    }

    func persistWorkspaceSelection() {
        UserDefaults.standard.set(workspaceMode.rawValue, forKey: "workspaceMode")
        if let developmentRepoRoot {
            UserDefaults.standard.set(developmentRepoRoot, forKey: "developmentRepoRoot")
        }
    }

    func workspaceURL() throws -> URL {
        let sharedRuntime = sharedRuntimeRootURL()
        if Self.isValidRepoRoot(sharedRuntime.path) {
            return sharedRuntime
        }
        guard !repoRoot.isEmpty else {
            throw ToolkitGUIError.repoRootNotFound
        }
        let url = URL(fileURLWithPath: repoRoot)
        guard Self.isValidRepoRoot(url.path) else {
            throw ToolkitGUIError.cliNotFound(sharedRuntime.appendingPathComponent(preferredCLIName).path)
        }
        return url
    }

    func cliURL() throws -> URL {
        let root = try workspaceURL()
        let candidates = [
            root.appendingPathComponent(preferredCLIName),
            root.appendingPathComponent(fallbackCLIName),
            root.appendingPathComponent("mac_app/swift-cli/build/dbtctl-swift"),
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return root.appendingPathComponent(preferredCLIName)
    }

    var localAgentBaseURL: URL {
        URL(string: "http://127.0.0.1:\(localAgentPort)")!
    }

    var remoteBoardPluginIndexURL: URL {
        URL(string: "https://gitee.com/kvell/development-board-toolchain/raw/master/plugins/index.json")!
    }

    func appSupportRootURL() -> URL {
        let fileManager = FileManager.default
        let generic = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("development-board-toolchain")) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("development-board-toolchain")
        let legacy = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("rk356x-mac-toolkit")) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rk356x-mac-toolkit")
        if fileManager.fileExists(atPath: legacy.path), !fileManager.fileExists(atPath: generic.path) {
            return legacy
        }
        return generic
    }

    func boardPluginsRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("plugins", isDirectory: true)
    }

    func boardPluginCatalogCacheURL() -> URL {
        boardPluginsRootURL().appendingPathComponent("catalog-cache.json")
    }

    func boardPluginRegistryURL() -> URL {
        userBoardPluginsRootURL().appendingPathComponent("installed.json")
    }

    func boardPluginDownloadsRootURL() -> URL {
        userBoardPluginsRootURL().appendingPathComponent("downloads", isDirectory: true)
    }

    func boardPluginInstallRootURL(for boardID: String) -> URL {
        userBoardPluginsRootURL().appendingPathComponent(boardID, isDirectory: true)
    }

    func builtinBoardPluginsRootURL() -> URL {
        boardPluginsRootURL().appendingPathComponent("builtin", isDirectory: true)
    }

    func userBoardPluginsRootURL() -> URL {
        boardPluginsRootURL().appendingPathComponent("user", isDirectory: true)
    }

    func sharedRuntimeRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("runtime", isDirectory: true)
    }

    func imagesRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("images", isDirectory: true)
    }

    func factoryImagesRootURL() -> URL {
        imagesRootURL().appendingPathComponent("factory", isDirectory: true)
    }

    func customImagesRootURL() -> URL {
        imagesRootURL().appendingPathComponent("custom", isDirectory: true)
    }

    func factoryImageDirURL() -> URL {
        factoryImagesRootURL().appendingPathComponent("current", isDirectory: true)
    }

    func customImageDirURL() -> URL {
        customImagesRootURL().appendingPathComponent("current", isDirectory: true)
    }

    func bundledBoardPluginsRootURL() -> URL {
        let fm = FileManager.default
        guard let root = try? workspaceURL() else {
            return URL(fileURLWithPath: "/nonexistent", isDirectory: true)
        }

        let candidates = [
            root.appendingPathComponent("builtin-plugin-seed", isDirectory: true),
            root
                .appendingPathComponent("product_release/board_plugins", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true),
        ]
        return candidates.first(where: { fm.fileExists(atPath: $0.path) })
            ?? URL(fileURLWithPath: "/nonexistent", isDirectory: true)
    }

    func ensureBuiltinBoardPlugins() {
        let fm = FileManager.default
        let sourceRoot = bundledBoardPluginsRootURL()
        guard fm.fileExists(atPath: sourceRoot.path) else { return }
        let builtinBoardIDs: Set<String> = ["TaishanPi"]
        let targetRoot = builtinBoardPluginsRootURL()
        try? fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        let existing = (try? fm.contentsOfDirectory(at: targetRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in existing {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            if !builtinBoardIDs.contains(entry.lastPathComponent) {
                try? fm.removeItem(at: entry)
            }
        }
        let entries = (try? fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true, builtinBoardIDs.contains(entry.lastPathComponent) else { continue }
            let target = targetRoot.appendingPathComponent(entry.lastPathComponent, isDirectory: true)
            try? fm.removeItem(at: target)
            try? fm.copyItem(at: entry, to: target)
        }
    }

    func boardPluginInstalledVersion(_ boardID: String) -> String? {
        installedBoardPluginMetadata[boardID]?.version ?? installedBoardPlugins[boardID]
    }

    func boardPluginCatalogVersion(_ boardID: String) -> String? {
        boardPluginCatalogVersions[boardID]
    }

    func boardPluginDisplayVersion(_ boardID: String) -> String {
        boardPluginCatalogVersion(boardID) ?? boardPluginInstalledVersion(boardID) ?? "-"
    }

    func isBoardPluginInstalled(_ boardID: String) -> Bool {
        boardPluginInstalledVersion(boardID) != nil
    }

    func remoteBoardPluginEntry(_ boardID: String) -> RemoteBoardPluginEntry? {
        remoteBoardPluginEntries[boardID]
    }

    func installedBoardToolingMetadata(_ boardID: String) -> InstalledBoardPluginMetadata? {
        installedBoardPluginMetadata[boardID]
    }

    func canRemoveBoardPlugin(_ boardID: String) -> Bool {
        !(installedBoardPluginMetadata[boardID]?.isBuiltin ?? false)
    }

    func activeVariantID(for boardID: String) -> String? {
        if let currentLiveCandidate, currentLiveCandidate.boardID == boardID {
            return currentLiveCandidate.variantID
        }
        guard connectedBoardID == boardID, !detectedBoardCandidates.isEmpty else {
            return nil
        }
        return connectedBoardVariantID
    }

    func boardSupportsDevelopmentEnvironment(_ boardID: String, variantID: String?) -> Bool {
        guard let metadata = installedBoardPluginMetadata[boardID],
              metadata.development_environment_enabled else {
            return false
        }
        if metadata.tooling_variants.isEmpty {
            return true
        }
        if let variantID, !variantID.isEmpty,
           let matched = metadata.tooling_variants.first(where: { $0.variant_id == variantID }) {
            return (matched.status ?? "supported").lowercased() == "supported" &&
                (matched.supports ?? []).contains("development_environment")
        }
        if metadata.require_explicit_variant_confirmation {
            return false
        }
        return metadata.tooling_variants.contains {
            ($0.status ?? "supported").lowercased() == "supported" &&
            ($0.supports ?? []).contains("development_environment")
        }
    }

    func actionAvailabilityState(for precondition: ActionPrecondition) -> ActionAvailabilityState {
        actionAvailability[precondition] ?? .enabledState
    }

    func flashAvailabilityState(for target: String, source: FlashImageSource) -> ActionAvailabilityState {
        let base = actionAvailabilityState(for: .flash(target))
        guard base.enabled else {
            return base
        }
        if let localError = localFlashPrerequisiteError(target, source: source) {
            return ActionAvailabilityState(enabled: false, reason: localError)
        }
        return base
    }

    private func currentOperationRoute() -> (boardID: String?, variantID: String?) {
        let boardID = preferredControlBoardID ?? connectedBoardID
        let variantID = boardID.flatMap { activeVariantID(for: $0) }
        return (boardID, variantID)
    }

    private func localFlashPrerequisiteError(_ target: String, source: FlashImageSource = .custom) -> String? {
        let imageDir = imageDirURL(for: source)
        let parameter = imageDir.appendingPathComponent("parameter.txt")
        guard FileManager.default.fileExists(atPath: parameter.path) else {
            return "未找到 parameter.txt：\(parameter.path)"
        }
        if target == "all" {
            guard hasAnyFlashableImage(source: source) else {
                return "镜像目录中没有可刷写的镜像文件：\(imageDir.path)"
            }
        } else {
            guard let imagePath = resolvedImagePath(for: target, source: source) else {
                return "未找到 \(target) 对应镜像文件，期望目录：\(imageDir.path)"
            }
            guard FileManager.default.fileExists(atPath: imagePath.path) else {
                return "镜像文件不存在：\(imagePath.path)"
            }
        }
        return nil
    }

    private func boardOperationPreflightMessage(operationID: String, boardID: String?, variantID: String?) async -> String? {
        var args = ["board", "preflight", "--operation", operationID, "--json"]
        if let boardID, !boardID.isEmpty {
            args.append(contentsOf: ["--board", boardID])
        }
        if let variantID, !variantID.isEmpty {
            args.append(contentsOf: ["--variant", variantID])
        }
        do {
            let response = try await runDecodedCLI(args, as: BoardOperationPreflightResponse.self)
            return response.ready ? nil : response.message
        } catch {
            return error.localizedDescription
        }
    }

    private func liveBoardConnectionReady() -> Bool {
        if connectedBoardID != nil || currentLiveCandidate != nil {
            return true
        }
        return hasRockchipSignalFromStatus()
    }

    private func liveUSBControlReady() -> Bool {
        guard liveBoardConnectionReady() else { return false }
        return status?.board?.control_service == true
    }

    private func liveUSBOrSSHReady() -> Bool {
        guard liveBoardConnectionReady() else { return false }
        return status?.board?.control_service == true || status?.board?.ssh_port_open == true
    }

    private func liveFlashTransportReady() -> Bool {
        guard liveBoardConnectionReady() else { return false }
        let usbMode = (status?.usb?.mode ?? "").lowercased()
        return usbMode == "loader" || usbMode == "usb-ecm" || usbMode == "rockchip-other"
    }

    func refreshActionAvailability() {
        actionAvailabilityTask?.cancel()
        actionAvailabilityTask = nil

        let dockerReady = status?.host?.docker_daemon == true
        let usbMode = (status?.usb?.mode ?? "").lowercased()
        let usbControlReady = liveUSBControlReady()
        let usbOrSSHReady = liveUSBOrSSHReady()
        let flashTransportReady = liveFlashTransportReady()

        var next: [ActionPrecondition: ActionAvailabilityState] = [:]
        next[.checkHost] = .enabledState
        next[.ensureUSBNet] = usbMode == "usb-ecm"
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到 USB ECM 连接，无法恢复主机静态地址。")
        next[.authorizeKey] = usbControlReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用的 USB 控制服务。请确认开发板已联机并完成 USB ECM 初始化。")
        next[.rebootLoader] = usbControlReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用的 USB 控制服务。请确认开发板已联机并完成 USB ECM 初始化。")
        next[.rebootDevice] = usbOrSSHReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用的设备控制链路。请确认 SSH 或控制服务已恢复。")

        for target in ["all", "boot", "rootfs", "userdata"] {
            next[.flash(target)] = flashTransportReady
                ? .enabledState
                : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用于刷写的开发板连接。请确认开发板已进入 Loader 或 USB ECM 状态。")
        }

        next[.buildSync] = dockerReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "Docker 未就绪，无法执行构建同步。")

        if !dockerReady {
            next[.buildSyncFlash] = ActionAvailabilityState(enabled: false, reason: "Docker 未就绪，无法执行构建同步刷写。")
        } else if !flashTransportReady {
            next[.buildSyncFlash] = ActionAvailabilityState(enabled: false, reason: "当前未检测到可用于刷写的开发板连接。请确认开发板已进入 Loader 或 USB ECM 状态。")
        } else {
            next[.buildSyncFlash] = .enabledState
        }

        if actionAvailability != next {
            actionAvailability = next
        }
    }

    func hostImageDirURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["HOST_IMAGE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let legacy = appSupportRootURL().appendingPathComponent("tspi-img", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: factoryImageDirURL().path) {
            return legacy
        }
        return factoryImageDirURL()
    }

    var officialImageName: String { "tspi-rk356x-env" }
    var officialContainerName: String { "tspi-rk356x-official-container" }
    var officialVolumeName: String { "tspi-rk356x-official-workspace" }
    var developmentContainerName: String { "rk-sdk-container" }
    var developmentVolumeName: String { "rk-sdk-workspace" }

    var activeContainerName: String {
        workspaceMode == .release ? officialContainerName : developmentContainerName
    }

    var activeVolumeName: String {
        workspaceMode == .release ? officialVolumeName : developmentVolumeName
    }

    var activeImageName: String {
        officialImageName
    }

    func workspaceRuntimeEnvironment() -> [String: String] {
        [
            "IMAGE_NAME": activeImageName,
            "CONTAINER_NAME": activeContainerName,
            "VOLUME_NAME": activeVolumeName,
        ]
    }

    func bundledRuntimeIsActive() -> Bool {
        guard !releaseRepoRoot.isEmpty else {
            return false
        }
        return URL(fileURLWithPath: releaseRepoRoot).standardizedFileURL.path ==
            URL(fileURLWithPath: repoRoot).standardizedFileURL.path
    }

    func runCLI(_ arguments: [String], environmentOverrides: [String: String] = [:]) async throws -> (Int32, String) {
        let executableURL = try cliURL()
        let currentDirectoryURL = try workspaceURL()

        var env = ProcessInfo.processInfo.environment
        for (key, value) in workspaceRuntimeEnvironment() {
            env[key] = value
        }
        if bundledRuntimeIsActive() {
            let supportRoot = appSupportRootURL()
            let stateDir = supportRoot.appendingPathComponent("state")
            let imageDir = hostImageDirURL()
            env["DBT_TOOLKIT_APP_SUPPORT_DIR"] = supportRoot.path
            env["DBT_TOOLKIT_STATE_DIR"] = stateDir.path
            env["RK356X_TOOLKIT_APP_SUPPORT_DIR"] = supportRoot.path
            env["RK356X_TOOLKIT_STATE_DIR"] = stateDir.path
            env["HOST_IMAGE_DIR"] = imageDir.path
        }
        for (key, value) in environmentOverrides {
            env[key] = value
        }
        return try await ProcessExecutor.run(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL,
            environment: env
        )
    }

    func shellEnvironment() throws -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PROJECT_ROOT"] = try workspaceURL().path
        env["HOST_IMAGE_DIR"] = hostImageDirURL().path
        for (key, value) in workspaceRuntimeEnvironment() {
            env[key] = value
        }
        if bundledRuntimeIsActive() {
            let supportRoot = appSupportRootURL()
            env["DBT_TOOLKIT_APP_SUPPORT_DIR"] = supportRoot.path
            env["DBT_TOOLKIT_STATE_DIR"] = supportRoot.appendingPathComponent("state").path
            env["RK356X_TOOLKIT_APP_SUPPORT_DIR"] = supportRoot.path
            env["RK356X_TOOLKIT_STATE_DIR"] = supportRoot.appendingPathComponent("state").path
            env["HOST_IMAGE_DIR"] = hostImageDirURL().path
        }
        return env
    }

    func runShell(_ script: String) async throws -> (Int32, String) {
        try await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-lc", script],
            currentDirectoryURL: try workspaceURL(),
            environment: try shellEnvironment()
        )
    }

    func extractJSONObject(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    func runJSONAction(_ arguments: [String], environmentOverrides: [String: String] = [:]) async throws -> ActionResponse {
        let (code, output) = try await runCLI(arguments, environmentOverrides: environmentOverrides)
        guard let jsonText = extractJSONObject(output) else {
            throw ToolkitGUIError.invalidJSON(output)
        }
        let data = Data(jsonText.utf8)
        let response = try JSONDecoder().decode(ActionResponse.self, from: data)
        if code != 0 || response.ok == false {
            throw ToolkitGUIError.commandFailed(response.error ?? output)
        }
        return response
    }

    func runDecodedCLI<T: Decodable>(_ arguments: [String], as type: T.Type, environmentOverrides: [String: String] = [:]) async throws -> T {
        let (code, output) = try await runCLI(arguments, environmentOverrides: environmentOverrides)
        guard let jsonText = extractJSONObject(output) else {
            throw ToolkitGUIError.invalidJSON(output)
        }
        let data = Data(jsonText.utf8)
        let response = try JSONDecoder().decode(type, from: data)
        if code != 0 {
            throw ToolkitGUIError.commandFailed(output)
        }
        return response
    }

    func localAgentURL(path: String) -> URL {
        localAgentBaseURL.appendingPathComponent(path)
    }

    func localAgentRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("agent", isDirectory: true)
    }

    func localAgentBinaryURL() -> URL {
        localAgentRootURL().appendingPathComponent("bin/dbt-agentd")
    }

    func localAgentConfigURL() -> URL {
        localAgentRootURL().appendingPathComponent("config/dbt-agentd.local.json")
    }

    func localAgentRunRootURL() -> URL {
        localAgentRootURL().appendingPathComponent("run", isDirectory: true)
    }

    func fetchLocalAgentHealthz() async throws {
        var request = URLRequest(url: localAgentURL(path: "healthz"))
        request.timeoutInterval = 2
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 不可用")
        }
        localAgentRunning = true
    }

    func ensureLocalAgentStartedIfNeeded() async {
        if localAgentStartInProgress {
            return
        }
        if (try? await fetchLocalAgentHealthz()) != nil {
            didBootstrapLocalAgent = true
            localAgentRunning = true
            return
        }
        let binaryURL = localAgentBinaryURL()
        let configURL = localAgentConfigURL()
        guard FileManager.default.fileExists(atPath: binaryURL.path),
              FileManager.default.fileExists(atPath: configURL.path) else {
            return
        }
        localAgentStartInProgress = true
        defer { localAgentStartInProgress = false }
        do {
            try FileManager.default.createDirectory(at: localAgentRunRootURL(), withIntermediateDirectories: true)
            let logURL = localAgentRunRootURL().appendingPathComponent("dbt-agentd.log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let logHandle = try FileHandle(forWritingTo: logURL)
            try logHandle.seekToEnd()

            let process = Process()
            process.executableURL = binaryURL
            process.arguments = ["--config", configURL.path]
            process.currentDirectoryURL = localAgentRootURL()
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()
            try? await Task.sleep(for: .milliseconds(400))
            _ = try await fetchLocalAgentHealthz()
            didBootstrapLocalAgent = true
            localAgentRunning = true
            appendActivity(level: .success, title: "本地 DBT Agent", message: "已启动")
        } catch {
            localAgentRunning = false
            appendActivity(level: .warning, title: "本地 DBT Agent", message: "启动失败", detail: error.localizedDescription)
        }
    }

    func fetchLocalAgentStatusSummary() async throws -> AgentStatusSummaryResponse {
        var request = URLRequest(url: localAgentURL(path: "v1/status/summary"))
        request.timeoutInterval = 4
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 状态请求失败")
        }
        localAgentRunning = true
        return try JSONDecoder().decode(AgentStatusSummaryResponse.self, from: data)
    }

    func fetchLocalAgentTask(_ taskID: String) async throws -> ToolkitTask {
        var request = URLRequest(url: localAgentURL(path: "v1/jobs/\(taskID)"))
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 任务请求失败")
        }
        let envelope = try JSONDecoder().decode(TaskResponse.self, from: data)
        if http.statusCode != 200 || envelope.ok == false || envelope.task == nil {
            throw ToolkitGUIError.commandFailed(envelope.error ?? "本地 DBT Agent 任务请求失败")
        }
        localAgentRunning = true
        return envelope.task!
    }

    func postLocalAgentFlashJob(
        scope: String,
        source: FlashImageSource,
        boardID: String?,
        variantID: String?,
        hostImageDir: String
    ) async throws -> TaskResponse {
        var payload: [String: Any] = [
            "image_source": source == .factory ? "factory" : "custom",
            "scope": scope,
            "host_image_dir": hostImageDir
        ]
        if let boardID, !boardID.isEmpty {
            payload["board_id"] = boardID
        }
        if let variantID, !variantID.isEmpty {
            payload["variant_id"] = variantID
        }

        var request = URLRequest(url: localAgentURL(path: "v1/jobs/flash"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 刷写任务启动失败")
        }
        let envelope = try JSONDecoder().decode(TaskResponse.self, from: data)
        if http.statusCode != 200 || envelope.ok == false || envelope.task == nil {
            throw ToolkitGUIError.commandFailed(envelope.error ?? "本地 DBT Agent 刷写任务启动失败")
        }
        localAgentRunning = true
        return envelope
    }

    func postLocalAgentRebootJob(
        target: String,
        boardID: String?,
        variantID: String?
    ) async throws -> TaskResponse {
        var payload: [String: Any] = [
            "target": target
        ]
        if let boardID, !boardID.isEmpty {
            payload["board_id"] = boardID
        }
        if let variantID, !variantID.isEmpty {
            payload["variant_id"] = variantID
        }

        var request = URLRequest(url: localAgentURL(path: "v1/jobs/reboot"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 重启任务启动失败")
        }
        let envelope = try JSONDecoder().decode(TaskResponse.self, from: data)
        if http.statusCode != 200 || envelope.ok == false || envelope.task == nil {
            throw ToolkitGUIError.commandFailed(envelope.error ?? "本地 DBT Agent 重启任务启动失败")
        }
        localAgentRunning = true
        return envelope
    }

    func postLocalAgentRuntimeJob(
        actionID: String,
        title: String,
        arguments: [String],
        environmentOverrides: [String: String] = [:]
    ) async throws -> TaskResponse {
        var payload: [String: Any] = [
            "action_id": actionID,
            "title": title,
            "arguments": arguments
        ]
        if !environmentOverrides.isEmpty {
            payload["environment_overrides"] = environmentOverrides
        }

        var request = URLRequest(url: localAgentURL(path: "v1/jobs/runtime-action"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 任务启动失败")
        }
        let envelope = try JSONDecoder().decode(TaskResponse.self, from: data)
        if http.statusCode != 200 || envelope.ok == false || envelope.task == nil {
            throw ToolkitGUIError.commandFailed(envelope.error ?? "本地 DBT Agent 任务启动失败")
        }
        localAgentRunning = true
        return envelope
    }

    func runLocalAgentRuntimeJobAndWait(
        actionID: String,
        title: String,
        arguments: [String],
        environmentOverrides: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> ToolkitTask {
        await ensureLocalAgentStartedIfNeeded()
        guard localAgentRunning else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
        }
        let envelope = try await postLocalAgentRuntimeJob(
            actionID: actionID,
            title: title,
            arguments: arguments,
            environmentOverrides: environmentOverrides
        )
        guard let initialTask = envelope.task, let taskID = initialTask.id else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 未返回任务信息")
        }
        let deadline = Date().addingTimeInterval(timeout)
        var latestTask = initialTask
        while !Task.isCancelled, Date() < deadline {
            latestTask = try await fetchLocalAgentTask(taskID)
            if latestTask.status == "finished" {
                guard latestTask.ok == true else {
                    throw ToolkitGUIError.commandFailed(latestTask.output_tail ?? "任务执行失败")
                }
                return latestTask
            }
            try await Task.sleep(for: .milliseconds(800))
        }
        throw ToolkitGUIError.timeout("\(title)超时")
    }

    func applyLocalAgentStatusSummary(_ agentStatus: AgentStatusSummaryResponse, silent: Bool = false) {
        if let runtimeStatus = agentStatus.runtime_status {
            applyStatusUpdate(runtimeStatus, silent: silent)
            return
        }

        let nextDevice = ToolkitStatus.Device(
            board_id: agentStatus.board_id,
            variant_id: agentStatus.variant_id,
            connected: agentStatus.connected_device,
            display_name: connectedBoardDisplayName,
            manufacturer: nil,
            interface_name: nil,
            transport_name: agentStatus.usb_ecm_ready == true ? "USB ECM" : nil,
            source_name: "dbt-agentd"
        )
        let merged = mergedStatus(
            usbnet: ToolkitStatus.USBNet(
                iface: status?.usbnet?.iface,
                current_ip: status?.usbnet?.current_ip,
                expected_ip: status?.usbnet?.expected_ip ?? "198.19.77.2",
                board_ip: status?.usbnet?.board_ip ?? "198.19.77.1",
                configured: agentStatus.usb_ecm_ready
            ),
            board: ToolkitStatus.Board(
                ping: agentStatus.connected_device,
                ssh_port_open: agentStatus.ssh_ready,
                control_service: agentStatus.control_service_ready
            ),
            device: nextDevice,
            summary: agentStatus.summary,
            deviceSummary: agentStatus.device_summary,
            updatedAt: agentStatus.updated_at
        )
        applyStatusUpdate(merged, silent: silent)
    }

    func loadCachedBoardPluginCatalog() {
        let url = boardPluginCatalogCacheURL()
        guard let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedBoardPluginCatalog.self, from: data) else {
            boardCatalog = SupportedBoard.catalog
            boardPluginCatalogVersions = [:]
            return
        }
        applyRemoteBoardPluginEntries(cached.boards, checkedAt: cached.checked_at)
    }

    func startBoardPluginCatalogSyncLoop() {
        guard boardPluginCatalogSyncTask == nil else {
            return
        }
        loadCachedBoardPluginCatalog()
        boardPluginCatalogSyncTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.syncBoardPluginCatalog(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(21600))
                await self.syncBoardPluginCatalog(force: true)
            }
        }
    }

    func syncBoardPluginCatalog(force: Bool = false) async {
        if !force,
           !boardPluginCatalogCheckedAt.isEmpty,
           let checkedAt = ISO8601DateFormatter().date(from: boardPluginCatalogCheckedAt),
           Date().timeIntervalSince(checkedAt) < 300
        {
            return
        }

        do {
            var request = URLRequest(url: remoteBoardPluginIndexURL)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ToolkitGUIError.commandFailed("插件目录同步失败：远端返回异常")
            }

            let entries = try parseRemoteBoardPluginEntries(data: data)
            let checkedAt = ISO8601DateFormatter().string(from: Date())
            try FileManager.default.createDirectory(at: boardPluginsRootURL(), withIntermediateDirectories: true)
            let cacheData = try JSONEncoder().encode(CachedBoardPluginCatalog(checked_at: checkedAt, boards: entries))
            try cacheData.write(to: boardPluginCatalogCacheURL(), options: .atomic)
            applyRemoteBoardPluginEntries(entries, checkedAt: checkedAt)
        } catch {
            let detail = error.localizedDescription
            if boardPluginCatalogCheckedAt.isEmpty {
                boardCatalog = SupportedBoard.catalog
            }
            appendActivity(level: .warning, title: "插件目录", message: "远端插件目录同步失败", detail: detail)
        }
    }

    func installOrRemoveBoardPlugin(_ board: SupportedBoard) {
        if isBoardPluginInstalled(board.id) {
            if !canRemoveBoardPlugin(board.id) {
                return
            }
            removeBoardPlugin(board)
        } else {
            installBoardPlugin(board)
        }
    }

    func installBoardPlugin(_ board: SupportedBoard) {
        guard !boardPluginOperation(for: board.id).isBusy else {
            return
        }
        guard let version = boardPluginCatalogVersion(board.id), !version.isEmpty else {
            boardPluginAlert = BoardPluginAlert(title: "插件安装失败", message: "远端插件目录尚未提供 \(board.displayName) 的版本信息。")
            return
        }

        boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.02, message: "准备下载")

        Task {
            do {
                let downloadURL = derivedBoardPluginDownloadURL(boardID: board.id, version: version)
                let checksumURL = derivedBoardPluginChecksumURL(boardID: board.id, version: version)
                try FileManager.default.createDirectory(at: boardPluginDownloadsRootURL(), withIntermediateDirectories: true)
                let zipURL = boardPluginDownloadsRootURL().appendingPathComponent("\(board.id)-\(version).zip")

                try await downloadBoardPluginArchive(from: downloadURL, to: zipURL, boardID: board.id)

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.72, message: "校验下载文件")
                let expectedSHA = try await fetchBoardPluginChecksum(from: checksumURL)
                let actualSHA = try sha256Hex(for: zipURL)
                guard actualSHA.caseInsensitiveCompare(expectedSHA) == .orderedSame else {
                    throw ToolkitGUIError.commandFailed("插件校验失败：SHA256 不匹配")
                }

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.84, message: "安装插件")
                let installRoot = boardPluginInstallRootURL(for: board.id)
                if FileManager.default.fileExists(atPath: installRoot.path) {
                    try FileManager.default.removeItem(at: installRoot)
                }
                try FileManager.default.createDirectory(at: installRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
                try unzipBoardPluginArchive(zipURL: zipURL, destinationURL: installRoot)

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.93, message: "校验插件内容")
                let metadata = try validateInstalledBoardPlugin(at: installRoot, expectedBoardID: board.id, expectedVersion: version)

                installedBoardPlugins[board.id] = version
                installedBoardPluginMetadata[board.id] = metadata
                try persistInstalledBoardPlugins()
                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .idle, progress: nil, message: "")
                appendActivity(level: .success, title: "插件安装", message: "\(board.displayName) 插件安装完成", detail: "版本 \(version)")
                refreshStatus(silent: true)
            } catch {
                let installRoot = boardPluginInstallRootURL(for: board.id)
                if FileManager.default.fileExists(atPath: installRoot.path) {
                    try? FileManager.default.removeItem(at: installRoot)
                }
                installedBoardPlugins.removeValue(forKey: board.id)
                installedBoardPluginMetadata.removeValue(forKey: board.id)
                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .failed, progress: nil, message: error.localizedDescription)
                boardPluginAlert = BoardPluginAlert(title: "插件安装失败", message: error.localizedDescription)
                appendActivity(level: .error, title: "插件安装失败", message: board.displayName, detail: error.localizedDescription)
            }
        }
    }

    func removeBoardPlugin(_ board: SupportedBoard) {
        guard !boardPluginOperation(for: board.id).isBusy else {
            return
        }
        guard canRemoveBoardPlugin(board.id) else {
            boardPluginAlert = BoardPluginAlert(title: "内置插件", message: "\(board.displayName) 是内置只读插件，不能删除。")
            return
        }

        boardPluginOperations[board.id] = BoardPluginOperationState(kind: .deleting, progress: nil, message: "正在删除")
        Task {
            do {
                let installRoot = boardPluginInstallRootURL(for: board.id)
                if FileManager.default.fileExists(atPath: installRoot.path) {
                    try FileManager.default.removeItem(at: installRoot)
                }
                installedBoardPlugins.removeValue(forKey: board.id)
                installedBoardPluginMetadata.removeValue(forKey: board.id)
                try persistInstalledBoardPlugins()
                if connectedBoardID == board.id {
                    connectedBoardID = nil
                    connectedBoardDisplayName = nil
                    showingSupportedBoardCatalog = true
                }
                if preferredControlBoardID == board.id {
                    setPreferredControlBoard(nil)
                }
                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .idle, progress: nil, message: "")
                appendActivity(level: .success, title: "插件删除", message: "\(board.displayName) 插件已删除")
                refreshStatus(silent: true)
            } catch {
                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .failed, progress: nil, message: error.localizedDescription)
                boardPluginAlert = BoardPluginAlert(title: "插件删除失败", message: error.localizedDescription)
            }
        }
    }

    func boardPluginOperation(for boardID: String) -> BoardPluginOperationState {
        boardPluginOperations[boardID] ?? BoardPluginOperationState()
    }

    private func applyRemoteBoardPluginEntries(_ entries: [RemoteBoardPluginEntry], checkedAt: String) {
        boardCatalog = mergedBoardCatalog(with: entries)
        remoteBoardPluginEntries = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        boardPluginCatalogVersions = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.version ?? "") })
        boardPluginCatalogCheckedAt = checkedAt
        updateBoardRoutingFromCurrentState()
    }

    private func mergedBoardCatalog(with entries: [RemoteBoardPluginEntry]) -> [SupportedBoard] {
        let builtInByID = Dictionary(uniqueKeysWithValues: SupportedBoard.catalog.map { ($0.id, $0) })
        var merged: [SupportedBoard] = []
        var seen = Set<String>()

        for entry in entries {
            let base = builtInByID[entry.id] ?? placeholderBoard(for: entry)
            merged.append(
                SupportedBoard(
                    id: base.id,
                    englishName: base.englishName,
                    displayName: entry.display_name ?? base.displayName,
                    manufacturer: entry.manufacturer ?? base.manufacturer,
                    modelDirectoryName: base.modelDirectoryName,
                    variantDisplayNames: entry.variants ?? base.variantDisplayNames,
                    shortSummary: base.shortSummary,
                    detailSummary: base.detailSummary,
                    integrationStatus: base.integrationStatus,
                    integrationReady: base.integrationReady,
                    thumbnailLabel: base.thumbnailLabel,
                    thumbnailSymbol: base.thumbnailSymbol,
                    accentStart: base.accentStart,
                    accentEnd: base.accentEnd,
                    capabilities: base.capabilities,
                    searchableTerms: base.searchableTerms
                )
            )
            seen.insert(entry.id)
        }

        for board in SupportedBoard.catalog where !seen.contains(board.id) {
            merged.append(board)
        }

        return merged
    }

    private func placeholderBoard(for entry: RemoteBoardPluginEntry) -> SupportedBoard {
        SupportedBoard(
            id: entry.id,
            englishName: entry.id,
            displayName: entry.display_name ?? entry.id,
            manufacturer: entry.manufacturer ?? "未知厂家",
            modelDirectoryName: nil,
            variantDisplayNames: entry.variants ?? [entry.display_name ?? entry.id],
            shortSummary: "该开发板插件来自远端插件目录，当前 GUI 版本尚未内置详细说明。",
            detailSummary: "该开发板插件已从远端目录发现，但当前应用版本没有内置该开发板的详细资料。后续可通过插件形式补全识别、动作和展示信息。",
            integrationStatus: "已发现远端插件目录项，等待安装。",
            integrationReady: false,
            thumbnailLabel: entry.id.uppercased(),
            thumbnailSymbol: "shippingbox.fill",
            accentStart: Color(red: 0.35, green: 0.45, blue: 0.62),
            accentEnd: Color(red: 0.22, green: 0.30, blue: 0.42),
            capabilities: [.usbProbe],
            searchableTerms: [entry.id.lowercased()]
        )
    }

    func showSupportedBoardCatalog() {
        showingSupportedBoardCatalog = true
        boardCatalogBaselineSignature = candidateSignature(for: detectedBoardCandidates)
    }

    func setPreferredControlBoard(_ boardID: String?) {
        if preferredControlBoardID == boardID {
            return
        }
        preferredControlBoardID = boardID
        if let boardID, !boardID.isEmpty {
            UserDefaults.standard.set(boardID, forKey: "preferredControlBoardID")
        } else {
            UserDefaults.standard.removeObject(forKey: "preferredControlBoardID")
        }
        refreshActionAvailability()
    }

    func showControlPage(for board: SupportedBoard) {
        connectedBoardID = board.id
        connectedBoardVariantID = nil
        connectedBoardDisplayName = board.variantDisplayNames.first ?? board.displayName
        setPreferredControlBoard(board.id)
        showingSupportedBoardCatalog = false
        boardCatalogBaselineSignature = nil
    }

    func chooseDetectedBoard(_ candidate: DetectedBoardCandidate) {
        let sameSelection =
            selectedDetectedCandidateID == candidate.id &&
            connectedBoardID == candidate.boardID &&
            connectedBoardVariantID == candidate.variantID &&
            connectedBoardDisplayName == candidate.displayName &&
            preferredControlBoardID == candidate.boardID &&
            showingSupportedBoardCatalog == false &&
            deviceSelectionPrompt == nil
        if sameSelection {
            return
        }
        selectedDetectedCandidateID = candidate.id
        connectedBoardID = candidate.boardID
        connectedBoardVariantID = candidate.variantID
        connectedBoardDisplayName = candidate.displayName
        setPreferredControlBoard(candidate.boardID)
        showingSupportedBoardCatalog = false
        boardCatalogBaselineSignature = nil
        deviceSelectionPrompt = nil
    }

    func dismissDeviceSelectionPrompt() {
        deviceSelectionPrompt = nil
    }

    private func updateBoardRoutingFromCurrentState() {
        let candidates = scanDetectedBoardCandidates()
        if detectedBoardCandidates != candidates {
            detectedBoardCandidates = candidates
        }
        refreshActionAvailability()

        let currentSignature = candidateSignature(for: candidates)
        if candidates.isEmpty {
            if deviceSelectionPrompt != nil {
                deviceSelectionPrompt = nil
            }
            return
        }

        if showingSupportedBoardCatalog,
           let baseline = boardCatalogBaselineSignature,
           baseline == currentSignature
        {
            if deviceSelectionPrompt != nil {
                deviceSelectionPrompt = nil
            }
            return
        }

        if candidates.count == 1, let first = candidates.first {
            chooseDetectedBoard(first)
            return
        }

        let semanticCandidates = Dictionary(
            grouping: candidates,
            by: { semanticCandidateSignature(for: $0) }
        )
        if semanticCandidates.count == 1, let preferred = candidates.first {
            chooseDetectedBoard(preferred)
            return
        }

        if let selectedDetectedCandidateID,
           let selected = candidates.first(where: { $0.id == selectedDetectedCandidateID })
        {
            chooseDetectedBoard(selected)
            return
        }

        let nextPrompt = DeviceSelectionPrompt(candidates: candidates)
        if deviceSelectionPrompt != nextPrompt {
            deviceSelectionPrompt = nextPrompt
        }
    }

    private func candidateSignature(for candidates: [DetectedBoardCandidate]) -> String {
        candidates
            .map(\.id)
            .sorted()
            .joined(separator: "|")
    }

    private func semanticCandidateSignature(for candidate: DetectedBoardCandidate) -> String {
        "\(candidate.boardID)::\(candidate.variantID ?? "default")"
    }

    private func scanDetectedBoardCandidates() -> [DetectedBoardCandidate] {
        var candidates: [DetectedBoardCandidate] = []

        if let device = status?.device,
           device.connected == true,
           let boardID = device.board_id,
           isBoardPluginInstalled(boardID) || supportedBoard(for: boardID) != nil
        {
            let displayName = device.display_name ?? supportedBoard(for: boardID)?.displayName ?? boardID
            let manufacturer = device.manufacturer ?? supportedBoard(for: boardID)?.manufacturer ?? "未知厂家"
            let interfaceName = device.interface_name ?? status?.usbnet?.iface ?? "设备接口"
            let transportName = device.transport_name ?? status?.usb?.mode ?? "设备连接"
            let sourceName = device.source_name ?? "状态服务"
            let variantID = device.variant_id
            candidates.append(
                DetectedBoardCandidate(
                    id: "\(boardID)-status-\(variantID ?? "default")-\(interfaceName)",
                    boardID: boardID,
                    variantID: variantID,
                    displayName: displayName,
                    manufacturer: manufacturer,
                    interfaceName: interfaceName,
                    transportName: transportName,
                    sourceName: sourceName,
                    priority: 120
                )
            )
        }

        candidates.append(contentsOf: scanUSBBoardCandidates())
        candidates.append(contentsOf: scanMountedVolumeBoardCandidates())

        if candidates.isEmpty,
           isBoardPluginInstalled("TaishanPi"),
           hasRockchipSignalFromStatus()
        {
            let interfaceName = status?.usbnet?.iface.map { "USB ECM / \($0)" } ?? "USB 接口"
            candidates.append(
                DetectedBoardCandidate(
                    id: "TaishanPi-service-fallback",
                    boardID: "TaishanPi",
                    variantID: "1M-RK3566",
                    displayName: "泰山派（1M-RK3566）",
                    manufacturer: "嘉立创",
                    interfaceName: interfaceName,
                    transportName: deviceConnectionText,
                    sourceName: "状态服务",
                    priority: 90
                )
            )
        }

        var deduped: [String: DetectedBoardCandidate] = [:]
        for candidate in candidates.sorted(by: { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id < rhs.id
            }
            return lhs.priority > rhs.priority
        }) {
            if deduped[candidate.id] == nil {
                deduped[candidate.id] = candidate
            }
        }
        return deduped.values.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.priority > rhs.priority
        }
    }

    private func hasRockchipSignalFromStatus() -> Bool {
        let usbMode = (status?.usb?.mode ?? "absent").lowercased()
        let usbProduct = (status?.usb?.product ?? "").lowercased()
        return usbMode != "absent" ||
            usbProduct.contains("rockchip") ||
            usbProduct.contains("download gadget") ||
            usbProduct.contains("usb ecm") ||
            status?.usbnet?.configured == true ||
            status?.board?.ping == true ||
            status?.board?.ssh_port_open == true ||
            status?.board?.control_service == true
    }

    private func scanUSBBoardCandidates() -> [DetectedBoardCandidate] {
        guard let matching = IOServiceMatching("IOUSBHostDevice") else {
            return []
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        let rockchipVendorID: UInt16 = 0x2207
        let loaderPID: UInt16 = 0x350a
        let usbECMPID: UInt16 = 0x3606

        var candidates: [DetectedBoardCandidate] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == IO_OBJECT_NULL {
                break
            }
            defer { IOObjectRelease(service) }

            let vendorID = registryUInt16(service: service, keys: ["idVendor", "kUSBVendorID"]) ?? 0
            let productID = registryUInt16(service: service, keys: ["idProduct", "kUSBProductID"]) ?? 0
            let product = registryString(service: service, keys: ["USB Product Name", "product", "kUSBProductString"]) ?? "USB Device"
            let serial = registryString(service: service, keys: ["USB Serial Number", "serial", "kUSBSerialNumberString"]) ?? ""
            let locationID = registryUInt32(service: service, keys: ["locationID", "kUSBDevicePropertyLocationID"]) ?? 0
            let productLower = product.lowercased()

            if isBoardPluginInstalled("TaishanPi"),
               vendorID == rockchipVendorID ||
               productLower.contains("rockchip") ||
               productLower.contains("download gadget") ||
               productLower.contains("usb ecm")
            {
                let transport: String
                if productID == loaderPID || productLower.contains("download gadget") {
                    transport = "Loader USB"
                } else if productID == usbECMPID || productLower.contains("usb ecm") {
                    transport = "USB ECM"
                } else {
                    transport = "USB"
                }
                candidates.append(
                    DetectedBoardCandidate(
                        id: "TaishanPi-usb-\(locationID)-\(serial)",
                        boardID: "TaishanPi",
                        variantID: "1M-RK3566",
                        displayName: "泰山派（1M-RK3566）",
                        manufacturer: "嘉立创",
                        interfaceName: "USB@0x\(String(format: "%08x", locationID))",
                        transportName: transport,
                        sourceName: product,
                        priority: 100
                    )
                )
            }

            if isBoardPluginInstalled("ColorEasyPICO2"),
               productLower.contains("coloreasy") ||
               productLower.contains("pico") ||
               productLower.contains("rp2350")
            {
                candidates.append(
                    DetectedBoardCandidate(
                        id: "ColorEasyPICO2-usb-\(locationID)-\(serial)",
                        boardID: "ColorEasyPICO2",
                        variantID: "ColorEasyPICO2",
                        displayName: "ColorEasyPICO2",
                        manufacturer: "嘉立创",
                        interfaceName: "USB@0x\(String(format: "%08x", locationID))",
                        transportName: "USB",
                        sourceName: product,
                        priority: 80
                    )
                )
            }
        }
        return candidates
    }

    private func scanMountedVolumeBoardCandidates() -> [DetectedBoardCandidate] {
        guard isBoardPluginInstalled("ColorEasyPICO2") else {
            return []
        }
        let keys: [URLResourceKey] = [.volumeNameKey, .nameKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            let resourceValues = try? url.resourceValues(forKeys: Set(keys))
            let volumeName = resourceValues?.volumeName ?? resourceValues?.name ?? url.lastPathComponent
            let lower = volumeName.lowercased()
            guard lower.contains("rpi-rp2") || lower.contains("pico") || lower.contains("coloreasy") else {
                return nil
            }
            return DetectedBoardCandidate(
                id: "ColorEasyPICO2-volume-\(volumeName)",
                boardID: "ColorEasyPICO2",
                variantID: "ColorEasyPICO2",
                displayName: "ColorEasyPICO2",
                manufacturer: "嘉立创",
                interfaceName: volumeName,
                transportName: "UF2 存储盘",
                sourceName: url.path,
                priority: 70
            )
        }
    }

    private func registryUInt16(service: io_registry_entry_t, keys: [String]) -> UInt16? {
        for key in keys {
            guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
                continue
            }
            if let number = value as? NSNumber {
                return UInt16(truncating: number)
            }
            if let data = value as? Data {
                let bytes = [UInt8](data.prefix(2))
                if bytes.count == 2 {
                    return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
                }
            }
        }
        return nil
    }

    private func registryUInt32(service: io_registry_entry_t, keys: [String]) -> UInt32? {
        for key in keys {
            guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
                continue
            }
            if let number = value as? NSNumber {
                return UInt32(truncating: number)
            }
        }
        return nil
    }

    private func registryString(service: io_registry_entry_t, keys: [String]) -> String? {
        for key in keys {
            guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
                continue
            }
            if let string = value as? String, !string.isEmpty {
                return string
            }
        }
        return nil
    }

    private func parseRemoteBoardPluginEntries(data: Data) throws -> [RemoteBoardPluginEntry] {
        if let decoded = try? JSONDecoder().decode(RemoteBoardPluginIndex.self, from: data) {
            return decoded.boards
        }

        let text = String(decoding: data, as: UTF8.self)
        let parsed = parseTreeStyleBoardPluginEntries(text: text)
        if !parsed.isEmpty {
            return parsed
        }
        throw ToolkitGUIError.invalidJSON(text)
    }

    private func parseTreeStyleBoardPluginEntries(text: String) -> [RemoteBoardPluginEntry] {
        var entries: [String: RemoteBoardPluginEntry] = [:]
        var currentBoardID: String?

        for rawLine in text.components(separatedBy: .newlines) {
            if rawLine.hasPrefix("    "), !rawLine.hasPrefix("        ") {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if trimmed.hasSuffix("/"), trimmed != "boards/" {
                    currentBoardID = String(trimmed.dropLast())
                    entries[currentBoardID!] = RemoteBoardPluginEntry(
                        id: currentBoardID!,
                        version: entries[currentBoardID!]?.version,
                        display_name: nil,
                        manufacturer: nil,
                        variants: nil,
                        download_url: nil,
                        checksum_url: nil
                    )
                }
                continue
            }

            guard let currentBoardID else {
                continue
            }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("/"), CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: String(trimmed.prefix(1)))) {
                let version = String(trimmed.dropLast())
                entries[currentBoardID] = RemoteBoardPluginEntry(
                    id: currentBoardID,
                    version: version,
                    display_name: nil,
                    manufacturer: nil,
                    variants: nil,
                    download_url: nil,
                    checksum_url: nil
                )
            }
        }

        return entries.values.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func derivedBoardPluginDownloadURL(boardID: String, version: String) -> URL {
        if let value = remoteBoardPluginEntry(boardID)?.download_url,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        return URL(string: "https://gitee.com/kvell/development-board-toolchain/raw/master/plugins/boards/\(boardID)/releases/\(version)/plugin.zip")!
    }

    private func derivedBoardPluginChecksumURL(boardID: String, version: String) -> URL {
        if let value = remoteBoardPluginEntry(boardID)?.checksum_url,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        return URL(string: "https://gitee.com/kvell/development-board-toolchain/raw/master/plugins/boards/\(boardID)/releases/\(version)/plugin.zip.sha256")!
    }

    private func downloadBoardPluginArchive(from remoteURL: URL, to localURL: URL, boardID: String) async throws {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 600
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ToolkitGUIError.commandFailed("插件下载失败：无法获取安装包")
        }

        let expectedBytes = max(response.expectedContentLength, 0)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }
        FileManager.default.createFile(atPath: localURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: localURL)
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(contentsOf: [byte])
            received += 1
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
            let progress = expectedBytes > 0 ? min(Double(received) / Double(expectedBytes), 0.68) : nil
            await MainActor.run {
                boardPluginOperations[boardID] = BoardPluginOperationState(
                    kind: .installing,
                    progress: progress,
                    message: "下载中 \(ByteCountFormatter.string(fromByteCount: received, countStyle: .file))"
                )
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
    }

    private func fetchBoardPluginChecksum(from remoteURL: URL) async throws -> String {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ToolkitGUIError.commandFailed("插件校验失败：无法获取 SHA256 文件")
        }
        let raw = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = raw.split(whereSeparator: \.isWhitespace).first, !token.isEmpty else {
            throw ToolkitGUIError.commandFailed("插件校验失败：SHA256 文件为空")
        }
        return String(token)
    }

    private func sha256Hex(for fileURL: URL) throws -> String {
        let result = try ProcessExecutor.runSync(
            executableURL: URL(fileURLWithPath: "/usr/bin/shasum"),
            arguments: ["-a", "256", fileURL.path],
            currentDirectoryURL: boardPluginsRootURL(),
            environment: ProcessInfo.processInfo.environment
        )
        guard result.0 == 0 else {
            throw ToolkitGUIError.commandFailed(result.1)
        }
        guard let token = result.1.split(whereSeparator: \.isWhitespace).first else {
            throw ToolkitGUIError.commandFailed("无法计算插件 SHA256")
        }
        return String(token)
    }

    private func unzipBoardPluginArchive(zipURL: URL, destinationURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let result = try ProcessExecutor.runSync(
            executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", zipURL.path, destinationURL.path],
            currentDirectoryURL: destinationURL.deletingLastPathComponent(),
            environment: ProcessInfo.processInfo.environment
        )
        guard result.0 == 0 else {
            throw ToolkitGUIError.commandFailed(result.1.isEmpty ? "插件解压失败" : result.1)
        }
    }

    private func validateInstalledBoardPlugin(at installRoot: URL, expectedBoardID: String, expectedVersion: String, pluginSource: String = "user") throws -> InstalledBoardPluginMetadata {
        let manifestURL = try findBoardPluginFile(named: "manifest.json", under: installRoot)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(BoardPluginManifest.self, from: manifestData)
        guard manifest.id == expectedBoardID else {
            throw ToolkitGUIError.commandFailed("插件校验失败：manifest.id 与目标插件不一致")
        }
        guard manifest.version == expectedVersion else {
            throw ToolkitGUIError.commandFailed("插件校验失败：manifest.version 与目录版本不一致")
        }

        let pluginRoot = manifestURL.deletingLastPathComponent()
        let profileURL = try resolveBoardPluginProfileURL(pluginRoot: pluginRoot, manifest: manifest)
        let profileData = try Data(contentsOf: profileURL)
        let profile = try JSONDecoder().decode(BoardPluginProfile.self, from: profileData)
        let toolingURL = resolveBoardPluginToolingURL(pluginRoot: pluginRoot, manifest: manifest, profile: profile)
        let tooling: BoardPluginToolingConfig?
        if let toolingURL {
            let toolingData = try Data(contentsOf: toolingURL)
            tooling = try JSONDecoder().decode(BoardPluginToolingConfig.self, from: toolingData)
            if let toolingBoardID = tooling?.board_id, !toolingBoardID.isEmpty, toolingBoardID != expectedBoardID {
                throw ToolkitGUIError.commandFailed("插件校验失败：tooling.board_id 与目标插件不一致")
            }
        } else {
            tooling = nil
        }

        if let profileBoardID = profile.board_id, !profileBoardID.isEmpty, profileBoardID != expectedBoardID {
            throw ToolkitGUIError.commandFailed("插件校验失败：profile.board_id 与目标插件不一致")
        }

        let capabilityNames = (manifest.capabilities ?? profile.capabilities ?? [])
        let capabilities = capabilityNames.compactMap(BoardCapability.init(rawValue:))
        guard !capabilities.isEmpty else {
            throw ToolkitGUIError.commandFailed("插件校验失败：未声明有效能力模块")
        }

        let variants = (manifest.variants ?? profile.variants ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !variants.isEmpty else {
            throw ToolkitGUIError.commandFailed("插件校验失败：未声明任何板型变体")
        }

        let displayName = manifest.display_name ?? profile.display_name ?? expectedBoardID
        let manufacturer = manifest.manufacturer ?? profile.manufacturer ?? "未知厂家"
        let metadata = InstalledBoardPluginMetadata(
            id: expectedBoardID,
            version: expectedVersion,
            display_name: displayName,
            manufacturer: manufacturer,
            variants: variants,
            capabilities: capabilities.map(\.rawValue),
            manifest_path: manifestURL.path,
            profile_path: profileURL.path,
            tooling_config_path: toolingURL?.path,
            require_explicit_variant_confirmation: tooling?.require_explicit_variant_confirmation == true,
            development_environment_enabled: tooling?.development_environment?.enabled == true,
            tooling_variants: tooling?.variants ?? [],
            installed_at: ISO8601DateFormatter().string(from: Date()),
            plugin_source: pluginSource
        )

        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: installRoot.appendingPathComponent("installed-metadata.json"), options: .atomic)
        return metadata
    }

    private func resolveBoardPluginProfileURL(pluginRoot: URL, manifest: BoardPluginManifest) throws -> URL {
        if let relative = manifest.profile_path?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relative.isEmpty {
            let candidate = pluginRoot.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            throw ToolkitGUIError.commandFailed("插件校验失败：未找到 \(relative)")
        }
        return try findBoardPluginFile(named: "profile.json", under: pluginRoot)
    }

    private func resolveBoardPluginToolingURL(pluginRoot: URL, manifest: BoardPluginManifest, profile: BoardPluginProfile) -> URL? {
        let relative = manifest.tooling_config_path?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? profile.tooling_config_path?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let relative, !relative.isEmpty {
            let candidate = pluginRoot.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        let fallback = pluginRoot.appendingPathComponent("tooling.json")
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }

        let repoCandidate = URL(fileURLWithPath: repoRoot)
            .appendingPathComponent("product_release/board_plugins/boards", isDirectory: true)
            .appendingPathComponent(manifest.id, isDirectory: true)
            .appendingPathComponent(relative ?? "tooling.json")
        if FileManager.default.fileExists(atPath: repoCandidate.path) {
            return repoCandidate
        }
        let repoFallback = URL(fileURLWithPath: repoRoot)
            .appendingPathComponent("product_release/board_plugins/boards", isDirectory: true)
            .appendingPathComponent(manifest.id, isDirectory: true)
            .appendingPathComponent("tooling.json")
        return FileManager.default.fileExists(atPath: repoFallback.path) ? repoFallback : nil
    }

    private func findBoardPluginFile(named fileName: String, under root: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: root.appendingPathComponent(fileName).path) {
            return root.appendingPathComponent(fileName)
        }

        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw ToolkitGUIError.commandFailed("插件校验失败：无法扫描插件目录")
        }

        for case let url as URL in enumerator {
            if url.lastPathComponent == fileName {
                return url
            }
        }
        throw ToolkitGUIError.commandFailed("插件校验失败：未找到 \(fileName)")
    }

    func runPlainAction(_ arguments: [String], environmentOverrides: [String: String] = [:]) async throws -> String {
        let (code, output) = try await runCLI(arguments, environmentOverrides: environmentOverrides)
        guard code == 0 else {
            throw ToolkitGUIError.commandFailed(output)
        }
        return output
    }

    func runWithTimeout<T>(
        seconds: Double,
        failureMessage: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { @MainActor in
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ToolkitGUIError.timeout(failureMessage)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func placeholderStatus() -> ToolkitStatus {
        ToolkitStatus(
            repo_root: repoRoot.isEmpty ? nil : repoRoot,
            service: status?.service,
            updated_at: ISO8601DateFormatter().string(from: Date()),
            usb: status?.usb ?? .init(mode: "absent", product: nil, pid: nil),
            usbnet: status?.usbnet ?? .init(iface: nil, current_ip: nil, expected_ip: "198.19.77.2", board_ip: "198.19.77.1", configured: false),
            board: status?.board ?? .init(ping: false, ssh_port_open: false, control_service: false),
            host: status?.host,
            device: status?.device,
            summary: status?.summary,
            device_summary: status?.device_summary
        )
    }

    func mergedStatus(
        usb: ToolkitStatus.USB? = nil,
        usbnet: ToolkitStatus.USBNet? = nil,
        board: ToolkitStatus.Board? = nil,
        host: ToolkitStatus.Host? = nil,
        device: ToolkitStatus.Device? = nil,
        summary: String? = nil,
        deviceSummary: String? = nil,
        updatedAt: String? = nil
    ) -> ToolkitStatus {
        let current = status ?? placeholderStatus()
        return ToolkitStatus(
            repo_root: current.repo_root ?? repoRoot,
            service: current.service,
            updated_at: updatedAt ?? ISO8601DateFormatter().string(from: Date()),
            usb: usb ?? current.usb,
            usbnet: usbnet ?? current.usbnet,
            board: board ?? current.board,
            host: host ?? current.host,
            device: device ?? current.device,
            summary: summary ?? current.summary,
            device_summary: deviceSummary ?? current.device_summary
        )
    }

    func imageDirURL(for source: FlashImageSource) -> URL {
        switch source {
        case .custom:
            return customImageDirURL()
        case .factory:
            return factoryImageDirURL()
        }
    }

    func resolvedImagePath(for target: String, source: FlashImageSource = .custom) -> URL? {
        let imageDir = imageDirURL(for: source)
        switch target {
        case "rootfs":
            let img = imageDir.appendingPathComponent("rootfs.img")
            if FileManager.default.fileExists(atPath: img.path) {
                return img
            }
            let ext4 = imageDir.appendingPathComponent("rootfs.ext4")
            if FileManager.default.fileExists(atPath: ext4.path) {
                return ext4
            }
            return nil
        case "all":
            return nil
        default:
            let image = imageDir.appendingPathComponent("\(target).img")
            return FileManager.default.fileExists(atPath: image.path) ? image : nil
        }
    }

    func hasAnyFlashableImage(source: FlashImageSource = .custom) -> Bool {
        let imageDir = imageDirURL(for: source)
        let candidates = [
            "boot.img",
            "rootfs.img",
            "rootfs.ext4",
            "userdata.img",
            "oem.img",
            "recovery.img",
            "uboot.img",
            "update.img",
        ]
        return candidates.contains { FileManager.default.fileExists(atPath: imageDir.appendingPathComponent($0).path) }
    }

    func ensureFactoryImagesReady() async throws {
        let required = [
            factoryImageDirURL().appendingPathComponent("parameter.txt").path,
            factoryImageDirURL().appendingPathComponent("boot.img").path,
            factoryImageDirURL().appendingPathComponent("userdata.img").path,
        ]
        if required.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) {
            return
        }
        _ = try await runLocalAgentRuntimeJobAndWait(
            actionID: "images-ensure-factory",
            title: "同步工厂镜像",
            arguments: ["images", "ensure-factory", "--json"],
            timeout: 30
        )
    }

    func refreshDevelopmentInstallStatus() async {
        do {
            let agentStatus = try await fetchLocalAgentStatusSummary()
            let host = agentStatus.runtime_status?.host
            var next = DevelopmentInstallStatus()
            next.dockerReady = host?.docker_daemon == true
            next.officialImageReady = host?.official_image == true
            next.rkflashtoolReady = host?.rkflashtool_built == true
            next.updatedAt = agentStatus.updated_at ?? ISO8601DateFormatter().string(from: Date())

            let imageDir = factoryImageDirURL()
            let requiredHostImages = [
                imageDir.appendingPathComponent("parameter.txt").path,
                imageDir.appendingPathComponent("boot.img").path,
                imageDir.appendingPathComponent("userdata.img").path,
            ]
            next.hostImagesReady = requiredHostImages.allSatisfy { FileManager.default.fileExists(atPath: $0) }

            if next.dockerReady {
                let volumeCheck = try await runShell("docker volume inspect '\(officialVolumeName)' >/dev/null 2>&1")
                next.releaseVolumeReady = volumeCheck.0 == 0
            }

            let home = NSHomeDirectory()
            let codexCandidates = [
                "\(home)/.codex/.tmp/plugins/plugins/development-board-toolchain/.codex-plugin/plugin.json",
                "\(home)/plugins/development-board-toolchain/.codex-plugin/plugin.json",
                "\(home)/.codex/.tmp/plugins/plugins/rk356x-mac-toolkit/.codex-plugin/plugin.json",
                "\(home)/plugins/rk356x-mac-toolkit/.codex-plugin/plugin.json"
            ]
            next.codexAvailable = FileManager.default.fileExists(atPath: "\(home)/.codex")
            next.codexPluginInstalled = codexCandidates.contains { FileManager.default.fileExists(atPath: $0) }

            let opencodeCandidates = [
                "\(home)/.config/opencode/plugins/development-board-toolchain/index.js",
                "\(home)/.config/opencode/plugins/development-board-toolchain/development-board-toolchain.runtime.json"
            ]
            let legacyOpenCodeCandidates = [
                "\(home)/.config/opencode/plugins/rk356x-toolkit.js",
                "\(home)/.config/opencode/plugins/rk356x-toolkit.runtime.json"
            ]
            let npmCheck = try await runShell("command -v npm >/dev/null 2>&1")
            next.npmReady = npmCheck.0 == 0
            let opencodeCheck = try await runShell("command -v opencode >/dev/null 2>&1")
            next.openCodeAvailable = opencodeCheck.0 == 0 || FileManager.default.fileExists(atPath: "\(home)/.config/opencode")
            next.openCodePluginInstalled =
                opencodeCandidates.allSatisfy { FileManager.default.fileExists(atPath: $0) } ||
                legacyOpenCodeCandidates.allSatisfy { FileManager.default.fileExists(atPath: $0) }

            developmentInstallStatus = next
        } catch {
            installerLastDetail = "环境状态刷新失败：\(error.localizedDescription)"
        }
    }

    func currentToolkitVersion() -> String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let versionURL = URL(fileURLWithPath: repoRoot).appendingPathComponent("VERSION")
        if let version = try? String(contentsOf: versionURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty
        {
            return version
        }
        return "unknown"
    }

    func refreshToolkitUpdateStatus() {
        var next = toolkitUpdateStatus
        next.currentVersion = currentToolkitVersion()
        let distributionURL = URL(fileURLWithPath: repoRoot).appendingPathComponent("product_release/release-installer/distribution.env")
        if let text = try? String(contentsOf: distributionURL, encoding: .utf8) {
            let lines = text
                .split(separator: "\n")
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            next.configured = lines.contains { line in
                (line.hasPrefix("RK356X_REMOTE_TOOLKIT_MANIFEST_URL=") ||
                 line.hasPrefix("RK356X_REMOTE_BASE_URL=") ||
                 line.hasPrefix("RK356X_REMOTE_UPDATE_MANIFEST_URL=") ||
                 line.hasPrefix("RK356X_REMOTE_TOOLKIT_BUNDLE_URL=")) &&
                    !line.hasSuffix("\"\"")
            }
        } else {
            next.configured = false
        }
        if !next.configured {
            next.remoteVersion = ""
            next.updateAvailable = false
        }
        toolkitUpdateStatus = next
    }

    func parseUpdateStatus(detail: String) {
        var next = toolkitUpdateStatus
        next.currentVersion = currentToolkitVersion()
        next.configured = !detail.contains("not configured") && !detail.contains("Toolkit bundle URL is not configured")
        for raw in detail.split(separator: "\n").map(String.init) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("local version:") {
                next.currentVersion = line.components(separatedBy: "local version:").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? next.currentVersion
            } else if line.contains("remote version:") {
                next.remoteVersion = line.components(separatedBy: "remote version:").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } else if line.contains("update available") {
                next.updateAvailable = true
            } else if line.contains("already up to date") {
                next.updateAvailable = false
            }
        }
        next.checkedAt = ISO8601DateFormatter().string(from: Date())
        toolkitUpdateStatus = next
    }

    func validatePrecondition(_ precondition: ActionPrecondition) async -> String? {
        let route = currentOperationRoute()
        switch precondition {
        case .checkHost:
            refreshStatus(silent: true)
            return nil

        case .ensureUSBNet:
            refreshStatus(silent: true)
            guard status?.usb?.mode == "usb-ecm" else {
                return "当前未检测到 USB ECM 连接，无法恢复主机静态地址。"
            }
            return nil

        case .authorizeKey, .rebootLoader:
            return await boardOperationPreflightMessage(operationID: "usb_control", boardID: route.boardID, variantID: route.variantID)

        case .rebootDevice:
            return await boardOperationPreflightMessage(operationID: "usb_or_ssh", boardID: route.boardID, variantID: route.variantID)

        case .flash:
            return await boardOperationPreflightMessage(operationID: "flash_transport", boardID: route.boardID, variantID: route.variantID)

        case .buildSync:
            refreshStatus(silent: true)
            guard status?.host?.docker_daemon == true else {
                return "Docker 未就绪，无法执行构建同步。"
            }
            return nil

        case .buildSyncFlash:
            refreshStatus(silent: true)
            guard status?.host?.docker_daemon == true else {
                return "Docker 未就绪，无法执行构建同步刷写。"
            }
            return await boardOperationPreflightMessage(operationID: "flash_transport", boardID: route.boardID, variantID: route.variantID)

        case let .updateLogo(flashAfter):
            refreshStatus(silent: true)
            guard status?.host?.docker_daemon == true else {
                return "Docker 未就绪，无法更新启动 Logo。"
            }
            guard !logoPath.isEmpty, FileManager.default.fileExists(atPath: logoPath) else {
                return "请选择存在的启动 Logo 文件。"
            }
            guard let scale = Int(logoScale), (1...100).contains(scale) else {
                return "Logo 显示比例必须是 1 到 100 之间的整数。"
            }
            if flashAfter {
                return await validatePrecondition(.flash("boot"))
            }
            return nil

        case let .updateDTB(flashAfter):
            refreshStatus(silent: true)
            guard status?.host?.docker_daemon == true else {
                return "Docker 未就绪，无法更新设备树。"
            }
            guard !dtsFilePath.isEmpty, FileManager.default.fileExists(atPath: dtsFilePath) else {
                return "请选择存在的设备树文件。"
            }
            if flashAfter {
                return await validatePrecondition(.flash("boot"))
            }
            return nil
        }
    }

    func refreshServiceState() async {
        localAgentRunning = (try? await fetchLocalAgentHealthz()) != nil
        eventStreamConnected = false
    }

    func refreshTransportStatus(silent: Bool = true) async {
        do {
            let agentStatus = try await fetchLocalAgentStatusSummary()
            let runtimeStatus = agentStatus.runtime_status
            let nextUSB = runtimeStatus?.usb ?? ToolkitStatus.USB(mode: "absent", product: nil, pid: nil)
            let nextUSBNet = runtimeStatus?.usbnet ?? ToolkitStatus.USBNet(iface: nil, current_ip: nil, expected_ip: "198.19.77.2", board_ip: "198.19.77.1", configured: false)
            let connected = nextUSB.mode == "usb-ecm" && nextUSBNet.configured == true
            let nextBoard = connected ? runtimeStatus?.board : ToolkitStatus.Board(ping: false, ssh_port_open: false, control_service: false)
            let merged = mergedStatus(usb: nextUSB, usbnet: nextUSBNet, board: nextBoard, updatedAt: agentStatus.updated_at)
            applyStatusUpdate(merged, silent: silent)
            if connected {
                resetAutomaticUSBNetRepairState()
                if usesEventDrivenStatus {
                    stopBoardMonitoring()
                } else {
                    ensureBoardMonitoring(forceImmediate: true)
                }
            } else {
                stopBoardMonitoring()
                scheduleAutomaticUSBNetRepairIfNeeded(trigger: "transport")
            }
        } catch {
            if !silent {
                presentInlineError("刷新连接状态失败: \(error.localizedDescription)")
            }
        }
    }

    func refreshBoardStatus(silent: Bool = true) async {
        guard status?.usb?.mode == "usb-ecm", status?.usbnet?.configured == true else {
            resetBoardFailureCounters()
            let merged = mergedStatus(board: .init(ping: false, ssh_port_open: false, control_service: false))
            applyStatusUpdate(merged, silent: true)
            return
        }
        do {
            let agentStatus = try await fetchLocalAgentStatusSummary()
            let stableBoard = stabilizedBoardStatus(agentStatus.runtime_status?.board)
            let merged = mergedStatus(board: stableBoard, updatedAt: agentStatus.updated_at)
            applyStatusUpdate(merged, silent: silent)
        } catch {
            if !silent {
                presentInlineError("刷新板卡状态失败: \(error.localizedDescription)")
            }
        }
    }

    func refreshHostStatus(silent: Bool = true) async {
        do {
            let agentStatus = try await fetchLocalAgentStatusSummary()
            let merged = mergedStatus(host: agentStatus.runtime_status?.host, updatedAt: agentStatus.updated_at)
            applyStatusUpdate(merged, silent: silent)
            scheduleAutomaticUSBNetRepairIfNeeded(trigger: "host")
        } catch {
            if !silent {
                presentInlineError("刷新主机状态失败: \(error.localizedDescription)")
            }
        }
    }

    private func automaticUSBNetRepairSignature(for status: ToolkitStatus) -> String {
        let usbMode = status.usb?.mode ?? ""
        let usbProduct = status.usb?.product ?? ""
        let usbPID = status.usb?.pid ?? ""
        let usbIface = status.usbnet?.iface ?? ""
        let currentIP = status.usbnet?.current_ip ?? ""
        let expectedIP = status.usbnet?.expected_ip ?? ""
        let helperInstalled = status.host?.usbnet_helper_installed == true ? "1" : "0"
        return [usbMode, usbProduct, usbPID, usbIface, currentIP, expectedIP, helperInstalled].joined(separator: "|")
    }

    private func resetAutomaticUSBNetRepairState(cancelTask: Bool = false) {
        if cancelTask {
            automaticUSBNetRepairTask?.cancel()
            automaticUSBNetRepairTask = nil
        }
        lastAutomaticUSBNetRepairAt = nil
        lastAutomaticUSBNetRepairSignature = ""
    }

    private func scheduleAutomaticUSBNetRepairIfNeeded(trigger: String) {
        guard let current = status else {
            resetAutomaticUSBNetRepairState(cancelTask: trigger == "disconnected")
            return
        }
        guard current.usb?.mode == "usb-ecm" else {
            resetAutomaticUSBNetRepairState(cancelTask: true)
            return
        }
        guard current.usbnet?.configured != true else {
            resetAutomaticUSBNetRepairState()
            return
        }
        guard current.host?.usbnet_helper_installed != false else {
            return
        }
        guard !isFlashTaskRunning, pendingTaskTitle.isEmpty, currentTask == nil else {
            return
        }
        guard automaticUSBNetRepairTask == nil else {
            return
        }

        let signature = automaticUSBNetRepairSignature(for: current)
        let now = Date()
        if signature == lastAutomaticUSBNetRepairSignature,
           let lastAutomaticUSBNetRepairAt,
           now.timeIntervalSince(lastAutomaticUSBNetRepairAt) < 6
        {
            return
        }

        lastAutomaticUSBNetRepairSignature = signature
        lastAutomaticUSBNetRepairAt = now
        appendActivity(level: .info, title: "USB 网络", message: "检测到 USB ECM，正在自动恢复主机网络")

        automaticUSBNetRepairTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.automaticUSBNetRepairTask = nil
            }

            do {
                let detail: String
                let task = try await self.runLocalAgentRuntimeJobAndWait(
                    actionID: "usbnet-ensure",
                    title: "USB 网络自动恢复",
                    arguments: ["usbnet", "ensure"],
                    timeout: 18
                )
                detail = task.output_tail ?? task.log_path ?? ""

                await self.refreshTransportStatus(silent: true)
                guard !Task.isCancelled else {
                    return
                }
                if self.status?.usb?.mode == "usb-ecm", self.status?.usbnet?.configured == true {
                    self.appendActivity(level: .success, title: "USB 网络", message: "已自动恢复", detail: detail)
                    await self.refreshBoardStatus(silent: true)
                } else {
                    self.appendActivity(level: .warning, title: "USB 网络", message: "自动恢复未完成，可手动重试", detail: detail)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self.appendActivity(level: .warning, title: "USB 网络", message: "自动恢复失败，可手动点击恢复", detail: error.localizedDescription)
            }
        }
    }

    func startTransportMonitor() {
        transportMonitorTask?.cancel()
        transportMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isFlashTaskRunning, !self.usesEventDrivenStatus {
                    await self.refreshTransportStatus(silent: true)
                }
                try? await Task.sleep(for: self.usesEventDrivenStatus ? .seconds(18) : .seconds(3))
            }
        }
    }

    func ensureBoardMonitoring(forceImmediate: Bool = false) {
        if forceImmediate {
            Task { [weak self] in
                await self?.refreshBoardStatus(silent: true)
            }
        }
        guard boardMonitorTask == nil || boardMonitorTask?.isCancelled == true else {
            return
        }
        boardMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if self.usesEventDrivenStatus {
                    self.boardMonitorTask = nil
                    return
                }
                guard self.status?.usb?.mode == "usb-ecm", self.status?.usbnet?.configured == true else {
                    self.boardMonitorTask = nil
                    return
                }
                await self.refreshBoardStatus(silent: true)
                try? await Task.sleep(for: .seconds(3))
            }
            self.boardMonitorTask = nil
        }
    }

    func stopBoardMonitoring() {
        boardMonitorTask?.cancel()
        boardMonitorTask = nil
    }

    func startHostMonitor() {
        hostMonitorTask?.cancel()
        hostMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isFlashTaskRunning, !self.usesEventDrivenStatus {
                    await self.refreshHostStatus(silent: true)
                }
                try? await Task.sleep(for: self.usesEventDrivenStatus ? .seconds(30) : .seconds(15))
            }
        }
    }

    func startServiceMonitor() {
        serviceMonitorTask?.cancel()
        serviceMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshServiceState()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func appendActivity(level: ActivityLevel, title: String, message: String, detail: String? = nil) {
        let entry = ActivityEntry(level: level, title: title, message: message, detail: detail)
        activities.insert(entry, at: 0)
        if activities.count > 50 {
            activities.removeLast(activities.count - 50)
        }
        lastActionSummary = "\(title): \(message)"
    }

    func presentInlineError(_ message: String) {
        lastError = message
        inlineErrorMessage = message
        footerFlashOn = true
        inlineErrorDismissTask?.cancel()
        inlineErrorFlashTask?.cancel()
        inlineErrorFlashTask = Task { [weak self] in
            guard let self else { return }
            for index in 0..<4 {
                guard !Task.isCancelled, self.inlineErrorMessage == message else { return }
                self.footerFlashOn = index % 2 == 0
                try? await Task.sleep(for: .milliseconds(220))
            }
            if !Task.isCancelled, self.inlineErrorMessage == message {
                self.footerFlashOn = false
            }
        }
        inlineErrorDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, self.inlineErrorMessage == message else {
                return
            }
            self.clearInlineError()
        }
    }

    func clearInlineError() {
        inlineErrorDismissTask?.cancel()
        inlineErrorFlashTask?.cancel()
        inlineErrorMessage = ""
        lastError = ""
        footerFlashOn = false
    }

    func dismissCurrentTaskOverlay() {
        if postFlashRecoveryActive, postFlashRecoveryFinished {
            clearPostFlashRecovery()
        }
        if currentTask?.status == "finished" {
            if let taskID = currentTask?.id {
                dismissedFinishedTaskIDs.insert(taskID)
            }
            currentTask = nil
        }
        pendingTaskTitle = ""
    }

    var isFlashTaskRunning: Bool {
        if postFlashRecoveryActive && !postFlashRecoveryFinished {
            return true
        }
        if pendingTaskTitle.contains("刷写") {
            return true
        }
        guard let task = currentTask else {
            return false
        }
        guard task.status != "finished" else {
            return false
        }
        let flashLikeActions = Set([
            "flash",
            "dev-build-sync-flash",
            "release-update-logo-flash",
            "release-update-dtb-flash"
        ])
        return flashLikeActions.contains(task.action ?? "")
    }

    func pollTask(_ taskID: String) {
        taskPollTask?.cancel()
        taskPollTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard taskID.hasPrefix("agent_job_") else {
                presentInlineError("旧任务轮询接口已弃用，请重新执行当前操作。")
                return
            }
            while !Task.isCancelled {
                do {
                    let task = try await fetchLocalAgentTask(taskID)
                    handleTaskUpdate(task)
                    if task.status == "finished" {
                        return
                    }
                } catch {
                    presentInlineError(error.localizedDescription)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func sendUserNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func handleTaskUpdate(_ task: ToolkitTask) {
        if task.status == "finished", let taskID = task.id, dismissedFinishedTaskIDs.contains(taskID) {
            return
        }
        currentTask = task
        if isInstallerTask(task), let output = task.output_tail, !output.isEmpty {
            installerLastDetail = output
        } else if isInstallerTask(task), task.status != "finished" {
            installerLastDetail = taskProgressLine(for: task)
        }
        if isUpdaterTask(task), let output = task.output_tail, !output.isEmpty {
            updaterLastDetail = output
        } else if isUpdaterTask(task), task.status != "finished" {
            updaterLastDetail = taskProgressLine(for: task)
        }
        guard task.status == "finished" else {
            return
        }
        taskPollTask?.cancel()
        pendingTaskTitle = ""
        if task.ok == true {
            if isInstallerTask(task) {
                switch task.action {
                case "release-build-image":
                    installerLastDetail = "官方镜像安装完成"
                case "release-check-env":
                    installerLastDetail = "发布环境检查完成"
                default:
                    installerLastDetail = "发布环境安装任务已完成"
                }
            }
            if isUpdaterTask(task) {
                if task.action == "release-update-images" {
                    updaterLastDetail = "初始镜像更新完成，可直接用于恢复刷写。"
                } else {
                    updaterLastDetail = shouldRelaunchAfterToolkitUpdate ? "更新完成，正在重启应用..." : "更新完成"
                    var next = toolkitUpdateStatus
                    next.updateAvailable = false
                    toolkitUpdateStatus = next
                    if shouldRelaunchAfterToolkitUpdate {
                        shouldRelaunchAfterToolkitUpdate = false
                        relaunchToolkitApplication()
                    }
                }
            }
            appendActivity(level: .success, title: task.action ?? "任务", message: "已完成", detail: task.output_tail)
            sendUserNotification(title: task.action ?? "任务", message: "已完成")
            if ["flash", "dev-build-sync-flash", "release-update-logo-flash", "release-update-dtb-flash"].contains(task.action ?? "") {
                clearPostFlashRecovery()
                startPostFlashRecovery(.flash)
            } else if task.action == "reboot-device" {
                clearPostFlashRecovery()
                startPostFlashRecovery(.reboot)
            }
            let finishedTaskID = task.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard let self else {
                    return
                }
                if self.currentTask?.id == finishedTaskID {
                    if let finishedTaskID {
                        self.dismissedFinishedTaskIDs.insert(finishedTaskID)
                    }
                    self.currentTask = nil
                }
            }
        } else {
            let detail = task.output_tail ?? "任务执行失败"
            if isInstallerTask(task) {
                installerLastDetail = detail
            }
            if isUpdaterTask(task) {
                shouldRelaunchAfterToolkitUpdate = false
                updaterLastDetail = detail
            }
            if ["flash", "dev-build-sync-flash", "release-update-logo-flash", "release-update-dtb-flash"].contains(task.action ?? "") {
                clearPostFlashRecovery()
            }
            presentInlineError(detail)
            appendActivity(level: .error, title: task.action ?? "任务", message: "执行失败", detail: detail)
            sendUserNotification(title: task.action ?? "任务", message: "执行失败")
        }
        refreshStatus(silent: true)
        Task {
            await refreshDevelopmentInstallStatus()
        }
        refreshToolkitUpdateStatus()
    }

    func clearPostFlashRecovery() {
        postFlashRecoveryTask?.cancel()
        postFlashRecoveryActive = false
        postFlashRecoveryFinished = false
        postFlashRecoverySucceeded = false
        postFlashRecoveryTitle = "设备恢复"
        postFlashRecoveryStatus = ""
        postFlashRecoveryProgress = ""
        postFlashRecoveryProgressValue = nil
        postFlashRecoveryLines = []
    }

    func updatePostFlashRecovery(
        status: String,
        progress: String,
        progressValue: Double?,
        line: String? = nil,
        finished: Bool = false,
        succeeded: Bool = false
    ) {
        postFlashRecoveryActive = true
        postFlashRecoveryStatus = status
        postFlashRecoveryProgress = progress
        postFlashRecoveryProgressValue = progressValue
        postFlashRecoveryFinished = finished
        postFlashRecoverySucceeded = succeeded
        if let line, !line.isEmpty {
            if postFlashRecoveryLines.last != line {
                postFlashRecoveryLines.append(line)
            }
            if postFlashRecoveryLines.count > 6 {
                postFlashRecoveryLines.removeFirst(postFlashRecoveryLines.count - 6)
            }
        }
    }

    func startPostFlashRecovery(_ context: DeviceRecoveryContext = .flash) {
        postFlashRecoveryTask?.cancel()
        postFlashRecoveryTitle = context.activityTitle
        appendActivity(level: .info, title: context.activityTitle, message: "等待设备重启并恢复 USB ECM 网络")
        updatePostFlashRecovery(
            status: context == .flash ? "刷写完成，等待设备重启" : "设备重启中，等待重新连接",
            progress: "正在等待设备重启并重新枚举为 USB ECM…",
            progressValue: 0.2,
            line: context.initialLine
        )
        postFlashRecoveryTask = Task { [weak self] in
            guard let self else { return }
            let rebootDeadline = Date().addingTimeInterval(45)
            while !Task.isCancelled, Date() < rebootDeadline {
                await self.refreshTransportStatus(silent: true)
                if self.status?.usb?.mode == "usb-ecm" {
                    self.updatePostFlashRecovery(
                        status: "设备已重启，正在恢复 USB 网络",
                        progress: "检测到 USB ECM，正在恢复主机地址 198.19.77.2…",
                        progressValue: 0.7,
                        line: "检测到设备已回到 USB ECM"
                    )
                    var ensureSucceeded = false
                    var lastEnsureError = ""
                    let ensureDeadline = Date().addingTimeInterval(12)
                    while !Task.isCancelled, Date() < ensureDeadline {
                        do {
                            let task = try await self.runLocalAgentRuntimeJobAndWait(
                                actionID: "usbnet-ensure",
                                title: "USB 网络恢复",
                                arguments: ["usbnet", "ensure"],
                                timeout: 10
                            )
                            let detail = task.output_tail ?? task.log_path
                            self.appendActivity(
                                level: .success,
                                title: context.activityTitle,
                                message: "主机 USB 网络已恢复",
                                detail: detail
                            )
                            self.updatePostFlashRecovery(
                                status: "设备已恢复在线",
                                progress: "主机 USB 网络已恢复，正在确认板卡状态…",
                                progressValue: 0.9,
                                line: detail ?? "主机 USB 网络已恢复"
                            )
                            ensureSucceeded = true
                            break
                        } catch {
                            lastEnsureError = error.localizedDescription
                            self.updatePostFlashRecovery(
                                status: "设备已重启，正在恢复 USB 网络",
                                progress: "检测到 USB ECM，正在恢复主机地址 198.19.77.2…",
                                progressValue: 0.7,
                                line: "USB 网络恢复重试中: \(lastEnsureError)"
                            )
                            try? await Task.sleep(for: .seconds(1))
                        }
                    }
                    if !ensureSucceeded {
                        self.updatePostFlashRecovery(
                            status: "恢复失败",
                            progress: "设备已重启，但 USB 网络自动恢复失败",
                            progressValue: nil,
                            line: lastEnsureError.isEmpty ? "USB 网络自动恢复失败" : lastEnsureError,
                            finished: true,
                            succeeded: false
                        )
                        self.appendActivity(
                            level: .warning,
                            title: context.activityTitle,
                            message: "设备已重启，但 USB 网络自动恢复失败",
                            detail: lastEnsureError
                        )
                        return
                    }
                    await self.refreshTransportStatus(silent: true)
                    let serviceDeadline = Date().addingTimeInterval(20)
                    while !Task.isCancelled, Date() < serviceDeadline {
                        try? await Task.sleep(for: .seconds(1))
                        await self.refreshBoardStatus(silent: true)
                        self.ensureBoardMonitoring(forceImmediate: true)
                        let boardReady = self.status?.board?.ping == true &&
                            self.status?.board?.ssh_port_open == true &&
                            self.status?.board?.control_service == true
                        if boardReady {
                            self.updatePostFlashRecovery(
                                status: "设备已恢复在线",
                                progress: "Ping / SSH / 控制服务已恢复",
                                progressValue: 1.0,
                                line: "Ping / SSH / 控制服务已恢复",
                                finished: true,
                                succeeded: true
                            )
                            self.sendUserNotification(title: context.activityTitle, message: "设备已恢复在线")
                            let keepVisibleSeconds: UInt64 = 3_000_000_000
                            try? await Task.sleep(nanoseconds: keepVisibleSeconds)
                            if !Task.isCancelled {
                                self.clearPostFlashRecovery()
                            }
                            return
                        }
                        let pingReady = self.status?.board?.ping == true
                        let sshReady = self.status?.board?.ssh_port_open == true
                        let controlReady = self.status?.board?.control_service == true
                        let waitingParts = [
                            pingReady ? nil : "Ping",
                            sshReady ? nil : "SSH",
                            controlReady ? nil : "控制服务"
                        ].compactMap { $0 }
                        self.updatePostFlashRecovery(
                            status: "设备已重启，服务仍在恢复中",
                            progress: "USB 网络已恢复，等待板卡服务恢复…",
                            progressValue: 0.95,
                            line: waitingParts.isEmpty ? "等待板卡服务恢复" : "等待恢复: \(waitingParts.joined(separator: " / "))"
                        )
                    }
                    self.updatePostFlashRecovery(
                        status: "设备已重启，服务恢复超时",
                        progress: "USB 网络已恢复，但板卡服务未在预期时间内恢复",
                        progressValue: nil,
                        line: "20 秒内未恢复 Ping / SSH / 控制服务",
                        finished: true,
                        succeeded: false
                    )
                    self.appendActivity(
                        level: .warning,
                        title: context.activityTitle,
                        message: "USB 网络已恢复，但板卡服务未在预期时间内恢复"
                    )
                    return
                }
                self.updatePostFlashRecovery(
                    status: context == .flash ? "刷写完成，等待设备重启" : "设备重启中，等待重新连接",
                    progress: "正在等待设备重启并重新枚举为 USB ECM…",
                    progressValue: 0.2,
                    line: context == .flash ? "设备尚未回到 USB ECM" : "设备尚未重新连接到 USB ECM"
                )
                try? await Task.sleep(for: .seconds(1))
            }
            if !Task.isCancelled {
                self.updatePostFlashRecovery(
                    status: "恢复超时",
                    progress: "刷写已完成，但设备尚未在预期时间内恢复",
                    progressValue: nil,
                    line: "45 秒内未检测到设备恢复到 USB ECM",
                    finished: true,
                    succeeded: false
                )
                self.appendActivity(
                    level: .warning,
                    title: context.activityTitle,
                    message: "刷写已完成，但设备尚未在预期时间内恢复到 USB ECM"
                )
            }
        }
    }

    func prettyTaskOutput(_ task: ToolkitTask?) -> String {
        taskTimelineLines(for: task).joined(separator: "\n")
    }

    func taskProgressLine(for task: ToolkitTask?) -> String {
        taskDisplaySummary(for: task).progress
    }

    func taskTimelineLines(for task: ToolkitTask?) -> [String] {
        taskDisplaySummary(for: task).lines
    }

    func taskProgressValue(for task: ToolkitTask?) -> Double? {
        if !pendingTaskTitle.isEmpty && task == nil {
            return 0.05
        }
        guard let task else {
            return nil
        }
        if task.status == "finished" {
            return task.ok == true ? 1.0 : nil
        }
        let output = task.output_tail ?? ""
        let action = task.action ?? ""
        return progressValue(for: action, output: output)
    }

    private func progressValue(for action: String, output: String) -> Double? {
        let text = output.lowercased()
        switch action {
        case "release-install-environment":
            var progress = 0.05
            if text.contains("downloading remote manifest") || text.contains("probing") {
                progress = max(progress, 0.12)
            }
            if text.contains("loading official image") || text.contains("downloading official image archive") || text.contains("official image already available") || text.contains("building official image") {
                progress = max(progress, 0.28)
            }
            if text.contains("importing host images") || text.contains("downloading host images") {
                progress = max(progress, 0.48)
            }
            if text.contains("importing official workspace") || text.contains("downloading full workspace payload") || text.contains("seeding full development volume") {
                progress = max(progress, 0.72)
            }
            if text.contains("optional qt host tools") {
                progress = max(progress, 0.84)
            }
            if text.contains("verifying release environment") {
                progress = max(progress, 0.93)
            }
            if text.contains("full development environment install completed") {
                progress = 1.0
            }
            return progress
        case "release-update-toolkit":
            var progress = 0.08
            if text.contains("downloading update manifest") || text.contains("remote version") {
                progress = max(progress, 0.2)
            }
            if text.contains("downloading toolkit bundle") || text.contains("update bundle is reachable") {
                progress = max(progress, 0.55)
            }
            if text.contains("extracting") || text.contains("installing") || text.contains("verifying") {
                progress = max(progress, 0.85)
            }
            if text.contains("replacing installed application") {
                progress = max(progress, 0.96)
            }
            if text.contains("toolkit update completed") || text.contains("installed app:") {
                progress = 1.0
            }
            return progress
        case "release-update-images":
            var progress = 0.08
            if text.contains("downloading host images") || text.contains("host image bundle is reachable") {
                progress = max(progress, 0.45)
            }
            if text.contains("importing host images") {
                progress = max(progress, 0.82)
            }
            return progress
        default:
            return nil
        }
    }

    private func taskDisplaySummary(for task: ToolkitTask?) -> (progress: String, lines: [String]) {
        guard let task else {
            if !pendingTaskTitle.isEmpty {
                return ("正在初始化日志流…", [])
            }
            return ("等待日志输出…", [])
        }
        if let output = task.output_tail, !output.isEmpty {
            let compact = compactTaskOutput(
                output,
                action: task.action ?? "",
                isFinished: task.status == "finished",
                isSuccess: task.ok == true
            )
            if !compact.progress.isEmpty || !compact.lines.isEmpty {
                return compact
            }
        }
        if let logPath = task.log_path, !logPath.isEmpty {
            return ("正在初始化日志流…", ["日志文件: \(logPath)"])
        }
        return ("等待日志输出…", [])
    }

    func taskStatusText(for task: ToolkitTask?) -> String {
        guard pendingTaskTitle.isEmpty else {
            return ""
        }
        guard let task else {
            return ""
        }
        if task.status == "finished" {
            if task.ok == true {
                if ["flash", "release-update-logo-flash", "release-update-dtb-flash"].contains(task.action ?? "") {
                    return "下载成功，正在重启设备…"
                }
                return "执行完成"
            }
            return "执行失败"
        }
        return ""
    }

    private func compactTaskOutput(_ output: String, action: String, isFinished: Bool, isSuccess: Bool) -> (progress: String, lines: [String]) {
        let planPattern = #"\[stage\] plan\s+(\S+)\s+file=.* offset=(0x[0-9a-fA-F]+) write_sectors=0x([0-9a-fA-F]+)"#
        let writePattern = #"rkflashtool: info: writing flash memory at offset (0x[0-9a-fA-F]+)(\.\.\. Done!)?"#
        let chunkPattern = #"Using LBA read/write chunk size (\d+) sectors"#
        let lines = output
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        var stageLines: [String] = []
        var infoLines: [String] = []
        var partitionName = ""
        var startOffset: Int?
        var totalSectors: Int?
        var currentOffset: Int?
        var chunkSectors: Int = 0
        var writeDone = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            if let groups = regexGroups(in: line, pattern: chunkPattern), let value = Int(groups[0]) {
                chunkSectors = value
                continue
            }

            if let groups = regexGroups(in: line, pattern: planPattern), groups.count >= 3 {
                partitionName = groups[0]
                startOffset = Int(String(groups[1]).dropFirst(2), radix: 16)
                totalSectors = Int(String(groups[2]), radix: 16)
                stageLines.append(line)
                continue
            }

            if let groups = regexGroups(in: line, pattern: writePattern), !groups.isEmpty {
                currentOffset = Int(String(groups[0]).dropFirst(2), radix: 16)
                writeDone = line.contains("... Done!")
                continue
            }

            if line.contains("USB device scan") ||
                line.contains("descriptor:") ||
                line.contains("interface=") ||
                line.contains("ep=0x") ||
                line.contains("strings:") ||
                line.contains("kernel_driver_") ||
                line.contains("claim_interface_") ||
                line.contains("mode_hint:") ||
                line.contains("config: source=") {
                continue
            }

            if line.hasPrefix("[stage]") {
                stageLines.append(line)
                continue
            }

            if line.hasPrefix("rkflashtool: info:") {
                infoLines.append(line)
                continue
            }

            infoLines.append(line)
        }

        let cleanedStages = dedupeConsecutive(stageLines.map { cleanTaskLine($0) })
        var result: [String] = Array(cleanedStages.suffix(6))
        var progress = ""

        if let currentOffset {
            let displayName = partitionName.isEmpty ? "当前分区" : partitionName
            if let startOffset, let totalSectors, totalSectors > 0 {
                var completed = max(0, currentOffset - startOffset)
                if chunkSectors > 0 {
                    completed += chunkSectors
                }
                if writeDone {
                    completed = totalSectors
                }
                let percent = max(0, min(100, Int((Double(completed) / Double(totalSectors)) * 100.0)))
                progress = "刷写进度: \(displayName) \(percent)%"
            } else {
                progress = "刷写进度: offset \(String(format: "0x%08x", currentOffset))"
            }
        } else if action == "flash" && output.contains("waiting for target board") {
            progress = "正在等待开发板进入 Loader…"
        } else if action == "flash" {
            progress = "正在准备刷写任务…"
        }

        let filteredInfo = infoLines.filter {
            !$0.contains("writing flash memory at offset") &&
            !$0.contains("USB device scan")
        }.map { cleanTaskLine($0) }
        result.append(contentsOf: dedupeConsecutive(filteredInfo).suffix(3))

        if action == "flash" && isFinished && isSuccess {
            progress = "下载成功，正在重启设备…"
        } else if isFinished && isSuccess {
            progress = "执行完成"
        }

        return (progress, Array(result.suffix(6)))
    }

    private func regexGroups(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        return (1..<match.numberOfRanges).compactMap { index in
            let groupRange = match.range(at: index)
            guard groupRange.location != NSNotFound, let swiftRange = Range(groupRange, in: text) else {
                return nil
            }
            return String(text[swiftRange])
        }
    }

    private func cleanTaskLine(_ line: String) -> String {
        let cleaned = line
            .replacingOccurrences(of: "[stage] ", with: "")
            .replacingOccurrences(of: "rkflashtool: info: ", with: "")
        if cleaned.hasPrefix("command: ") {
            return cleaned.replacingOccurrences(of: "command: ", with: "执行入口: ")
        }
        if cleaned.hasPrefix("process started: ") {
            return cleaned.replacingOccurrences(of: "process started: ", with: "后台任务已启动: ")
        }
        return cleaned
    }

    private func dedupeConsecutive(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            if result.last != line {
                result.append(line)
            }
        }
        return result
    }

    func makeSnapshot(from status: ToolkitStatus) -> StatusSnapshot {
        StatusSnapshot(
            usbMode: status.usb?.mode ?? "-",
            usbProduct: status.usb?.product ?? "-",
            usbPid: status.usb?.pid ?? "-",
            usbIface: status.usbnet?.iface ?? "-",
            hostIP: status.usbnet?.current_ip ?? "-",
            usbConfigured: status.usbnet?.configured ?? false,
            ping: status.board?.ping ?? false,
            ssh: status.board?.ssh_port_open ?? false,
            controlService: status.board?.control_service ?? false,
            dockerReady: status.host?.docker_daemon ?? false,
            usbnetHelperInstalled: status.host?.usbnet_helper_installed ?? false
        )
    }

    func recordStatusChanges(from old: StatusSnapshot, to new: StatusSnapshot) {
        var changes: [(ActivityLevel, String, String)] = []

        if old.usbMode != new.usbMode {
            changes.append((.info, "USB 模式变化", "\(old.usbMode) -> \(new.usbMode)"))
        }
        if old.hostIP != new.hostIP || old.usbConfigured != new.usbConfigured {
            let message = "主机地址 \(old.hostIP) -> \(new.hostIP)"
            changes.append((new.usbConfigured ? .success : .warning, "USB 网络变化", message))
        }
        if old.ping != new.ping {
            changes.append((new.ping ? .success : .warning, "板卡连通性变化", new.ping ? "开发板已在线" : "开发板已离线"))
        }
        if old.ssh != new.ssh {
            changes.append((new.ssh ? .success : .warning, "SSH 状态变化", new.ssh ? "SSH 已可连接" : "SSH 不可连接"))
        }
        if old.controlService != new.controlService {
            changes.append((new.controlService ? .success : .warning, "控制服务变化", new.controlService ? "usb0 控制服务已恢复" : "usb0 控制服务不可达"))
        }
        if old.dockerReady != new.dockerReady {
            changes.append((new.dockerReady ? .success : .warning, "Docker 状态变化", new.dockerReady ? "Docker 已就绪" : "Docker 未就绪"))
        }
        if old.usbnetHelperInstalled != new.usbnetHelperInstalled {
            changes.append((
                new.usbnetHelperInstalled ? .success : .warning,
                "网络权限变化",
                new.usbnetHelperInstalled ? "主机 USB 网络权限已安装" : "主机 USB 网络权限未安装"
            ))
        }

        for change in changes {
            appendActivity(level: change.0, title: change.1, message: change.2)
            sendUserNotification(title: change.1, message: change.2)
        }
    }

    func restartServiceForWorkspaceModeSwitch() {
        busy = true
        Task {
            transitionWatchTask?.cancel()
            taskPollTask?.cancel()
            currentTask = nil
            pendingTaskTitle = ""
            lastSnapshot = nil
            status = nil
            await ensureLocalAgentStartedIfNeeded()
            refreshStatus(silent: true)
            busy = false
        }
    }

    func applyStatusUpdate(_ newStatus: ToolkitStatus, silent: Bool = false) {
        lastEventAt = Date()
        let stableStatus = stabilizedStatus(from: newStatus)
        let newSnapshot = makeSnapshot(from: stableStatus)
        let previousSnapshot = lastSnapshot
        if let oldSnapshot = previousSnapshot, oldSnapshot != newSnapshot {
            recordStatusChanges(from: oldSnapshot, to: newSnapshot)
        } else if previousSnapshot == nil, !silent {
            appendActivity(level: .success, title: "状态监控", message: "已建立实时订阅")
        }
        if previousSnapshot == newSnapshot {
            if newSnapshot.usbMode == "usb-ecm" && newSnapshot.usbConfigured &&
                newSnapshot.ping && newSnapshot.ssh {
                boardStateGraceUntil = nil
            }
            persistWorkspaceSelection()
            updateBoardRoutingFromCurrentState()
            lastRefreshErrorSignature = ""
            return
        }
        status = stableStatus
        lastSnapshot = newSnapshot
        if newSnapshot.usbMode == "usb-ecm" && newSnapshot.usbConfigured &&
            newSnapshot.ping && newSnapshot.ssh {
            boardStateGraceUntil = nil
        }
        persistWorkspaceSelection()
        updateBoardRoutingFromCurrentState()
        lastRefreshErrorSignature = ""
    }

    func stabilizedStatus(from status: ToolkitStatus) -> ToolkitStatus {
        guard let current = self.status else {
            return status
        }

        let withinGrace = boardStateGraceUntil.map { Date() < $0 } ?? false
        let usbLooksStable = (status.usb?.mode == "usb-ecm") && (status.usbnet?.configured == true)
        let previousUSBLooksStable = (current.usb?.mode == "usb-ecm") && (current.usbnet?.configured == true)
        guard usbLooksStable || (withinGrace && previousUSBLooksStable) else {
            return status
        }

        return ToolkitStatus(
            repo_root: status.repo_root,
            service: status.service,
            updated_at: status.updated_at,
            usb: status.usb,
            usbnet: status.usbnet,
            board: stabilizedBoardStatus(status.board),
            host: status.host,
            device: status.device,
            summary: status.summary,
            device_summary: status.device_summary
        )
    }

    func startBackgroundMonitoring() {
        guard !monitoringStarted else {
            return
        }
        monitoringStarted = true
        startBoardPluginCatalogSyncLoop()
        systemMonitor = SystemEventMonitor { [weak self] reason in
            self?.handleSystemEvent(reason)
        }
        systemMonitor?.start()
        startLocalAgentMonitor()
        Task {
            refreshStatus(silent: true)
        }
    }

    func handleSystemEvent(_ reason: String) {
        if isFlashTaskRunning {
            return
        }
        if reason == "usb-removed" {
            boardStateGraceUntil = nil
            stopBoardMonitoring()
            resetAutomaticUSBNetRepairState(cancelTask: true)
        } else if reason == "usb-added" {
            boardStateGraceUntil = Date().addingTimeInterval(8)
        } else if reason == "network", status?.usb?.mode == "usb-ecm" {
            boardStateGraceUntil = Date().addingTimeInterval(5)
        }
        pendingSystemRefreshTask?.cancel()
        pendingSystemRefreshTask = Task { [weak self] in
            let delay = reason.hasPrefix("usb") ? Duration.milliseconds(40) : Duration.milliseconds(120)
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else {
                return
            }
            self.refreshStatus(silent: true)
        }
    }

    func startLocalAgentMonitor() {
        localAgentMonitorTask?.cancel()
        localAgentMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isFlashTaskRunning {
                    self.refreshStatus(silent: true)
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func applyTransientUSBStateIfNeeded() {
        guard let current = status else {
            return
        }
        if current.usb?.mode == "usb-ecm", current.usbnet?.configured == true {
            return
        }
        applyTransientUSBState(from: current)
    }

    func applyTransientUSBState(from current: ToolkitStatus) {
        resetBoardFailureCounters()
        let transient = ToolkitStatus(
            repo_root: current.repo_root,
            service: current.service,
            updated_at: current.updated_at,
            usb: .init(
                mode: "detecting",
                product: current.usb?.product,
                pid: current.usb?.pid
            ),
            usbnet: .init(
                iface: current.usbnet?.iface,
                current_ip: nil,
                expected_ip: current.usbnet?.expected_ip,
                board_ip: current.usbnet?.board_ip,
                configured: false
            ),
            board: .init(
                ping: false,
                ssh_port_open: false,
                control_service: false
            ),
            host: current.host,
            device: current.device,
            summary: current.summary,
            device_summary: current.device_summary
        )
        status = transient
        lastSnapshot = makeSnapshot(from: transient)
    }

    func applyDisconnectedUSBState() {
        guard let current = status else {
            return
        }
        resetBoardFailureCounters()
        let disconnected = ToolkitStatus(
            repo_root: current.repo_root,
            service: current.service,
            updated_at: current.updated_at,
            usb: .init(
                mode: "absent",
                product: nil,
                pid: nil
            ),
            usbnet: .init(
                iface: nil,
                current_ip: nil,
                expected_ip: current.usbnet?.expected_ip,
                board_ip: current.usbnet?.board_ip,
                configured: false
            ),
            board: .init(
                ping: false,
                ssh_port_open: false,
                control_service: false
            ),
            host: current.host,
            device: nil,
            summary: nil,
            device_summary: nil
        )
        status = disconnected
        lastSnapshot = makeSnapshot(from: disconnected)
    }

    func startTransitionWatch(reason: String, duration: TimeInterval = 28, step: TimeInterval = 1.0) {
        transitionWatchTask?.cancel()
        transitionWatchTask = Task { [weak self] in
            guard let self else {
                return
            }
            let started = Date()
            var stableTicks = 0
            var previous = self.lastSnapshot
            while !Task.isCancelled, Date().timeIntervalSince(started) < duration {
                let currentStep: TimeInterval = Date().timeIntervalSince(started) < 4 ? 0.35 : step
                try? await Task.sleep(for: .seconds(currentStep))
                guard !Task.isCancelled else {
                    return
                }
                await self.refreshTransportStatus(silent: true)
                if self.status?.usb?.mode == "usb-ecm", self.status?.usbnet?.configured == true {
                    await self.refreshBoardStatus(silent: true)
                }
                if self.lastSnapshot == previous {
                    stableTicks += 1
                } else {
                    stableTicks = 0
                    previous = self.lastSnapshot
                }
                if stableTicks >= 3, Date().timeIntervalSince(started) >= 6 {
                    break
                }
            }
            if reason == "usb" || reason == "network" {
                self.appendActivity(level: .info, title: "状态跟踪", message: "已完成 \(reason) 变化后的状态同步")
            }
        }
    }

    func resetBoardFailureCounters() {
        boardPingFalseCount = 0
        boardSSHFalseCount = 0
        boardControlFalseCount = 0
    }

    func stabilizedBoardStatus(_ nextBoard: ToolkitStatus.Board?) -> ToolkitStatus.Board {
        let incoming = nextBoard ?? ToolkitStatus.Board(ping: false, ssh_port_open: false, control_service: false)
        let current = status?.board ?? ToolkitStatus.Board(ping: false, ssh_port_open: false, control_service: false)

        func stableValue(
            incoming: Bool?,
            current: Bool?,
            counter: inout Int
        ) -> Bool {
            let next = incoming ?? false
            let previous = current ?? false

            if next {
                counter = 0
                return true
            }

            if !previous {
                counter = 0
                return false
            }

            counter += 1
            if counter >= boardFalseThreshold {
                counter = 0
                return false
            }
            return true
        }

        return ToolkitStatus.Board(
            ping: stableValue(incoming: incoming.ping, current: current.ping, counter: &boardPingFalseCount),
            ssh_port_open: stableValue(incoming: incoming.ssh_port_open, current: current.ssh_port_open, counter: &boardSSHFalseCount),
            control_service: stableValue(incoming: incoming.control_service, current: current.control_service, counter: &boardControlFalseCount)
        )
    }

    func startEventStream() {
        eventTask?.cancel()
        eventStreamConnected = false
        eventTask = nil
    }

    func stopEventStream() {
        eventTask?.cancel()
        eventTask = nil
        eventStreamConnected = false
    }

    func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    func refreshStatus(silent: Bool = false) {
        if isFlashTaskRunning {
            return
        }
        if busy && !silent {
            return
        }
        refreshSequence += 1
        let sequence = refreshSequence
        if !silent {
            busy = true
        }
        Task {
            do {
                _ = try workspaceURL()
                await ensureLocalAgentStartedIfNeeded()
                guard sequence == self.refreshSequence else {
                    if !silent {
                        self.busy = false
                    }
                    return
                }
                var localAgentApplied = false
                if let agentStatus = try? await fetchLocalAgentStatusSummary() {
                    self.applyLocalAgentStatusSummary(agentStatus, silent: true)
                    localAgentApplied = true
                } else {
                    self.localAgentRunning = false
                }
                if !localAgentApplied {
                    let fallbackStatus = self.mergedStatus(
                        summary: "本地 DBT Agent 暂不可用",
                        deviceSummary: "本地 DBT Agent 暂不可用",
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    self.applyStatusUpdate(fallbackStatus, silent: true)
                }
            } catch {
                let signature = error.localizedDescription
                if sequence == self.refreshSequence, signature != lastRefreshErrorSignature {
                    presentInlineError("刷新状态失败: \(signature)")
                    appendActivity(level: .error, title: "状态刷新失败", message: signature)
                    lastRefreshErrorSignature = signature
                }
            }
            busy = false
        }
    }

    func runManagedAction(
        title: String,
        successMessage: String,
        localArgs: [String],
        plainText: Bool = false,
        transitionTracking: Bool = false,
        asyncTask: Bool = false,
        preferLocalExecution: Bool = false,
        environmentOverrides: [String: String] = [:],
        servicePayloadOverrides: [String: Any] = [:],
        recoveryContext: DeviceRecoveryContext? = nil
    ) {
        busy = true
        Task {
            do {
                _ = try workspaceURL()
                clearInlineError()
                if asyncTask {
                    taskPollTask?.cancel()
                    dismissedFinishedTaskIDs.removeAll()
                    currentTask = nil
                    pendingTaskTitle = title
                }
                let routedLocalArgs = self.routedBoardArguments(for: localArgs)
                let args = routedLocalArgs
                let detail: String
                if asyncTask {
                    await ensureLocalAgentStartedIfNeeded()
                    guard localAgentRunning else {
                        throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                    }
                    let response = try await postLocalAgentRuntimeJob(
                        actionID: managedRuntimeActionID(for: args),
                        title: title,
                        arguments: args,
                        environmentOverrides: environmentOverrides
                    )
                    pendingTaskTitle = ""
                    currentTask = response.task
                    busy = false
                    if let taskID = response.task?.id {
                        appendActivity(level: .info, title: title, message: "任务已启动", detail: response.task?.log_path)
                        pollTask(taskID)
                    }
                    detail = response.task?.log_path ?? ""
                } else if plainText {
                    detail = try await runPlainAction(args, environmentOverrides: environmentOverrides)
                } else {
                    let response = try await runJSONAction(args, environmentOverrides: environmentOverrides)
                    detail = response.output ?? response.output_tail ?? response.log_path ?? ""
                }
                appendActivity(level: .success, title: title, message: successMessage, detail: detail)
                if let recoveryContext, !asyncTask {
                    startPostFlashRecovery(recoveryContext)
                }
                if transitionTracking {
                    startTransitionWatch(reason: title, duration: 14, step: 1.0)
                }
                if !asyncTask {
                    refreshStatus(silent: true)
                }
            } catch {
                let detail = error.localizedDescription
                pendingTaskTitle = ""
                presentInlineError(detail)
                appendActivity(level: .error, title: title, message: "执行失败", detail: detail)
                busy = false
            }
            if !asyncTask {
                busy = false
            }
        }
    }

    private func managedRuntimeActionID(for arguments: [String]) -> String {
        guard arguments.count >= 2 else {
            return arguments.first ?? "runtime-action"
        }
        return "\(arguments[0])-\(arguments[1])"
    }

    private func routedBoardArguments(for arguments: [String]) -> [String] {
        guard let first = arguments.first, first == "dev" || first == "release" else {
            return arguments
        }
        guard !arguments.contains("--board") else {
            return arguments
        }
        guard let boardID = preferredControlBoardID ?? connectedBoardID, !boardID.isEmpty else {
            return arguments
        }
        var routed = arguments
        routed.append(contentsOf: ["--board", boardID])
        if let variantID = activeVariantID(for: boardID), !variantID.isEmpty, !arguments.contains("--variant") {
            routed.append(contentsOf: ["--variant", variantID])
        }
        return routed
    }

    func checkHost() {
        Task {
            if let message = await validatePrecondition(.checkHost) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "主机预检", message: message)
                return
            }
            runManagedAction(
                title: "主机预检",
                successMessage: "检查任务已提交",
                localArgs: ["check-host", "all"],
                asyncTask: true
            )
        }
    }

    func ensureUSBNet() {
        Task {
            if let message = await validatePrecondition(.ensureUSBNet) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "USB 网络", message: message)
                return
            }
            runManagedAction(
                title: "USB 网络",
                successMessage: "恢复任务已提交",
                localArgs: ["usbnet", "ensure"],
                asyncTask: true
            )
        }
    }

    func installUSBNetHelper() {
        Task {
            if let message = await validatePrecondition(.ensureUSBNet) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "网络权限安装", message: message)
                return
            }
            runManagedAction(
                title: "网络权限安装",
                successMessage: "安装任务已提交",
                localArgs: ["usbnet", "install-helper", "--json"],
                transitionTracking: true,
                asyncTask: true,
                preferLocalExecution: true
            )
        }
    }

    func checkDevelopmentEnvironment() {
        installerLastDetail = "准备检查发布环境..."
        runManagedAction(
            title: "发布环境检查",
            successMessage: "检查任务已提交",
            localArgs: ["release", "check-env"],
            asyncTask: true
        )
    }

    func installFullDevelopmentEnvironment() {
        installerLastDetail = "准备开始全量安装..."
        runManagedAction(
            title: "发布环境全量安装",
            successMessage: "全量安装任务已提交",
            localArgs: ["release", "install-environment"],
            asyncTask: true
        )
    }

    func installFullDevelopmentEnvironmentFromLocal() {
        let trimmed = localArtifactsDir.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presentInlineError("请先选择本地安装包目录。")
            appendActivity(level: .warning, title: "本地安装", message: "未选择本地安装包目录")
            return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory), isDirectory.boolValue else {
            presentInlineError("本地安装包目录不存在：\(trimmed)")
            appendActivity(level: .warning, title: "本地安装", message: "本地安装包目录不存在")
            return
        }
        guard localArtifactValidation.ready else {
            presentInlineError("本地安装资源未通过完整性校验，请先完成检查。")
            appendActivity(level: .warning, title: "本地安装", message: "资源校验未通过")
            return
        }
        installerLastDetail = "准备从本地目录导入发布环境..."
        runManagedAction(
            title: "发布环境本地安装",
            successMessage: "本地安装任务已提交",
            localArgs: ["release", "install-environment", "--artifacts-dir", trimmed],
            asyncTask: true
        )
    }

    func installCodexPlugin() {
        runManagedAction(
            title: "安装 Codex 插件",
            successMessage: "Codex 插件安装任务已提交",
            localArgs: ["release", "install-codex-plugin"],
            asyncTask: true
        )
        Task {
            try? await Task.sleep(for: .seconds(2))
            await refreshDevelopmentInstallStatus()
        }
    }

    func installOpenCodePlugin() {
        if !developmentInstallStatus.npmReady {
            presentInlineError("未检测到 npm，无法安装 OpenCode 插件。请先安装 Node.js/npm。")
            appendActivity(level: .warning, title: "安装 OpenCode 插件", message: "未检测到 npm")
            return
        }
        runManagedAction(
            title: "安装 OpenCode 插件",
            successMessage: "OpenCode 插件安装任务已提交",
            localArgs: ["release", "install-opencode-plugin"],
            asyncTask: true
        )
        Task {
            try? await Task.sleep(for: .seconds(2))
            await refreshDevelopmentInstallStatus()
        }
    }

    func checkToolkitUpdate() {
        updaterLastDetail = "正在检查远程版本..."
        automaticToolkitUpdateInProgress = true
        refreshToolkitUpdateStatus()
        Task {
            do {
                _ = try workspaceURL()
                let task = try await runWithTimeout(
                    seconds: 18,
                    failureMessage: "检查更新超时（18 秒），请检查网络连接或服务器状态。"
                ) {
                    try await self.runLocalAgentRuntimeJobAndWait(
                        actionID: "release-check-update",
                        title: "检查软件更新",
                        arguments: ["release", "check-update"],
                        timeout: 15
                    )
                }
                let detail = task.output_tail ?? "检查完成"
                updaterLastDetail = detail
                parseUpdateStatus(detail: detail)
                appendActivity(level: .success, title: "软件更新", message: toolkitUpdateHeadline, detail: detail)
            } catch {
                let detail = error.localizedDescription
                updaterLastDetail = detail
                presentInlineError(detail)
                appendActivity(level: .error, title: "软件更新", message: "检查失败", detail: detail)
            }
            automaticToolkitUpdateInProgress = false
        }
    }

    func startAutomaticToolkitUpdateFlow() {
        refreshToolkitUpdateStatus()
        guard updateConfigured else {
            updaterLastDetail = "未配置软件更新地址"
            return
        }
        guard !(isUpdaterTask(currentTask) && currentTask?.status != "finished") else {
            return
        }
        automaticToolkitUpdateTask?.cancel()
        automaticToolkitUpdateTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.automaticToolkitUpdateTask = nil
                if !(self.isUpdaterTask(self.currentTask) && self.currentTask?.status != "finished") {
                    self.automaticToolkitUpdateInProgress = false
                }
            }
            self.automaticToolkitUpdateInProgress = true
            self.updaterLastDetail = "正在联网检查更新..."
            self.refreshToolkitUpdateStatus()
            do {
                _ = try self.workspaceURL()
                let task = try await self.runWithTimeout(
                    seconds: 18,
                    failureMessage: "检查更新超时（18 秒），请检查网络连接或服务器状态。"
                ) {
                    try await self.runLocalAgentRuntimeJobAndWait(
                        actionID: "release-check-update",
                        title: "检查软件更新",
                        arguments: ["release", "check-update"],
                        timeout: 15
                    )
                }
                let detail = task.output_tail ?? "检查完成"
                self.updaterLastDetail = detail
                self.parseUpdateStatus(detail: detail)
                if self.toolkitUpdateStatus.updateAvailable {
                    self.updaterLastDetail = "发现新版本，正在下载安装..."
                    self.shouldRelaunchAfterToolkitUpdate = true
                    self.installToolkitUpdate()
                } else {
                    self.shouldRelaunchAfterToolkitUpdate = false
                    self.updaterLastDetail = "当前已是最新版本"
                    self.appendActivity(level: .success, title: "软件更新", message: "当前已是最新版本")
                }
            } catch {
                self.shouldRelaunchAfterToolkitUpdate = false
                let detail = error.localizedDescription
                self.updaterLastDetail = detail
                self.presentInlineError(detail)
                self.appendActivity(level: .error, title: "软件更新", message: "检查失败", detail: detail)
            }
        }
    }

    func installToolkitUpdate() {
        updaterLastDetail = "准备下载并安装更新..."
        runManagedAction(
            title: "软件更新",
            successMessage: "更新任务已提交",
            localArgs: ["release", "update-toolkit"],
            asyncTask: true
        )
    }

    func updateInitialImages() {
        updaterLastDetail = "准备下载并更新初始镜像..."
        runManagedAction(
            title: "初始镜像更新",
            successMessage: "初始镜像更新任务已提交",
            localArgs: ["release", "update-images"],
            asyncTask: true
        )
    }

    private func relaunchToolkitApplication() {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else {
            return
        }
        let targetPath = bundleURL.path
        let currentPID = ProcessInfo.processInfo.processIdentifier
        Task { @MainActor in
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/bash")
            helper.arguments = [
                "-lc",
                """
                app_path="$1"
                exiting_pid="$2"
                checks=0
                while kill -0 "${exiting_pid}" 2>/dev/null; do
                    checks=$((checks + 1))
                    if [ "${checks}" -ge 50 ]; then
                        break
                    fi
                    sleep 0.2
                done
                sleep 0.5
                exec /usr/bin/open -n "${app_path}"
                """,
                "development-board-toolchain-relaunch",
                targetPath,
                String(currentPID),
            ]
            helper.standardInput = nil
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try? helper.run()
            try? await Task.sleep(for: .milliseconds(250))
            NSApp.terminate(nil)
        }
    }

    func installOfficialImage() {
        installerLastDetail = "准备构建官方镜像..."
        runManagedAction(
            title: "官方镜像安装",
            successMessage: "官方镜像构建任务已提交",
            localArgs: ["release", "build-image"],
            asyncTask: true
        )
    }

    func installReleaseVolume(profile: String) {
        let title = profile == "bsp-flex" ? "完整开发 Volume" : "基础 Volume"
        installerLastDetail = "准备初始化\(title)..."
        runManagedAction(
            title: title,
            successMessage: "\(title)初始化任务已提交",
            localArgs: ["release", "seed-volume", "--profile", profile],
            asyncTask: true
        )
    }

    func authorizeKey() {
        Task {
            if let message = await validatePrecondition(.authorizeKey) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "SSH 授权", message: message)
                return
            }
            runManagedAction(
                title: "SSH 授权",
                successMessage: "授权任务已提交",
                localArgs: ["usb", "authorize-key"],
                asyncTask: true
            )
        }
    }

    func rebootLoader() {
        Task {
            if let message = await validatePrecondition(.rebootLoader) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "切换 Loader", message: message)
                return
            }
            let route = currentOperationRoute()
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "切换 Loader"
                let response = try await postLocalAgentRebootJob(
                    target: "loader",
                    boardID: route.boardID,
                    variantID: route.variantID
                )
                pendingTaskTitle = ""
                currentTask = response.task
                appendActivity(level: .info, title: "切换 Loader", message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "切换 Loader", message: "执行失败", detail: detail)
            }
        }
    }

    func rebootDevice() async throws {
        if let message = await validatePrecondition(.rebootDevice) {
            presentInlineError(message)
            appendActivity(level: .warning, title: "设备重启", message: message)
            throw ToolkitGUIError.commandFailed(message)
        }

        let title = "设备重启"
        busy = true
        defer { busy = false }

        do {
            let route = currentOperationRoute()
            await ensureLocalAgentStartedIfNeeded()
            guard localAgentRunning else {
                throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
            }
            clearInlineError()
            taskPollTask?.cancel()
            dismissedFinishedTaskIDs.removeAll()
            currentTask = nil
            pendingTaskTitle = title
            let response = try await postLocalAgentRebootJob(
                target: "device",
                boardID: route.boardID,
                variantID: route.variantID
            )
            pendingTaskTitle = ""
            currentTask = response.task
            let detail = response.task?.log_path ?? ""
            appendActivity(level: .info, title: title, message: "任务已启动", detail: detail)
            if let taskID = response.task?.id {
                pollTask(taskID)
            }
        } catch {
            pendingTaskTitle = ""
            let detail = error.localizedDescription
            presentInlineError(detail)
            appendActivity(level: .error, title: title, message: "执行失败", detail: detail)
            throw error
        }
    }

    func flash(_ target: String, source: FlashImageSource = .custom) {
        Task {
            let route = currentOperationRoute()
            if source == .factory {
                do {
                    try await ensureFactoryImagesReady()
                } catch {
                    presentInlineError(error.localizedDescription)
                    appendActivity(level: .error, title: "\(source.displayName)同步", message: "初始镜像准备失败", detail: error.localizedDescription)
                    return
                }
            }
            if let message = await validatePrecondition(.flash(target)) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "刷写 \(target)", message: message)
                return
            }
            if let localError = localFlashPrerequisiteError(target, source: source) {
                presentInlineError(localError)
                appendActivity(level: .warning, title: "\(source.displayName)刷写", message: localError)
                return
            }
            busy = true
            defer { busy = false }
            do {
                _ = try workspaceURL()
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "\(source.displayName)刷写 \(target)"
                let response = try await postLocalAgentFlashJob(
                    scope: target,
                    source: source,
                    boardID: route.boardID,
                    variantID: route.variantID,
                    hostImageDir: imageDirURL(for: source).path
                )
                pendingTaskTitle = ""
                currentTask = response.task
                let detail = response.task?.log_path ?? imageDirURL(for: source).path
                appendActivity(level: .info, title: "\(source.displayName)刷写 \(target)", message: "任务已启动", detail: detail)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "\(source.displayName)刷写 \(target)", message: "执行失败", detail: detail)
            }
        }
    }

    func buildSync() {
        Task {
            if let message = await validatePrecondition(.buildSync) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "开发版构建", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "开发版构建"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "dev-build-sync",
                    title: "开发版构建",
                    arguments: ["dev", "build-sync"]
                )
                pendingTaskTitle = ""
                currentTask = response.task
                appendActivity(level: .info, title: "开发版构建", message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "开发版构建", message: "执行失败", detail: detail)
            }
        }
    }

    func buildSyncFlash() {
        Task {
            if let message = await validatePrecondition(.buildSyncFlash) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "开发版构建并刷写", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "开发版构建并刷写"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "dev-build-sync-flash",
                    title: "开发版构建并刷写",
                    arguments: ["dev", "build-sync-flash"]
                )
                pendingTaskTitle = ""
                currentTask = response.task
                appendActivity(level: .info, title: "开发版构建并刷写", message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "开发版构建并刷写", message: "执行失败", detail: detail)
            }
        }
    }

    func updateLogo() {
        dismissEditingFocus()
        var localArgs = ["release", "update-logo", "--logo", logoPath, "--rotate", logoRotate, "--scale", logoScale]
        if logoFlashAfter {
            localArgs.append("--flash")
        }
        Task {
            if let message = await validatePrecondition(.updateLogo(flashAfter: logoFlashAfter)) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "启动 Logo", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "启动 Logo"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "release-update-logo",
                    title: "启动 Logo",
                    arguments: localArgs
                )
                pendingTaskTitle = ""
                currentTask = response.task
                appendActivity(level: .info, title: "启动 Logo", message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "启动 Logo", message: "执行失败", detail: detail)
            }
        }
    }

    func dismissEditingFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    func updateDTB() {
        dismissEditingFocus()
        var localArgs = ["release", "update-dtb", "--dts-file", dtsFilePath]
        if dtsFlashAfter {
            localArgs.append("--flash")
        }
        Task {
            if let message = await validatePrecondition(.updateDTB(flashAfter: dtsFlashAfter)) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "设备树", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed("本地 DBT Agent 暂不可用")
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "设备树"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "release-update-dtb",
                    title: "设备树",
                    arguments: localArgs
                )
                pendingTaskTitle = ""
                currentTask = response.task
                appendActivity(level: .info, title: "设备树", message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "设备树", message: "执行失败", detail: detail)
            }
        }
    }

    func reconnectMonitoring() {
        lastEventAt = Date()
        refreshStatus(silent: true)
    }

    func browseFile(assign: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let window = NSApp.keyWindow {
            fileDialogActive = true
            panel.beginSheetModal(for: window) { response in
                self.fileDialogActive = false
                if response == .OK, let url = panel.url {
                    assign(url.path)
                }
            }
            return
        }
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
        }
    }

    func browseDirectory(assign: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        if let window = NSApp.keyWindow {
            fileDialogActive = true
            panel.beginSheetModal(for: window) { response in
                self.fileDialogActive = false
                if response == .OK, let url = panel.url {
                    assign(url.path)
                }
            }
            return
        }
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
        }
    }

    func validateLocalArtifactsDirectory(showFailureDetails: Bool = false) {
        let trimmed = localArtifactsDir.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            localArtifactValidation = LocalArtifactValidationState()
            return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory), isDirectory.boolValue else {
            localArtifactValidation = LocalArtifactValidationState(
                checking: false,
                checked: true,
                ready: false,
                summary: "本地安装目录不存在",
                items: [
                    LocalArtifactValidationItem(
                        title: "安装目录",
                        detail: trimmed,
                        ok: false,
                        optional: false
                    )
                ],
                failureDetail: "安装目录不存在：\(trimmed)"
            )
            return
        }

        localArtifactValidation = LocalArtifactValidationState(
            checking: true,
            checked: false,
            ready: false,
            summary: "正在校验本地安装资源...",
            items: []
        )

        Task {
            let state = await validateLocalArtifactsDirectory(at: trimmed)
            localArtifactValidation = state
            _ = showFailureDetails
        }
    }

    private func validateLocalArtifactsDirectory(at path: String) async -> LocalArtifactValidationState {
        struct ArtifactManifest: Decodable {
            let official_image: String?
            let host_images: String?
            let official_workspace: String?
            let qt_host_tools: String?
            let official_image_size_bytes: Int64?
            let host_images_size_bytes: Int64?
            let official_workspace_size_bytes: Int64?
            let qt_host_tools_size_bytes: Int64?
        }

        let directoryURL = URL(fileURLWithPath: path)
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        let fileManager = FileManager.default
        let directoryEntries = (try? fileManager.contentsOfDirectory(atPath: path).sorted()) ?? []
        var items: [LocalArtifactValidationItem] = []
        var manifest: ArtifactManifest?

        if fileManager.fileExists(atPath: manifestURL.path) {
            do {
                let data = try Data(contentsOf: manifestURL)
                manifest = try JSONDecoder().decode(ArtifactManifest.self, from: data)
                items.append(.init(
                    title: "manifest.json",
                    detail: manifestURL.path,
                    ok: true,
                    optional: false
                ))
            } catch {
                items.append(.init(
                    title: "manifest.json",
                    detail: "解析失败：\(error.localizedDescription)",
                    ok: false,
                    optional: false
                ))
            }
        } else {
            items.append(.init(
                title: "manifest.json",
                detail: "未找到，将按文件名规则快速匹配资源包",
                ok: true,
                optional: true
            ))
        }

        let checks: [(title: String, required: Bool, names: [String], expectedSize: Int64?)] = {
            var list: [(String, Bool, [String], Int64?)] = []
            let imageCandidates = manifest?.official_image.map { [$0] } ?? []
            let hostImageCandidates = manifest?.host_images.map { [$0] } ?? []
            let workspaceCandidates = manifest?.official_workspace.map { [$0] } ?? []
            let qtCandidates = manifest?.qt_host_tools.map { [$0] } ?? []
            list.append(("共享镜像包", true, imageCandidates.isEmpty ? ["tspi-rk356x-env-*.tar.gz"] : imageCandidates, manifest?.official_image_size_bytes))
            list.append(("初始镜像包", true, hostImageCandidates.isEmpty ? ["tspi-img-*.tar.gz"] : hostImageCandidates, manifest?.host_images_size_bytes))
            list.append(("发布工作区包", true, workspaceCandidates.isEmpty ? ["official-workspace-*.tar.gz"] : workspaceCandidates, manifest?.official_workspace_size_bytes))
            list.append(("Qt 编译环境包", false, qtCandidates.isEmpty ? ["qt6Host-*.tar.gz", "qt6host-*.tar.gz"] : qtCandidates, manifest?.qt_host_tools_size_bytes))
            return list
        }()

        func matches(_ filename: String, pattern: String) -> Bool {
            let predicate = NSPredicate(format: "SELF LIKE[c] %@", pattern)
            return predicate.evaluate(with: filename)
        }

        func firstMatch(patterns: [String]) -> String? {
            for pattern in patterns {
                if !pattern.contains("*") {
                    let expanded = directoryURL.appendingPathComponent(pattern)
                    if fileManager.fileExists(atPath: expanded.path) {
                        return expanded.path
                    }
                }
                if let matched = directoryEntries.first(where: { matches($0, pattern: pattern) }) {
                    return directoryURL.appendingPathComponent(matched).path
                }
            }
            return nil
        }

        func validatePackage(_ filePath: String, expectedSize: Int64?) -> (Bool, String) {
            guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                  let actualSize = attrs[.size] as? NSNumber else {
                return (false, "无法读取文件")
            }
            if let expectedSize, expectedSize > 0, actualSize.int64Value != expectedSize {
                return (false, "大小不匹配，期望 \(expectedSize) 字节，实际 \(actualSize.int64Value) 字节")
            }
            return (true, filePath)
        }

        for check in checks {
            if let matched = firstMatch(patterns: check.names) {
                let validation = validatePackage(matched, expectedSize: check.expectedSize)
                items.append(.init(
                    title: check.title,
                    detail: validation.0 ? matched : "\(matched) (\(validation.1))",
                    ok: validation.0,
                    optional: !check.required
                ))
            } else {
                items.append(.init(
                    title: check.title,
                    detail: check.required ? "未找到匹配资源包" : "未提供，可跳过安装",
                    ok: !check.required,
                    optional: !check.required
                ))
            }
        }

        let requiredItems = items.filter { !$0.optional }
        let ready = requiredItems.allSatisfy(\.ok)
        let failureLines = items
            .filter { !$0.ok }
            .map { "• \($0.title)\n  \($0.detail)" }
            .joined(separator: "\n\n")
        return LocalArtifactValidationState(
            checking: false,
            checked: true,
            ready: ready,
            summary: ready ? "本地资源校验通过" : "本地资源校验未通过",
            items: items,
            failureDetail: failureLines
        )
    }

    var workspaceName: String {
        workspaceMode.displayName
    }

    var hasDevelopmentWorkspace: Bool {
        if let developmentRepoRoot {
            return Self.isValidRepoRoot(developmentRepoRoot)
        }
        return false
    }

    var fullDevelopmentEnvironmentReady: Bool {
        developmentInstallStatus.dockerReady &&
        developmentInstallStatus.officialImageReady &&
        developmentInstallStatus.releaseVolumeReady &&
        developmentInstallStatus.hostImagesReady &&
        developmentInstallStatus.rkflashtoolReady
    }

    var developmentInstallHeadline: String {
        if fullDevelopmentEnvironmentReady {
            return "发布环境已完整安装"
        }
        if developmentInstallStatus.dockerReady || developmentInstallStatus.officialImageReady || developmentInstallStatus.releaseVolumeReady || developmentInstallStatus.hostImagesReady {
            return "发布环境部分已安装"
        }
        return "发布环境尚未安装"
    }

    var updateConfigured: Bool {
        toolkitUpdateStatus.configured
    }

    var toolkitVersionText: String {
        toolkitUpdateStatus.currentVersion
    }

    var toolkitUpdateHeadline: String {
        if !toolkitUpdateStatus.configured {
            return "未配置远程更新地址"
        }
        if toolkitUpdateStatus.updateAvailable {
            return "发现新版本"
        }
        if !toolkitUpdateStatus.remoteVersion.isEmpty {
            return "当前已是最新版本"
        }
        return "等待检查更新"
    }

    var productDisplayName: String {
        "Development Board Toolchain"
    }

    var supportedBoards: [SupportedBoard] {
        boardCatalog
    }

    func supportedBoard(for boardID: String?) -> SupportedBoard? {
        guard let boardID else {
            return nil
        }
        return supportedBoards.first(where: { $0.id == boardID })
    }

    var currentLiveCandidate: DetectedBoardCandidate? {
        if let selectedDetectedCandidateID,
           let candidate = detectedBoardCandidates.first(where: { $0.id == selectedDetectedCandidateID })
        {
            return candidate
        }
        return detectedBoardCandidates.first
    }

    var liveDetectedBoard: SupportedBoard? {
        supportedBoard(for: currentLiveCandidate?.boardID)
    }

    var detectedBoard: SupportedBoard? {
        supportedBoard(for: connectedBoardID)
    }

    var preferredControlBoard: SupportedBoard? {
        supportedBoard(for: preferredControlBoardID)
    }

    var heroTargetBoard: SupportedBoard? {
        preferredControlBoard
    }

    var heroTargetDisplayName: String? {
        if let connectedBoardDisplayName, !connectedBoardDisplayName.isEmpty, detectedBoard != nil {
            return connectedBoardDisplayName
        }
        guard let board = heroTargetBoard ?? liveDetectedBoard else {
            return nil
        }
        switch board.id {
        case "TaishanPi":
            return "泰山派（1M-RK3566）"
        default:
            return board.displayName
        }
    }

    var heroTargetMatchesLiveBoard: Bool {
        guard let targetBoard = heroTargetBoard,
              let liveBoard = liveDetectedBoard
        else {
            return false
        }
        return targetBoard.id == liveBoard.id
    }

    var detectedHardwareDisplayName: String? {
        if let connectedBoardDisplayName, !connectedBoardDisplayName.isEmpty {
            return connectedBoardDisplayName
        }
        guard let board = detectedBoard ?? liveDetectedBoard else {
            return nil
        }
        switch board.id {
        case "TaishanPi":
            return "泰山派（1M-RK3566）"
        default:
            return board.displayName
        }
    }

    var isWaitingForHardware: Bool {
        detectedBoardCandidates.isEmpty
    }

    var isShowingBoardCatalog: Bool {
        showingSupportedBoardCatalog || connectedBoardID == nil
    }

    var heroState: ToolkitHeroState {
        if !isShowingBoardCatalog {
            return .pluginHub
        }
        guard heroTargetBoard != nil else {
            return .pluginHub
        }
        return heroTargetMatchesLiveBoard ? .deviceReady : .deviceClose
    }

    var heroBadgeTitle: String {
        switch heroState {
        case .pluginHub:
            return "PLUGIN HUB"
        case .deviceReady:
            return "DEVICE READY"
        case .deviceClose:
            return "DEVICE CLOSE"
        }
    }

    var heroActionAvailable: Bool {
        if !isShowingBoardCatalog {
            return true
        }
        return heroTargetBoard != nil
    }

    var heroActionHint: String {
        if !isShowingBoardCatalog {
            return "点击返回初始化列表"
        }
        if heroTargetBoard != nil {
            return "点击切换到设备控制页面"
        }
        return ""
    }

    var headerSubtitle: String {
        if !isShowingBoardCatalog {
            return "点击返回初始化列表页面"
        }
        if detectedBoardCandidates.count > 1 {
            return "已检测到 \(detectedBoardCandidates.count) 个硬件设备，请先选择要连接的设备。"
        }
        if let board = heroTargetBoard, preferredControlBoardID != nil || connectedBoardID != nil {
            return "\(heroTargetDisplayName ?? board.displayName) · \(heroTargetMatchesLiveBoard ? "设备在线" : "设备未连接")"
        }
        if let board = liveDetectedBoard {
            return "当前已识别：\(detectedHardwareDisplayName ?? board.displayName) · \(board.manufacturer)"
        }
        return "请连接硬件设备，目前支持的硬件设备如下列表："
    }

    var deviceConnectionText: String {
        switch status?.usb?.mode ?? "absent" {
        case "loader":
            return "Loader 模式"
        case "usb-ecm":
            return status?.usbnet?.configured == true ? "USB 网口已连接" : "USB 网口待配置"
        case "rockchip-other":
            return "USB 已连接"
        case "absent":
            return "等待连接"
        default:
            return status?.usb?.mode ?? "待识别"
        }
    }

    var deviceReachabilityText: String {
        guard liveDetectedBoard != nil else {
            return "未连接任何硬件设备"
        }
        if status?.board?.control_service == true {
            return "控制服务正常"
        }
        if status?.board?.ssh_port_open == true {
            return "SSH 可连接"
        }
        if status?.board?.ping == true {
            return "开发板在线"
        }
        if status?.usb?.mode == "loader" {
            return "等待系统启动"
        }
        return "已检测到设备"
    }

    func isInstallerTask(_ task: ToolkitTask?) -> Bool {
        guard let action = task?.action else {
            return false
        }
        return action == "release-build-image" ||
            action == "release-check-env" ||
            action == "release-install-environment" ||
            action == "release-install-codex-plugin" ||
            action == "release-install-opencode-plugin" ||
            action == "release-seed-volume"
    }

    func isUpdaterTask(_ task: ToolkitTask?) -> Bool {
        guard let action = task?.action else {
            return false
        }
        return action == "release-update-toolkit" || action == "release-update-images"
    }

    func switchWorkspaceMode(_ mode: WorkspaceMode) {
        guard mode != workspaceMode else {
            return
        }
        guard mode != .development || hasDevelopmentWorkspace else {
            presentInlineError("当前未检测到开发版安装目录，无法切换到开发版。")
            return
        }
        workspaceMode = mode
        persistWorkspaceSelection()
        restartServiceForWorkspaceModeSwitch()
    }

    var statusHeadline: String {
        if detectedBoardCandidates.count > 1 {
            return "检测到多个设备，等待选择"
        }
        guard let board = detectedBoard ?? liveDetectedBoard else {
            return "未连接任何硬件设备"
        }
        let stateText = liveDetectedBoard != nil ? deviceReachabilityText : "设备未连接"
        return "\(detectedHardwareDisplayName ?? board.displayName) / \(deviceConnectionText) / \(stateText)"
    }

    var lastUpdatedText: String {
        status?.updated_at ?? "未刷新"
    }

    var shouldShowUSBNetHelperBanner: Bool {
        guard status?.usb?.mode == "usb-ecm" else {
            return false
        }
        guard status?.host?.usbnet_helper_installed == false else {
            return false
        }
        return status?.usbnet?.configured != true
    }

    var taskOverlayVisible: Bool {
        !pendingTaskTitle.isEmpty || currentTask != nil || postFlashRecoveryActive
    }

    var taskOverlayBlocking: Bool {
        if postFlashRecoveryActive {
            return !postFlashRecoveryFinished
        }
        if !pendingTaskTitle.isEmpty {
            return true
        }
        guard let task = currentTask else {
            return false
        }
        return task.status != "finished"
    }

    var menuBarStatusColor: Color {
        if !localAgentRunning {
            return .orange
        }
        switch status?.usb?.mode ?? "absent" {
        case "loader":
            return .blue
        case "usb-ecm":
            return status?.board?.ping == true ? .green : .orange
        case "absent":
            return .secondary
        default:
            return .orange
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let ok: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(ok ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ActionTile: View {
    let title: String
    let subtitle: String
    let enabled: Bool
    let disabledReason: String?
    let action: () -> Void
    var compact: Bool = false
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                Text(title)
                    .font((compact ? Font.system(size: 12, weight: .semibold) : .subheadline.weight(.semibold)))
                    .lineLimit(1)
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)
                if !compact {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    if let disabledReason, !enabled {
                        Text(disabledReason)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 34 : 62, alignment: .topLeading)
            .padding(.horizontal, compact ? 9 : 10)
            .padding(.vertical, compact ? 7 : 10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(disabledReason ?? subtitle)
        .onHover { hovering in
            self.hovering = hovering
        }
    }

    private var backgroundColor: Color {
        if !enabled {
            return Color.secondary.opacity(0.10)
        }
        if hovering {
            return Color.accentColor.opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if !enabled {
            return Color.orange.opacity(0.22)
        }
        return hovering ? Color.accentColor.opacity(0.28) : Color.clear
    }
}

struct ActivityRow: View {
    let entry: ActivityEntry
    let onDetail: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.level.symbol)
                .foregroundStyle(entry.level.color)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title)
                        .font(.headline)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.subheadline)
                if entry.detail != nil {
                    Button("查看详情", action: onDetail)
                        .buttonStyle(.link)
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OverviewTab: View {
    @ObservedObject var vm: ToolkitViewModel
    private let statusColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]
    private let actionColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let checkHostState = vm.actionAvailabilityState(for: .checkHost)
            let ensureUSBNetState = vm.actionAvailabilityState(for: .ensureUSBNet)
            let authorizeKeyState = vm.actionAvailabilityState(for: .authorizeKey)
            let rebootLoaderState = vm.actionAvailabilityState(for: .rebootLoader)
            if vm.shouldShowUSBNetHelperBanner {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("主机网络权限未安装")
                            .font(.subheadline.weight(.semibold))
                        Text("未安装前，板子重启后 Mac 无法自动把 USB ECM 地址恢复到 198.19.77.2。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("安装并修复") { vm.installUSBNetHelper() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            LazyVGrid(columns: statusColumns, spacing: 6) {
                StatusCard(title: "USB 模式", value: vm.status?.usb?.mode ?? "-", ok: (vm.status?.usb?.mode ?? "") != "absent")
                StatusCard(title: "USB 设备", value: vm.status?.usb?.product ?? "-", ok: true)
                StatusCard(title: "主机网口", value: vm.status?.usbnet?.iface ?? "-", ok: vm.status?.usbnet?.configured == true)
                StatusCard(title: "设备 IP", value: vm.status?.usbnet?.board_ip ?? "-", ok: vm.status?.usbnet?.configured == true)
                StatusCard(title: "板卡 Ping", value: vm.status?.board?.ping == true ? "在线" : "离线", ok: vm.status?.board?.ping == true)
                StatusCard(title: "SSH", value: vm.status?.board?.ssh_port_open == true ? "可连接" : "未连接", ok: vm.status?.board?.ssh_port_open == true)
                StatusCard(title: "控制服务", value: vm.status?.board?.control_service == true ? "正常" : "未响应", ok: vm.status?.board?.control_service == true)
                StatusCard(title: "Docker", value: vm.status?.host?.docker_daemon == true ? "已就绪" : "未启动", ok: vm.status?.host?.docker_daemon == true)
            }

            GroupBox("连接与准备") {
                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionTile(title: "主机预检", subtitle: "检查 Docker、镜像和刷机工具状态", enabled: checkHostState.enabled, disabledReason: checkHostState.reason) { vm.checkHost() }
                    ActionTile(title: "恢复 USB 网络", subtitle: "修复 USB ECM 重枚举后的主机静态 IP", enabled: ensureUSBNetState.enabled, disabledReason: ensureUSBNetState.reason) { vm.ensureUSBNet() }
                    ActionTile(title: "授权 SSH", subtitle: "把当前电脑公钥写入开发板", enabled: authorizeKeyState.enabled, disabledReason: authorizeKeyState.reason) { vm.authorizeKey() }
                    ActionTile(title: "切换 Loader", subtitle: "通过 usb0 控制服务让开发板进入 Loader", enabled: rebootLoaderState.enabled, disabledReason: rebootLoaderState.reason) { vm.rebootLoader() }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FlashTab: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            flashSection(
                title: "用户镜像刷写",
                source: .custom,
                emptyState: "未发现用户镜像，请先生成或导入。"
            )

            flashSection(
                title: "初始镜像恢复",
                source: .factory,
                emptyState: "缺少初始镜像时会先自动同步。"
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func flashSection(
        title: String,
        source: FlashImageSource,
        emptyState: String
    ) -> some View {
        let flashAllState = vm.flashAvailabilityState(for: "all", source: source)
        let flashBootState = vm.flashAvailabilityState(for: "boot", source: source)
        let flashRootfsState = vm.flashAvailabilityState(for: "rootfs", source: source)
        let flashUserdataState = vm.flashAvailabilityState(for: "userdata", source: source)
        let imageDir = vm.imageDirURL(for: source)
        let hasImages = vm.hasAnyFlashableImage(source: source)
        let summaryState = [flashAllState, flashBootState, flashRootfsState, flashUserdataState].first(where: { !$0.enabled })
        let stateText = hasImages ? "\(source.displayName)已就绪，可直接刷写。" : emptyState
        let dotColor = source == .custom ? Color.orange : Color.green

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .help(summaryState?.reason ?? stateText)
                    Spacer(minLength: 6)
                    Text(relativePathLabel(imageDir))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(imageDir.path)
                }

                HStack(spacing: 6) {
                    ActionTile(
                        title: source == .custom ? "全部" : "恢复全部",
                        subtitle: "按 parameter 刷写全部分区",
                        enabled: flashAllState.enabled,
                        disabledReason: flashAllState.reason,
                        action: { vm.flash("all", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Boot",
                        subtitle: "仅刷 boot",
                        enabled: flashBootState.enabled,
                        disabledReason: flashBootState.reason,
                        action: { vm.flash("boot", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Rootfs",
                        subtitle: "仅刷 rootfs",
                        enabled: flashRootfsState.enabled,
                        disabledReason: flashRootfsState.reason,
                        action: { vm.flash("rootfs", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Userdata",
                        subtitle: "仅刷 userdata",
                        enabled: flashUserdataState.enabled,
                        disabledReason: flashUserdataState.reason,
                        action: { vm.flash("userdata", source: source) },
                        compact: true
                    )
                }
                .help(summaryState?.reason ?? imageDir.path)
            }
            .padding(.top, 2)
        }
        .groupBoxStyle(.automatic)
    }

    private func relativePathLabel(_ url: URL) -> String {
        let root = vm.imagesRootURL().path
        let full = url.path
        if full.hasPrefix(root) {
            let relative = String(full.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relative.isEmpty ? "images" : "images/\(relative)"
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        let suffix = parts.suffix(4).joined(separator: "/")
        return parts.count > 4 ? "…/\(suffix)" : full
    }
}

struct InstallStatusRow: View {
    let title: String
    let detail: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(ok ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ReleaseHeroCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(badgeColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(badgeColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(badgeText)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeColor.opacity(0.12))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.primary.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct HoverFlipActionCard<Front: View, Back: View>: View {
    let action: () -> Void
    let front: Front
    let back: Back
    @State private var hovering = false

    init(
        action: @escaping () -> Void,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self.action = action
        self.front = front()
        self.back = back()
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                front
                    .opacity(hovering ? 0 : 1)
                    .rotation3DEffect(.degrees(hovering ? -88 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                back
                    .opacity(hovering ? 1 : 0)
                    .rotation3DEffect(.degrees(hovering ? 0 : 88), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                hovering = inside
            }
        }
    }
}

struct ReleaseStateCard: View {
    let title: String
    let detail: String
    let ok: Bool
    let helpText: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let actionEnabled: Bool
    let actionEmphasized: Bool
    let actionSoft: Bool

    init(
        title: String,
        detail: String,
        ok: Bool,
        helpText: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        actionEnabled: Bool = true,
        actionEmphasized: Bool = false,
        actionSoft: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.ok = ok
        self.helpText = helpText
        self.actionTitle = actionTitle
        self.action = action
        self.actionEnabled = actionEnabled
        self.actionEmphasized = actionEmphasized
        self.actionSoft = actionSoft
    }

    var tint: Color { ok ? .green : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, actionEmphasized ? 12 : 0)
                        .padding(.vertical, actionEmphasized ? 7 : 0)
                        .background(
                            Group {
                                if actionEmphasized {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            actionEnabled
                                                ? (actionSoft ? Color.accentColor.opacity(0.12) : Color.accentColor)
                                                : Color.secondary.opacity(0.12)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    actionEnabled
                                                        ? (actionSoft ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(0.2))
                                                        : Color.secondary.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(
                                            color: actionEnabled && !actionSoft ? Color.black.opacity(0.18) : .clear,
                                            radius: 6,
                                            x: 0,
                                            y: 3
                                        )
                                }
                            }
                        )
                        .foregroundStyle(actionEmphasized ? (actionSoft ? Color.accentColor : Color.white) : Color.accentColor)
                        .opacity(actionEnabled ? 1 : 0.6)
                        .disabled(!actionEnabled)
                }
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .help(helpText ?? detail)
    }
}

struct ArtifactValidationRow: View {
    let item: LocalArtifactValidationItem

    var tint: Color {
        if item.ok {
            return item.optional ? .blue : .green
        }
        return .red
    }

    var symbol: String {
        if item.ok {
            return item.optional ? "checkmark.circle" : "checkmark.circle.fill"
        }
        return item.optional ? "minus.circle" : "xmark.octagon.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    if item.optional {
                        Text("可选")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(item.detail)
    }
}

struct InstallerPrimaryActionCard: View {
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button(secondaryTitle, action: secondaryAction)
                    .controlSize(.large)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct InstallerOfflineCard: View {
    let path: String
    let validation: LocalArtifactValidationState
    let chooseAction: () -> Void
    let installAction: () -> Void
    let detailAction: () -> Void

    private var summaryColor: Color {
        if validation.checking {
            return .secondary
        }
        if validation.ready {
            return .green
        }
        if validation.checked {
            return .red
        }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("离线安装")
                .font(.headline)
            Text("如已提前下载发布资源，可直接选择本地目录导入。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text(path.isEmpty ? "未选择本地安装包目录" : path)
                    .font(.caption)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button("选择目录", action: chooseAction)
                    .controlSize(.large)
            }

            HStack(spacing: 10) {
                Button("从本地文件安装", action: installAction)
                    .controlSize(.large)
                    .disabled(!validation.ready)
                Text("目录内应包含共享镜像、初始镜像和发布工作区归档，Qt 编译环境包可选。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Image(systemName: validation.ready ? "checkmark.seal.fill" : (validation.checked ? "exclamationmark.triangle.fill" : "folder.badge.questionmark"))
                    .foregroundStyle(summaryColor)
                Text(validation.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summaryColor)
                    .lineLimit(2)
                Spacer()
                if validation.checked && !validation.ready && !validation.failureDetail.isEmpty {
                    Button("查看详情", action: detailAction)
                        .controlSize(.small)
                }
                if validation.checking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 208, maxHeight: 208, alignment: .topLeading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ReleaseLogConsole: View {
    let title: String
    let statusText: String
    let running: Bool
    let progressValue: Double?
    let lines: [String]
    let logHeight: CGFloat
    let maxLines: Int

    private var visibleLines: [String] {
        Array(lines.suffix(maxLines))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(statusText.isEmpty ? "等待操作" : statusText)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if running {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let progressValue {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView(value: progressValue, total: 1.0)
                            .progressViewStyle(.linear)
                        Text("\(Int(progressValue * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: logHeight, maxHeight: logHeight)
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .foregroundStyle(Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: logHeight + 92, maxHeight: logHeight + 92, alignment: .topLeading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

struct ToolkitInfoRowData: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
    let tint: Color
}

struct ToolkitInfoSectionData: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let summary: String
    let rows: [ToolkitInfoRowData]
}

enum ToolkitInfoPage {
    case version(appVersion: String, buildVersion: String)
    case features
    case contact

    var windowTitle: String {
        switch self {
        case .version:
            return "版本信息"
        case .features:
            return "功能说明"
        case .contact:
            return "联系方式"
        }
    }

    var preferredSize: NSSize {
        switch self {
        case .version:
            return NSSize(width: 640, height: 620)
        case .features:
            return NSSize(width: 660, height: 720)
        case .contact:
            return NSSize(width: 560, height: 560)
        }
    }

    var accentColor: Color {
        switch self {
        case .version:
            return Color(red: 0.05, green: 0.45, blue: 0.78)
        case .features:
            return Color(red: 0.06, green: 0.55, blue: 0.38)
        case .contact:
            return Color(red: 0.80, green: 0.42, blue: 0.10)
        }
    }

    var heroTitle: String {
        switch self {
        case .version:
            return "Development Board Toolchain"
        case .features:
            return "功能说明"
        case .contact:
            return "联系方式"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .version:
            return "面向多种开发板的 macOS 常驻控制台，统一承载连接、刷写、发布与维护入口。"
        case .features:
            return "围绕开发板连接、刷写、发布和现场维护整理出的图形化能力入口。"
        case .contact:
            return "用于问题反馈、功能建议和维护支持的统一入口。欢迎通过邮箱联系，也可以通过下方二维码支持后续迭代。"
        }
    }

    var badgeText: String {
        switch self {
        case let .version(appVersion, buildVersion):
            return "v\(appVersion) · build \(buildVersion)"
        case .features:
            return "四类核心能力"
        case .contact:
            return "反馈与支持"
        }
    }

    var footerText: String {
        switch self {
        case .version:
            return "版本页用于查看当前安装包构建信息与工具覆盖范围。"
        case .features:
            return "功能页概览 GUI 已集成能力，具体执行入口仍在状态栏菜单和主面板中。"
        case .contact:
            return "感谢支持 Development Board Toolchain。你的反馈和捐献都会直接用于后续维护、适配和体验优化。"
        }
    }

    var contactEmail: String? {
        switch self {
        case .contact:
            return "kong_w@foxmail.com"
        default:
            return nil
        }
    }

    var sections: [ToolkitInfoSectionData] {
        switch self {
        case let .version(appVersion, buildVersion):
            return [
                ToolkitInfoSectionData(
                    eyebrow: "当前构建",
                    title: "版本与运行形态",
                    summary: "当前安装包以状态栏应用运行，图形界面、本地控制服务和后台任务使用同一套执行链路。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "app.badge.fill",
                            title: "应用版本",
                            detail: "当前 GUI 版本为 v\(appVersion)，构建号为 \(buildVersion)，适用于 macOS 14 及以上环境。",
                            tint: accentColor
                        ),
                        ToolkitInfoRowData(
                            symbol: "server.rack",
                            title: "控制服务 API",
                            detail: "内置本地控制服务 API v2，GUI、CLI 和异步任务共用同一条命令执行与状态回传路径。",
                            tint: Color.orange
                        ),
                        ToolkitInfoRowData(
                            symbol: "menubar.rectangle",
                            title: "工作方式",
                            detail: "常驻状态栏运行，支持后台状态监测、任务跟踪、更新安装和操作回显。",
                            tint: Color.purple
                        ),
                    ]
                ),
                ToolkitInfoSectionData(
                    eyebrow: "工具定位",
                    title: "覆盖场景",
                    summary: "这一版 GUI 重点覆盖开发板在 macOS 下的连接管理、镜像刷写、开发联调和发布维护流程。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "cable.connector",
                            title: "设备连接",
                            detail: "统一查看 USB、USB ECM、SSH、控制服务和 Docker 状态，减少多窗口切换。",
                            tint: Color.green
                        ),
                        ToolkitInfoRowData(
                            symbol: "externaldrive.badge.checkmark",
                            title: "刷写与恢复",
                            detail: "支持整机刷写，也支持 Boot、Rootfs、Userdata 的分区级快速验证。",
                            tint: Color.blue
                        ),
                        ToolkitInfoRowData(
                            symbol: "slider.horizontal.3",
                            title: "发布定制",
                            detail: "支持启动 Logo、设备树、初始镜像资源与发布工作区管理。",
                            tint: Color.pink
                        ),
                    ]
                ),
            ]
        case .features:
            return [
                ToolkitInfoSectionData(
                    eyebrow: "监控与连接",
                    title: "统一状态总览",
                    summary: "把主机侧和板卡侧的关键连接状态收敛到一个常驻面板里，便于快速判断当前能执行什么操作。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "dot.scope",
                            title: "连接状态",
                            detail: "实时展示 USB 模式、USB ECM 配置、开发板 Ping、SSH 端口和控制服务可达性。",
                            tint: Color.green
                        ),
                        ToolkitInfoRowData(
                            symbol: "shippingbox.circle",
                            title: "主机环境",
                            detail: "同时检查 Docker、共享镜像、rkflashtool 和发布资源是否准备完成。",
                            tint: Color.orange
                        ),
                        ToolkitInfoRowData(
                            symbol: "bell.badge",
                            title: "状态提醒",
                            detail: "连接变化、任务完成和异常情况会以界面提示或系统通知方式反馈。",
                            tint: Color.blue
                        ),
                    ]
                ),
                ToolkitInfoSectionData(
                    eyebrow: "刷写与定制",
                    title: "面向验证流程的快速操作",
                    summary: "针对开发和现场恢复最常见的动作做了图形化封装，降低命令行切换成本。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                            title: "整机与分区刷写",
                            detail: "支持按 parameter.txt 整机刷写，也支持 Boot、Rootfs、Userdata 的单独下发。",
                            tint: Color.red
                        ),
                        ToolkitInfoRowData(
                            symbol: "photo",
                            title: "启动 Logo 更新",
                            detail: "支持指定图片、旋转角度和显示比例，并可在更新后直接刷 Boot 分区。",
                            tint: Color.pink
                        ),
                        ToolkitInfoRowData(
                            symbol: "cpu",
                            title: "设备树更新",
                            detail: "支持选择 DTS 文件或目录进行增量更新，并联动 Boot 刷写验证。",
                            tint: Color.indigo
                        ),
                    ]
                ),
                ToolkitInfoSectionData(
                    eyebrow: "开发与发布",
                    title: "覆盖日常联调到交付准备",
                    summary: "把开发版构建同步、发布资源准备和插件安装收拢到 GUI 内，减少外部脚本依赖。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "hammer",
                            title: "开发版流程",
                            detail: "支持 build and sync、build-sync-flash 等高频联调动作，适合快速验证迭代。",
                            tint: Color.orange
                        ),
                        ToolkitInfoRowData(
                            symbol: "shippingbox.fill",
                            title: "发布环境安装",
                            detail: "支持共享镜像、发布工作区、初始镜像和辅助插件的准备与检查。",
                            tint: Color.green
                        ),
                        ToolkitInfoRowData(
                            symbol: "arrow.down.circle",
                            title: "软件与镜像更新",
                            detail: "支持软件更新检查、GUI 安装包替换和初始镜像资源同步。",
                            tint: Color.blue
                        ),
                    ]
                ),
                ToolkitInfoSectionData(
                    eyebrow: "后台能力",
                    title: "围绕稳定执行做的辅助机制",
                    summary: "GUI 不只是操作入口，还负责在后台维护本地服务、任务轮询和异常恢复。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "clock.arrow.circlepath",
                            title: "异步任务跟踪",
                            detail: "长任务通过本地服务异步执行，窗口中持续展示进度、日志和完成状态。",
                            tint: Color.teal
                        ),
                        ToolkitInfoRowData(
                            symbol: "arrow.triangle.2.circlepath",
                            title: "自动更新联动",
                            detail: "更新完成后会自动切换到新安装包，并重新拉起应用实例。",
                            tint: Color.purple
                        ),
                        ToolkitInfoRowData(
                            symbol: "wrench.and.screwdriver",
                            title: "故障恢复",
                            detail: "遇到旧版本地服务或状态流异常时，会自动重启服务并恢复监控链路。",
                            tint: Color.gray
                        ),
                    ]
                ),
            ]
        case .contact:
            return [
                ToolkitInfoSectionData(
                    eyebrow: "联系作者",
                    title: "问题反馈与功能建议",
                    summary: "如果你在安装、刷写、联机调试或版本升级过程中遇到问题，或者希望补充新功能，可以直接通过邮箱联系。",
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "envelope.badge.fill",
                            title: "联系邮箱",
                            detail: "kong_w@foxmail.com",
                            tint: accentColor
                        ),
                        ToolkitInfoRowData(
                            symbol: "bubble.left.and.bubble.right.fill",
                            title: "反馈内容建议",
                            detail: "建议附上当前版本、操作步骤、异常截图和日志信息，这样可以更快定位问题。",
                            tint: Color.blue
                        ),
                        ToolkitInfoRowData(
                            symbol: "hammer.circle.fill",
                            title: "维护支持",
                            detail: "如果这套工具对你的开发或交付流程有帮助，可以通过下方二维码支持后续维护与优化。",
                            tint: Color.green
                        ),
                    ]
                ),
            ]
        }
    }
}

struct ToolkitInfoLogoView: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    init(size: CGFloat = 116, cornerRadius: CGFloat = 24) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    private var logoImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "AppInfoLogo", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Group {
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.06)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: size * 0.33, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct ToolkitInfoHeroCard: View {
    let page: ToolkitInfoPage

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(page.windowTitle)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(page.accentColor)
                    .textCase(.uppercase)
                Text(page.heroTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(page.heroSubtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.badgeText)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(page.accentColor.opacity(0.12))
                    .foregroundStyle(page.accentColor)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
            ToolkitInfoLogoView()
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    page.accentColor.opacity(0.18),
                    Color.primary.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
        )
    }
}

struct ToolkitInfoRowCard: View {
    let row: ToolkitInfoRowData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(row.tint.opacity(0.12))
                Image(systemName: row.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(row.tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(row.detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ToolkitInfoSectionCard: View {
    let section: ToolkitInfoSectionData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(section.eyebrow)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(section.title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Text(section.summary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(section.rows) { row in
                    ToolkitInfoRowCard(row: row)
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToolkitBundledImageView: View {
    let resourceName: String
    let resourceExtension: String
    let fallbackSymbol: String

    private var image: NSImage? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ToolkitContactEmailCard: View {
    let email: String
    let accentColor: Color
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("联系邮箱", systemImage: "envelope.fill")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(accentColor)

                Spacer()

                if didCopy {
                    Label("复制成功", systemImage: "checkmark.circle.fill")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.green)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            Text(email)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                if let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) {
                        Label("发送邮件", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(email, forType: .string)
                    withAnimation(.easeOut(duration: 0.18)) {
                        didCopy = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            didCopy = false
                        }
                    }
                } label: {
                    Label("复制邮箱", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.14),
                    Color.primary.opacity(0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToolkitDonationQRCodeCard: View {
    let title: String
    let subtitle: String
    let resourceName: String
    let resourceExtension: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Spacer()
                Text(subtitle)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12))
                    .foregroundStyle(accentColor)
                    .clipShape(Capsule())
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                ToolkitBundledImageView(
                    resourceName: resourceName,
                    resourceExtension: resourceExtension,
                    fallbackSymbol: "qrcode"
                )
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToolkitDonationHintCard: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("如果这套工具对你有帮助，欢迎捐赠支持 ☕️")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)

            Text("你的支持会直接用于项目持续更新、功能打磨与体验优化 ❤️")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ToolkitContactWindowView: View {
    let page: ToolkitInfoPage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let email = page.contactEmail {
                ToolkitContactEmailCard(email: email, accentColor: page.accentColor)
            }

            ToolkitDonationHintCard(accentColor: page.accentColor)

            HStack(alignment: .top, spacing: 14) {
                ToolkitDonationQRCodeCard(
                    title: "支付宝",
                    subtitle: "Alipay",
                    resourceName: "ContactAlipay",
                    resourceExtension: "jpg",
                    accentColor: page.accentColor
                )
                ToolkitDonationQRCodeCard(
                    title: "微信",
                    subtitle: "WeChat",
                    resourceName: "ContactWeChat",
                    resourceExtension: "jpg",
                    accentColor: Color.green
                )
            }
        }
        .padding(18)
        .frame(
            minWidth: page.preferredSize.width,
            minHeight: page.preferredSize.height,
            alignment: .topLeading
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ToolkitDonationPanel: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("捐献支持")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("如果这套工具对你有帮助")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Text("可以通过下面二维码支持后续维护与更新。两个二维码展示区域保持一致尺寸，便于快速扫码。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 16) {
                ToolkitDonationQRCodeCard(
                    title: "支付宝",
                    subtitle: "Alipay",
                    resourceName: "ContactAlipay",
                    resourceExtension: "jpg",
                    accentColor: accentColor
                )
                ToolkitDonationQRCodeCard(
                    title: "微信",
                    subtitle: "WeChat",
                    resourceName: "ContactWeChat",
                    resourceExtension: "jpg",
                    accentColor: Color.green
                )
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToolkitInfoWindowView: View {
    let page: ToolkitInfoPage

    var body: some View {
        Group {
            if case .contact = page {
                ToolkitContactWindowView(page: page)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ToolkitInfoHeroCard(page: page)

                        ForEach(page.sections) { section in
                            ToolkitInfoSectionCard(section: section)
                        }

                        Text(page.footerText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }
            }
        }
        .frame(minWidth: page.preferredSize.width, minHeight: page.preferredSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct DevelopmentInstallPanelView: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard?
    let embedded: Bool
    @State private var showLocalValidationDetail = false
    @State private var localValidationDetail = ""

    var installTaskVisible: Bool {
        vm.pendingTaskTitle.contains("发布环境全量安装") ||
            vm.pendingTaskTitle.contains("发布环境本地安装") ||
            vm.pendingTaskTitle.contains("Volume") ||
            vm.pendingTaskTitle.contains("镜像") ||
            vm.isInstallerTask(vm.currentTask)
    }

    var installTaskRunning: Bool {
        if !vm.pendingTaskTitle.isEmpty {
            return true
        }
        return vm.currentTask?.status != "finished" && vm.isInstallerTask(vm.currentTask)
    }

    private var boardSupportsDevelopmentInstall: Bool {
        guard let board else {
            return false
        }
        return vm.boardSupportsDevelopmentEnvironment(board.id, variantID: vm.activeVariantID(for: board.id))
    }

    private var headerTitle: String {
        embedded ? "开发环境安装" : "发布环境安装"
    }

    private var headerSubtitle: String {
        if boardSupportsDevelopmentInstall {
            if let board {
                return "为 \(board.displayName) 准备共享镜像、发布工作区和初始镜像资源。"
            }
            return "自动准备共享镜像、发布工作区和初始镜像资源。"
        }
        if let board,
           let metadata = vm.installedBoardToolingMetadata(board.id),
           metadata.require_explicit_variant_confirmation,
           vm.activeVariantID(for: board.id) == nil
        {
            return "当前开发板插件要求先明确具体板型，确认后才能匹配对应的开发环境与部署参数。"
        }
        return "当前开发板插件已安装，但这一板型的开发环境安装链路尚未接入。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: embedded ? 8 : 10) {
            Group {
                if boardSupportsDevelopmentInstall {
                    HoverFlipActionCard(
                        action: {
                            Task { await vm.refreshDevelopmentInstallStatus() }
                        },
                        front: {
                            ReleaseHeroCard(
                                symbol: "shippingbox.circle.fill",
                                title: headerTitle,
                                subtitle: headerSubtitle,
                                badgeText: vm.developmentInstallHeadline,
                                badgeColor: vm.fullDevelopmentEnvironmentReady ? .green : .accentColor
                            )
                        },
                        back: {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.16))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("重新检查")
                                        .font(.title3.weight(.semibold))
                                    Text("刷新开发环境安装状态，并同步 Docker、镜像与插件检查结果。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("点击执行")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.14))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                            .padding(18)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.12),
                                        Color.accentColor.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    )
                    .help("点击重新检查开发环境安装状态")
                } else {
                    ReleaseHeroCard(
                        symbol: "shippingbox.circle.fill",
                        title: headerTitle,
                        subtitle: headerSubtitle,
                        badgeText: vm.developmentInstallHeadline,
                        badgeColor: vm.fullDevelopmentEnvironmentReady ? .green : .accentColor
                    )
                }
            }

            if boardSupportsDevelopmentInstall {
                HStack(spacing: 12) {
                    ReleaseStateCard(
                        title: "运行环境",
                        detail: vm.developmentInstallStatus.dockerReady && vm.developmentInstallStatus.officialImageReady ? "Docker 与共享镜像已就绪" : "需要准备 Docker 和共享镜像",
                        ok: vm.developmentInstallStatus.dockerReady && vm.developmentInstallStatus.officialImageReady,
                        helpText: """
                        Docker Desktop: \(vm.developmentInstallStatus.dockerReady ? "已启动" : "未就绪")
                        共享镜像: \(vm.developmentInstallStatus.officialImageReady ? "已安装" : "未安装")
                        镜像名: \(vm.officialImageName)
                        """
                    )
                    ReleaseStateCard(
                        title: "发布工作区",
                        detail: vm.developmentInstallStatus.releaseVolumeReady ? "发布工作区 Volume 已可用" : "将自动导入发布工作区",
                        ok: vm.developmentInstallStatus.releaseVolumeReady,
                        helpText: """
                        Docker Volume: \(vm.officialVolumeName)
                        工作区模式: 发布版
                        """
                    )
                    ReleaseStateCard(
                        title: "初始镜像",
                        detail: vm.developmentInstallStatus.hostImagesReady && vm.developmentInstallStatus.rkflashtoolReady ? "初始镜像缓存与刷机工具已就绪" : "将自动同步初始镜像并准备刷机工具",
                        ok: vm.developmentInstallStatus.hostImagesReady && vm.developmentInstallStatus.rkflashtoolReady,
                        helpText: """
                        镜像目录: \(vm.factoryImageDirURL().path)
                        初始镜像缓存: \(vm.developmentInstallStatus.hostImagesReady ? "已就绪" : "未就绪")
                        rkflashtool-mac: \(vm.developmentInstallStatus.rkflashtoolReady ? "已就绪" : "未就绪")
                        """
                    )
                }
                .padding(.top, 8)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI 插件（可选）")
                            .font(.headline)
                        HStack(spacing: 12) {
                            ReleaseStateCard(
                                title: "Codex 插件",
                                detail: vm.developmentInstallStatus.codexPluginInstalled ? "已安装，可直接在 Codex 中调用开发板工具链" : "未安装，可从当前应用直接安装",
                                ok: vm.developmentInstallStatus.codexPluginInstalled,
                                helpText: """
                                Codex 环境: \(vm.developmentInstallStatus.codexAvailable ? "已检测到" : "未检测到")
                                插件状态: \(vm.developmentInstallStatus.codexPluginInstalled ? "已安装" : "未安装")
                                """,
                                actionTitle: vm.developmentInstallStatus.codexPluginInstalled ? "重新安装" : "安装",
                                action: { vm.installCodexPlugin() },
                                actionEnabled: vm.developmentInstallStatus.codexAvailable,
                                actionEmphasized: true,
                                actionSoft: true
                            )
                            ReleaseStateCard(
                                title: "OpenCode 插件",
                                detail: vm.developmentInstallStatus.openCodePluginInstalled ? "已安装，可直接在 OpenCode 中调用开发板工具链" : "未安装，可从当前应用直接安装",
                                ok: vm.developmentInstallStatus.openCodePluginInstalled,
                                helpText: """
                                OpenCode 环境: \(vm.developmentInstallStatus.openCodeAvailable ? "已检测到" : "未检测到")
                                npm: \(vm.developmentInstallStatus.npmReady ? "已检测到" : "未检测到")
                                插件状态: \(vm.developmentInstallStatus.openCodePluginInstalled ? "已安装" : "未安装")
                                """,
                                actionTitle: vm.developmentInstallStatus.openCodePluginInstalled ? "重新安装" : "安装",
                                action: { vm.installOpenCodePlugin() },
                                actionEnabled: vm.developmentInstallStatus.openCodeAvailable && vm.developmentInstallStatus.npmReady,
                                actionEmphasized: true,
                                actionSoft: true
                            )
                        }
                    }
                }
                .padding(.top, 4)

                InstallerOfflineCard(
                    path: vm.localArtifactsDir,
                    validation: vm.localArtifactValidation,
                    chooseAction: { vm.browseDirectory { path in
                        vm.localArtifactsDir = path
                        vm.validateLocalArtifactsDirectory(showFailureDetails: true)
                    } },
                    installAction: { vm.installFullDevelopmentEnvironmentFromLocal() },
                    detailAction: {
                        localValidationDetail = vm.localArtifactValidation.failureDetail
                        showLocalValidationDetail = true
                    }
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前开发板插件已安装，但开发环境安装链路尚未接入这一型号。")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    Text("目前这套发布环境安装流程仍然优先适配泰山派（1M-RK3566）。后续会按开发板插件能力继续拆分与接入。")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        ReleaseStateCard(
                            title: "插件状态",
                            detail: "当前开发板插件已安装，可参与识别和页面切换。",
                            ok: true,
                            helpText: "插件版本: \(board.map { vm.boardPluginDisplayVersion($0.id) } ?? "-")"
                        )
                        ReleaseStateCard(
                            title: "环境接入",
                            detail: "开发环境安装功能待该板型接入后启用。",
                            ok: false,
                            helpText: "当前仅泰山派（1M-RK3566）已复用发布环境安装链路。"
                        )
                    }
                }
            }

            if !embedded {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, embedded ? 0 : 22)
        .padding(.top, embedded ? -6 : 14)
        .padding(.bottom, embedded ? 0 : 18)
        .overlay {
            if installTaskVisible && !embedded {
                TaskOverlayView(vm: vm)
            }
        }
        .sheet(isPresented: $showLocalValidationDetail) {
            VStack(alignment: .leading, spacing: 12) {
                Text("校验详情")
                    .font(.title3.weight(.semibold))
                ScrollView {
                    Text(localValidationDetail)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button("关闭") {
                        showLocalValidationDetail = false
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 560, minHeight: 320)
        }
        .onChange(of: vm.localArtifactValidation) { _, state in
            if state.checked, !state.ready, !state.failureDetail.isEmpty {
                localValidationDetail = state.failureDetail
                showLocalValidationDetail = true
            }
        }
        .task {
            guard boardSupportsDevelopmentInstall else {
                return
            }
            if !vm.localArtifactsDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.validateLocalArtifactsDirectory()
            }
            while !Task.isCancelled {
                await vm.refreshDevelopmentInstallStatus()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}

struct DevelopmentInstallWindowView: View {
    @ObservedObject var vm: ToolkitViewModel
    @State private var hostWindow: NSWindow?

    var installTaskRunning: Bool {
        if !vm.pendingTaskTitle.isEmpty {
            return true
        }
        return vm.currentTask?.status != "finished" && vm.isInstallerTask(vm.currentTask)
    }

    private func syncWindowClosePolicy() {
        guard let hostWindow else {
            return
        }
        let allowClose = !installTaskRunning
        hostWindow.standardWindowButton(.closeButton)?.isEnabled = allowClose
        hostWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = allowClose
    }

    var body: some View {
        DevelopmentInstallPanelView(vm: vm, board: nil, embedded: false)
            .frame(minWidth: 760, minHeight: 580)
            .background(
                WindowAccessor { window in
                    hostWindow = window
                    syncWindowClosePolicy()
                }
            )
            .onAppear {
                syncWindowClosePolicy()
            }
            .onChange(of: vm.currentTask?.status) { _, _ in
                syncWindowClosePolicy()
            }
            .onChange(of: vm.pendingTaskTitle) { _, _ in
                syncWindowClosePolicy()
            }
    }
}

struct ToolkitUpdateWindowView: View {
    @ObservedObject var vm: ToolkitViewModel

    var updateTaskVisible: Bool {
        vm.pendingTaskTitle == "软件更新" ||
            vm.pendingTaskTitle == "初始镜像更新" ||
            vm.isUpdaterTask(vm.currentTask)
    }

    var updateFlowRunning: Bool {
        updateTaskVisible || vm.automaticToolkitUpdateInProgress
    }

    var statusText: String {
        if updateTaskVisible {
            return vm.taskProgressLine(for: vm.currentTask)
        }
        return vm.updaterLastDetail
    }

    var logLines: [String] {
        if updateTaskVisible {
            return vm.taskTimelineLines(for: vm.currentTask)
        }
        return Array(vm.updaterLastDetail
            .split(separator: "\n")
            .map(String.init)
            .suffix(4))
    }

    var displayText: String {
        if updateFlowRunning {
            return statusText.isEmpty ? "正在联网检查更新..." : statusText
        }
        if !vm.updateConfigured {
            return "未配置远程更新地址"
        }
        if !vm.toolkitUpdateStatus.remoteVersion.isEmpty {
            return "当前版本 \(vm.toolkitUpdateStatus.currentVersion)，已经是最新版本"
        }
        return "等待检查更新"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            if let progress = vm.taskProgressValue(for: vm.currentTask), updateFlowRunning {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 320)
            } else if updateFlowRunning {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(width: 320)
            }

            Text(displayText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(minWidth: 420, minHeight: 150)
        .task {
            vm.startAutomaticToolkitUpdateFlow()
        }
    }
}

struct CustomizeTab: View {
    @ObservedObject var vm: ToolkitViewModel
    private let rotateOptions = ["-90", "0", "90", "180"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("启动 Logo") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(vm.logoPath.isEmpty ? "未选择 logo 文件" : vm.logoPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(vm.logoPath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("选择文件") { vm.browseFile { vm.logoPath = $0 } }
                    }
                    HStack {
                        Text("旋转角度")
                        Picker("旋转角度", selection: $vm.logoRotate) {
                            ForEach(rotateOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 92)
                        Text("比例")
                        TextField("100", text: $vm.logoScale)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text("%")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Toggle("更新后直接刷 Boot", isOn: $vm.logoFlashAfter)
                    HStack {
                        Spacer()
                        Button("执行 Logo 更新") { vm.updateLogo() }
                    }
                }
                .padding(.top, 8)
            }

            GroupBox("设备树") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(vm.dtsFilePath.isEmpty ? "未选择设备树文件" : vm.dtsFilePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(vm.dtsFilePath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("选择文件") { vm.browseFile { vm.dtsFilePath = $0 } }
                    }
                    HStack {
                        Toggle("更新后直接刷 Boot", isOn: $vm.dtsFlashAfter)
                        Spacer()
                        Button("执行设备树更新") { vm.updateDTB() }
                    }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ActivityTab: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = vm.selectedActivityEntry {
                HStack {
                    Button {
                        vm.selectedActivityEntry = nil
                    } label: {
                        Label("返回列表", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.title, systemImage: entry.level.symbol)
                        .font(.headline)
                        .foregroundStyle(entry.level.color)
                    Text(entry.message)
                        .font(.subheadline)
                    ScrollView {
                        Text(entry.detail ?? entry.message)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                if vm.activities.isEmpty {
                    Text("暂无活动记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(vm.activities.prefix(4))) { entry in
                        ActivityRow(entry: entry) {
                            vm.selectedActivityEntry = entry
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BoardThumbnailView: View {
    let board: SupportedBoard
    let size: CGSize
    let cornerRadius: CGFloat

    init(board: SupportedBoard, size: CGSize, cornerRadius: CGFloat = 14) {
        self.board = board
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [board.accentStart, board.accentEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: board.thumbnailSymbol)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(board.integrationReady ? "LIVE" : "PLAN")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)

                Text(board.thumbnailLabel)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(board.manufacturer)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.88)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(10)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct CapabilityChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private func boardModelRootURL(for board: SupportedBoard) -> URL? {
    guard let directoryName = board.modelDirectoryName else {
        return nil
    }
    let fm = FileManager.default
    let supportRoot = (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("development-board-toolchain/plugins", isDirectory: true))
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/development-board-toolchain/plugins", isDirectory: true)

    let sharedRuntimeRoot = ((fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("development-board-toolchain", isDirectory: true))
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/development-board-toolchain", isDirectory: true))
        .appendingPathComponent("runtime", isDirectory: true)

    let candidates: [URL] = [
        supportRoot
            .appendingPathComponent("user", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets/models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        supportRoot
            .appendingPathComponent("builtin", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets/models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        sharedRuntimeRoot
            .appendingPathComponent("builtin-plugin-seed", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets/models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
    ]

    for candidate in candidates where fm.fileExists(atPath: candidate.path) {
        return candidate
    }
    return nil
}

private func boardModelOBJURL(for board: SupportedBoard) -> URL? {
    guard let rootURL = boardModelRootURL(for: board),
          let contents = try? FileManager.default.contentsOfDirectory(
              at: rootURL,
              includingPropertiesForKeys: nil,
              options: [.skipsHiddenFiles]
          )
    else {
        return nil
    }
    if let preview = contents.first(where: { $0.lastPathComponent.lowercased() == "preview.obj" }) {
        return preview
    }
    return contents.first(where: { $0.pathExtension.lowercased() == "obj" })
}

private struct BoardModelPresentationProfile {
    let previewSize: CGFloat
    let previewBackground: [Color]
    let fieldOfView: CGFloat
    let verticalOffsetMultiplier: Float
    let cameraDistanceMultiplier: Float
    let minimumZoomFactor: CGFloat
    let maximumZoomFactor: CGFloat
    let ambientIntensity: CGFloat
    let keyIntensity: CGFloat
    let fillIntensity: CGFloat
    let modelScale: SCNVector3
}

private func boardModelPresentationProfile(for board: SupportedBoard) -> BoardModelPresentationProfile {
    switch board.id {
    case "ColorEasyPICO2":
        return BoardModelPresentationProfile(
            previewSize: 232,
            previewBackground: [
                Color(red: 0.22, green: 0.27, blue: 0.34),
                Color(red: 0.15, green: 0.19, blue: 0.26)
            ],
            fieldOfView: 42,
            verticalOffsetMultiplier: 0.42,
            cameraDistanceMultiplier: 1.20,
            minimumZoomFactor: 0.78,
            maximumZoomFactor: 1.30,
            ambientIntensity: 70,
            keyIntensity: 116,
            fillIntensity: 82,
            modelScale: SCNVector3(0.95, 0.95, 0.95)
        )
    default:
        return BoardModelPresentationProfile(
            previewSize: 232,
            previewBackground: [
                Color(red: 0.18, green: 0.23, blue: 0.31),
                Color(red: 0.12, green: 0.17, blue: 0.25)
            ],
            fieldOfView: 48,
            verticalOffsetMultiplier: 0.52,
            cameraDistanceMultiplier: 1.65,
            minimumZoomFactor: 0.74,
            maximumZoomFactor: 1.38,
            ambientIntensity: 95,
            keyIntensity: 150,
            fillIntensity: 105,
            modelScale: SCNVector3(1.0, 1.0, 1.0)
        )
    }
}

@MainActor
final class BoardSceneRepository {
    static let shared = BoardSceneRepository()

    private var cachedScenes: [String: SCNScene] = [:]
    private var loadingBoardIDs: Set<String> = []

    func cachedScene(for boardID: String) -> SCNScene? {
        cachedScenes[boardID]
    }

    func store(_ scene: SCNScene, for boardID: String) {
        cachedScenes[boardID] = scene
        loadingBoardIDs.remove(boardID)
    }

    func markLoading(_ boardID: String) -> Bool {
        if loadingBoardIDs.contains(boardID) {
            return false
        }
        loadingBoardIDs.insert(boardID)
        return true
    }

    func finishLoading(_ boardID: String) {
        loadingBoardIDs.remove(boardID)
    }
}

private extension SCNVector3 {
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: CGFloat) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    var length: CGFloat {
        CGFloat(sqrt((x * x) + (y * y) + (z * z)))
    }
}

final class CenteredZoomSCNView: SCNView {
    var allowsModelZoom = true
    var minimumCameraDistance: CGFloat = 0
    var maximumCameraDistance: CGFloat = .greatestFiniteMagnitude

    override func scrollWheel(with event: NSEvent) {
        guard allowsModelZoom else {
            return
        }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 6)
        defaultCameraController.dolly(toTarget: Float(delta) * 0.04)
        clampCameraDistanceIfNeeded()
    }

    private func clampCameraDistanceIfNeeded() {
        guard let pointOfView else {
            return
        }
        let target = defaultCameraController.target
        let offset = pointOfView.worldPosition - target
        let currentDistance = offset.length
        guard currentDistance > 0 else {
            return
        }
        let clampedDistance = min(max(currentDistance, minimumCameraDistance), maximumCameraDistance)
        guard abs(clampedDistance - currentDistance) > 0.001 else {
            return
        }
        let scaledOffset = offset * (clampedDistance / currentDistance)
        pointOfView.worldPosition = target + scaledOffset
        pointOfView.look(at: target)
    }
}

struct BoardModelSceneContainer: NSViewRepresentable {
    let board: SupportedBoard
    let allowsZoom: Bool
    let doubleClickAction: (() -> Void)?
    let onSceneReady: (() -> Void)?

    init(
        board: SupportedBoard,
        allowsZoom: Bool,
        doubleClickAction: (() -> Void)?,
        onSceneReady: (() -> Void)? = nil
    ) {
        self.board = board
        self.allowsZoom = allowsZoom
        self.doubleClickAction = doubleClickAction
        self.onSceneReady = onSceneReady
    }

    final class Coordinator {
        var boardID = ""
        let doubleClickAction: (() -> Void)?

        init(doubleClickAction: (() -> Void)?) {
            self.doubleClickAction = doubleClickAction
        }

        @objc func handleDoubleClick() {
            doubleClickAction?()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(doubleClickAction: doubleClickAction)
    }

    func makeNSView(context: Context) -> SCNView {
        let view = CenteredZoomSCNView(frame: .zero)
        view.allowsModelZoom = allowsZoom
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .clear
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.target = SCNVector3(0, 0, 0)
        view.defaultCameraController.worldUp = SCNVector3(0, 1, 0)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        let recognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick))
        recognizer.numberOfClicksRequired = 2
        recognizer.buttonMask = 0x1
        view.addGestureRecognizer(recognizer)
        context.coordinator.boardID = board.id
        if let cachedScene = BoardSceneRepository.shared.cachedScene(for: board.id) {
            applyScene(cachedScene, to: view)
            DispatchQueue.main.async {
                onSceneReady?()
            }
        } else {
            let placeholder = Self.placeholderScene(for: board)
            applyScene(placeholder, to: view)
            loadSceneAsync(for: board, into: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        if let zoomView = nsView as? CenteredZoomSCNView {
            zoomView.allowsModelZoom = allowsZoom
        }
        guard context.coordinator.boardID != board.id else {
            return
        }
        context.coordinator.boardID = board.id
        if let cachedScene = BoardSceneRepository.shared.cachedScene(for: board.id) {
            applyScene(cachedScene, to: nsView)
            DispatchQueue.main.async {
                onSceneReady?()
            }
        } else {
            let placeholder = Self.placeholderScene(for: board)
            applyScene(placeholder, to: nsView)
            loadSceneAsync(for: board, into: nsView, coordinator: context.coordinator)
        }
    }

    private func applyScene(_ scene: SCNScene, to view: SCNView) {
        view.scene = scene
        let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil })
        view.pointOfView = cameraNode
        if let zoomView = view as? CenteredZoomSCNView,
           let cameraNode
        {
            let profile = boardModelPresentationProfile(for: board)
            let baseDistance = (cameraNode.worldPosition - zoomView.defaultCameraController.target).length
            zoomView.minimumCameraDistance = baseDistance * profile.minimumZoomFactor
            zoomView.maximumCameraDistance = baseDistance * profile.maximumZoomFactor
        }
    }

    private func loadSceneAsync(for board: SupportedBoard, into view: SCNView, coordinator: Coordinator) {
        guard BoardSceneRepository.shared.markLoading(board.id) else {
            return
        }
        let boardID = board.id
        DispatchQueue.global(qos: .userInitiated).async {
            let scene = Self.buildScene(for: board)
            DispatchQueue.main.async {
                BoardSceneRepository.shared.store(scene, for: boardID)
                guard coordinator.boardID == boardID else {
                    return
                }
                applyScene(scene, to: view)
                onSceneReady?()
            }
        }
    }

    private static func buildScene(for board: SupportedBoard) -> SCNScene {
        guard let modelURL = boardModelOBJURL(for: board),
              let loadedScene = try? SCNScene(url: modelURL, options: nil)
        else {
            return placeholderScene(for: board)
        }

        let (minVec, maxVec) = loadedScene.rootNode.boundingBox
        let center = SCNVector3(
            (minVec.x + maxVec.x) * 0.5,
            (minVec.y + maxVec.y) * 0.5,
            (minVec.z + maxVec.z) * 0.5
        )

        let scene = SCNScene()
        let container = SCNNode()
        for child in loadedScene.rootNode.childNodes {
            container.addChildNode(child)
        }
        container.position = SCNVector3(-center.x, -center.y, -center.z)
        container.scale = boardModelPresentationProfile(for: board).modelScale
        Self.tuneMaterials(in: container, for: board)
        scene.rootNode.addChildNode(container)

        configureCameraAndLights(for: scene, board: board, target: SCNVector3(0, 0, 0))
        return scene
    }

    private static func placeholderScene(for board: SupportedBoard) -> SCNScene {
        let placeholder = SCNScene()
        configureCameraAndLights(for: placeholder, board: board, target: SCNVector3(0, 0, 0))
        return placeholder
    }

    private static func configureCameraAndLights(for scene: SCNScene, board: SupportedBoard, target: SCNVector3) {
        let profile = boardModelPresentationProfile(for: board)
        let (minVec, maxVec) = scene.rootNode.boundingBox
        let extentX = max(maxVec.x - minVec.x, 1)
        let extentY = max(maxVec.y - minVec.y, 1)
        let extentZ = max(maxVec.z - minVec.z, 1)
        let radius = max(extentX, max(extentY, extentZ))

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = Double(radius * 20)
        cameraNode.camera?.wantsHDR = false
        cameraNode.camera?.fieldOfView = profile.fieldOfView
        cameraNode.position = SCNVector3(
            target.x,
            target.y + radius * CGFloat(profile.verticalOffsetMultiplier),
            target.z + radius * CGFloat(profile.cameraDistanceMultiplier)
        )
        cameraNode.look(at: target)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = profile.ambientIntensity
        scene.rootNode.addChildNode(ambient)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = profile.keyIntensity
        keyLight.light?.castsShadow = true
        keyLight.position = SCNVector3(target.x + radius * 1.4, target.y + radius * 1.2, target.z + radius * 1.8)
        keyLight.eulerAngles = SCNVector3(-0.75, 0.72, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .omni
        fillLight.light?.intensity = profile.fillIntensity
        fillLight.position = SCNVector3(target.x - radius * 1.5, target.y + radius * 0.95, target.z - radius * 1.2)
        scene.rootNode.addChildNode(fillLight)
    }

    private static func tuneMaterials(in root: SCNNode, for board: SupportedBoard) {
        guard board.id == "ColorEasyPICO2" else {
            return
        }

        root.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else {
                return
            }

            for material in geometry.materials {
                guard let color = materialColor(from: material.diffuse.contents) else {
                    continue
                }

                let tuned = tunedColor(color, for: board)
                material.lightingModel = .physicallyBased
                material.diffuse.contents = tuned

                let brightness = ((tuned.redComponent + tuned.greenComponent + tuned.blueComponent) / 3.0)
                if brightness > 0.78 {
                    material.diffuse.intensity = 0.66
                    material.multiply.contents = NSColor(calibratedRed: 0.78, green: 0.83, blue: 0.90, alpha: 1)
                    material.roughness.contents = 0.92
                    material.metalness.contents = 0.04
                } else if tuned.redComponent > 0.55 && tuned.greenComponent > 0.42 && tuned.blueComponent < 0.35 {
                    material.diffuse.intensity = 0.92
                    material.roughness.contents = 0.48
                    material.metalness.contents = 0.58
                } else {
                    material.diffuse.intensity = 1.0
                    material.multiply.contents = NSColor.white
                    material.roughness.contents = 0.82
                    material.metalness.contents = 0.08
                }
            }
        }
    }

    private static func materialColor(from contents: Any?) -> NSColor? {
        if let color = contents as? NSColor {
            return color.usingColorSpace(.deviceRGB) ?? color
        }
        return nil
    }

    private static func tunedColor(_ color: NSColor, for board: SupportedBoard) -> NSColor {
        guard board.id == "ColorEasyPICO2" else {
            return color
        }

        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let maxComponent = max(red, max(green, blue))
        let minComponent = min(red, min(green, blue))
        let brightness = (red + green + blue) / 3.0
        let saturation = maxComponent - minComponent

        if brightness > 0.84 && saturation < 0.20 {
            return NSColor(calibratedRed: 0.58, green: 0.68, blue: 0.80, alpha: 1)
        }
        if brightness > 0.70 && saturation < 0.24 {
            return NSColor(calibratedRed: 0.48, green: 0.57, blue: 0.69, alpha: 1)
        }
        if red > 0.70 && green > 0.55 && blue < 0.35 {
            return NSColor(calibratedRed: 0.76, green: 0.58, blue: 0.18, alpha: 1)
        }
        if brightness < 0.16 {
            return NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.16, alpha: 1)
        }
        return color
    }
}

struct BoardModelPreviewCard: View {
    let board: SupportedBoard
    let doubleClickAction: (() -> Void)?

    private var presentationProfile: BoardModelPresentationProfile {
        boardModelPresentationProfile(for: board)
    }

    private var hasModel: Bool {
        boardModelOBJURL(for: board) != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                BoardModelSceneContainer(board: board, allowsZoom: false, doubleClickAction: doubleClickAction)
                    .frame(width: presentationProfile.previewSize, height: presentationProfile.previewSize)
                    .background(
                        LinearGradient(
                            colors: presentationProfile.previewBackground,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Text("拖动旋转，双击可弹出独立窗口查看。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("开发板 3D 视图", systemImage: "rotate.3d.fill")
                    .font(.system(.headline, design: .rounded).weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    Label(hasModel ? "模型已加载，可围绕板子中心旋转查看。" : "当前使用占位模型，等待真实 3D 资源。", systemImage: hasModel ? "cube.transparent.fill" : "shippingbox.fill")
                    Label("嵌入视图固定比例显示，双击后可在大图窗口中缩放。", systemImage: "plus.magnifyingglass")
                    Label("背景和灯光已压低曝光，板卡轮廓会更稳定。", systemImage: "circle.lefthalf.filled")
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Circle()
                        .fill(board.accentStart)
                        .frame(width: 10, height: 10)
                    Text(board.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                Text(board.shortSummary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct BoardModelStandaloneWindowView: View {
    let board: SupportedBoard
    let closeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(board.displayName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("独立 3D 视图")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭", action: closeAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            BoardModelSceneContainer(board: board, allowsZoom: true, doubleClickAction: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: boardModelPresentationProfile(for: board).previewBackground,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text("拖动旋转，滚轮缩放。视角围绕模型中心。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ToolkitHomeHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let heroState: ToolkitHeroState
    let badgeTitle: String
    let busy: Bool
    let actionHint: String
    let action: (() -> Void)?
    @State private var hovering = false

    private var accentColors: [Color] {
        if colorScheme == .dark {
            switch heroState {
            case .pluginHub:
                return [
                    Color(red: 0.15, green: 0.22, blue: 0.30),
                    Color(red: 0.12, green: 0.28, blue: 0.27),
                ]
            case .deviceReady:
                return [
                    Color(red: 0.14, green: 0.24, blue: 0.20),
                    Color(red: 0.12, green: 0.30, blue: 0.24),
                ]
            case .deviceClose:
                return [
                    Color(red: 0.28, green: 0.22, blue: 0.18),
                    Color(red: 0.22, green: 0.20, blue: 0.16),
                ]
            }
        } else {
            switch heroState {
            case .pluginHub:
                return [
                    Color(red: 0.82, green: 0.91, blue: 0.98),
                    Color(red: 0.86, green: 0.96, blue: 0.94),
                ]
            case .deviceReady:
                return [
                    Color(red: 0.85, green: 0.95, blue: 0.90),
                    Color(red: 0.90, green: 0.98, blue: 0.95),
                ]
            case .deviceClose:
                return [
                    Color(red: 0.94, green: 0.92, blue: 0.88),
                    Color(red: 0.98, green: 0.96, blue: 0.92),
                ]
            }
        }
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.08, green: 0.18, blue: 0.28)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Color(red: 0.22, green: 0.31, blue: 0.40)
    }

    private var badgeTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.11, green: 0.31, blue: 0.54)
    }

    private var badgeBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.72)
    }

    private var accentTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color(red: 0.16, green: 0.33, blue: 0.50)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.65)
    }

    private var actionIconColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color(red: 0.21, green: 0.42, blue: 0.62)
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .scaleEffect(hovering && action != nil ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.16), value: hovering)
        .onHover { inside in
            hovering = inside
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 18) {
            ToolkitInfoLogoView(size: 74, cornerRadius: 20)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(badgeTitle)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(badgeTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(badgeBackgroundColor)
                        .clipShape(Capsule())
                }

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(
                        heroState == .deviceReady ? "设备已识别" : (heroState == .deviceClose ? "设备已断开" : "等待识别"),
                        systemImage: heroState == .deviceReady ? "checkmark.circle.fill" : (heroState == .deviceClose ? "xmark.circle.fill" : "wave.3.right.circle.fill")
                    )
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(accentTextColor)

                    if busy {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(accentTextColor)
                            Text("后台处理中")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(accentTextColor)
                        }
                    } else if !actionHint.isEmpty {
                        Text(actionHint)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(accentTextColor)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: accentColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 14, x: 0, y: 8)
        .overlay(alignment: .topTrailing) {
            if action != nil {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(actionIconColor)
                    .padding(14)
                    .opacity(hovering ? 1 : 0.72)
            }
        }
    }
}

struct SupportedBoardsHeaderRow: View {
    var body: some View {
        HStack(spacing: BoardCatalogLayout.columnSpacing) {
            Text("序号")
                .frame(width: BoardCatalogLayout.indexWidth, alignment: .leading)
            Text("开发板名称")
                .frame(width: BoardCatalogLayout.nameWidth, alignment: .leading)
            Text("厂家名称")
                .frame(width: BoardCatalogLayout.manufacturerWidth, alignment: .leading)
            Text("插件版本")
                .frame(width: BoardCatalogLayout.versionWidth, alignment: .leading)
            Text("操作")
                .frame(width: BoardCatalogLayout.actionWidth, alignment: .leading)
        }
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, BoardCatalogLayout.rowHorizontalPadding)
    }
}

struct SupportedBoardRowView: View {
    let index: Int
    let board: SupportedBoard
    let selected: Bool
    let remoteVersion: String
    let installedVersion: String?
    let builtinInstalled: Bool
    let operation: BoardPluginOperationState
    let action: () -> Void
    let detailAction: () -> Void

    @ViewBuilder
    private var actionContent: some View {
        if operation.isBusy {
            VStack(alignment: .leading, spacing: 6) {
                if let progress = operation.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                Text(operation.message.isEmpty ? "处理中..." : operation.message)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                Button("详情", action: detailAction)
                    .buttonStyle(.bordered)
                if installedVersion == nil {
                    Button("安装插件", action: action)
                        .buttonStyle(.borderedProminent)
                } else if builtinInstalled {
                    Button("内置插件", action: {})
                        .buttonStyle(.bordered)
                        .disabled(true)
                } else {
                    Button("删除插件", action: action)
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: BoardCatalogLayout.columnSpacing) {
            Text("\(index)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(width: BoardCatalogLayout.indexWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(board.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    Text(board.integrationReady ? "已接入" : "规划中")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((board.integrationReady ? Color.green : Color.orange).opacity(0.14))
                        .foregroundStyle(board.integrationReady ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }
                Text(board.englishName)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: BoardCatalogLayout.nameWidth, alignment: .leading)

            Text(board.manufacturer)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .frame(width: BoardCatalogLayout.manufacturerWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(remoteVersion)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(installedVersion == nil ? "未安装" : (builtinInstalled ? "内置 \(installedVersion!)" : "本地 \(installedVersion!)"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(installedVersion == nil ? Color.secondary : (builtinInstalled ? Color.accentColor : Color.green))
                    .lineLimit(1)
            }
            .frame(width: BoardCatalogLayout.versionWidth, alignment: .leading)

            actionContent
                .frame(width: BoardCatalogLayout.actionWidth, alignment: .leading)
        }
        .padding(.horizontal, BoardCatalogLayout.rowHorizontalPadding)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

private enum SupportedBoardDetailSection: String, CaseIterable, Identifiable {
    case overview = "总览"
    case summary = "设备说明"
    case capabilities = "能力模块"
    case variants = "板型范围"
    case developmentEnvironment = "开发环境"

    var id: String { rawValue }

    func tint(for board: SupportedBoard) -> Color {
        switch self {
        case .overview:
            return board.accentStart
        case .summary:
            return Color(red: 0.10, green: 0.62, blue: 0.56)
        case .capabilities:
            return Color(red: 0.90, green: 0.50, blue: 0.18)
        case .variants:
            return Color(red: 0.47, green: 0.36, blue: 0.82)
        case .developmentEnvironment:
            return Color(red: 0.16, green: 0.48, blue: 0.94)
        }
    }
}

struct LocalScrollMonitorView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    final class Coordinator {
        let onScroll: (CGFloat) -> Void
        var monitor: Any?
        weak var hostView: NSView?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func installMonitorIfNeeded() {
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let hostView,
                      let hostWindow = hostView.window,
                      event.window === hostWindow
                else {
                    return event
                }
                onScroll(event.scrollingDeltaY)
                return nil
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            removeMonitor()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.hostView = view
        context.coordinator.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.installMonitorIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }
}

struct SupportedBoardDetailView: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard
    let remoteVersion: String
    let installedVersion: String?
    let currentControlBoardSelection: Binding<Bool>
    let hideOuterHero: Binding<Bool>
    let backAction: () -> Void
    let showDetachedModel: (SupportedBoard) -> Void
    @State private var selectedSection: SupportedBoardDetailSection = .overview
    @State private var expandedSection: SupportedBoardDetailSection = .overview
    @State private var navShowsFullLabel = false
    @State private var revealAllNavButtons = false
    @State private var hoveredSection: SupportedBoardDetailSection?
    @State private var overviewModelReady = false
    @State private var lastSectionSwitchTime: CFAbsoluteTime = 0
    @State private var sectionTransitionDirection = 1
    private let capabilityColumns = [GridItem(.adaptive(minimum: 116), spacing: 8)]

    private var integrationLabel: String {
        board.integrationReady ? "已接入控制链路" : "规划接入中"
    }

    private var availableSections: [SupportedBoardDetailSection] {
        var sections: [SupportedBoardDetailSection] = [.overview, .summary, .capabilities, .variants]
        if installedVersion != nil {
            sections.append(.developmentEnvironment)
        }
        return sections
    }

    private var overviewSummaryTitle: String {
        switch board.id {
        case "TaishanPi":
            return "泰山派（1M-RK3566）核心参数"
        default:
            return board.shortSummary
        }
    }

    private var overviewSpecificationLines: [String] {
        switch board.id {
        case "TaishanPi":
            return [
                "主控芯片：RK3566（瑞芯微）",
                "CPU：四核 Cortex-A55",
                "GPU：ARM G52 2EE",
                "频率：1.8GHz",
                "工艺：22nm",
                "NPU：1.0TOP 算力",
                "内存：2GB",
                "存储：16GB",
            ]
        default:
            return [
                "开发板名称：\(board.displayName)",
                "厂家：\(board.manufacturer)",
                "控制链路：\(board.integrationStatus)"
            ]
        }
    }

    private func verticalLabel(for section: SupportedBoardDetailSection) -> String {
        section.rawValue.map(String.init).joined(separator: "\n")
    }

    private func sectionIsExpanded(_ section: SupportedBoardDetailSection) -> Bool {
        revealAllNavButtons || hoveredSection == section || (expandedSection == section && navShowsFullLabel)
    }

    private func sectionIndex(_ section: SupportedBoardDetailSection) -> Int {
        availableSections.firstIndex(of: section) ?? 0
    }

    private var sectionContentTransition: AnyTransition {
        let movingForward = sectionTransitionDirection >= 0
        let insertionEdge: Edge = movingForward ? .bottom : .top
        let removalEdge: Edge = movingForward ? .top : .bottom
        return .asymmetric(
            insertion: .move(edge: insertionEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .center)),
            removal: .move(edge: removalEdge)
                .combined(with: .opacity)
        )
    }

    private func selectSection(_ section: SupportedBoardDetailSection, animated: Bool = true) {
        let direction = sectionIndex(section) >= sectionIndex(selectedSection) ? 1 : -1
        if animated {
            sectionTransitionDirection = direction
            withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                selectedSection = section
                expandedSection = section
                navShowsFullLabel = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard expandedSection == section else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.28)) {
                    navShowsFullLabel = false
                }
            }
        } else {
            sectionTransitionDirection = direction
            selectedSection = section
            expandedSection = section
        }
    }

    private func switchSection(step: Int) {
        let all = availableSections
        guard let currentIndex = all.firstIndex(of: selectedSection) else {
            return
        }
        let nextIndex = min(max(currentIndex + step, 0), all.count - 1)
        guard nextIndex != currentIndex else {
            return
        }
        selectSection(all[nextIndex])
    }

    private func handleScrollDelta(_ delta: CGFloat) {
        guard abs(delta) > 3 else {
            return
        }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSectionSwitchTime > 0.24 else {
            return
        }
        lastSectionSwitchTime = now
        switchSection(step: delta > 0 ? -1 : 1)
    }

    private func refreshOverviewModelReady() {
        overviewModelReady = BoardSceneRepository.shared.cachedScene(for: board.id) != nil
    }

    private func syncOuterHeroVisibility() {
        hideOuterHero.wrappedValue = selectedSection == .developmentEnvironment
    }

    @ViewBuilder
    private var backButton: some View {
        Button(action: backAction) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 0.18, green: 0.48, blue: 0.94))
                .frame(width: 70, height: 44)
                .overlay {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .help("返回支持设备列表")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: selectedSection == .developmentEnvironment ? 10 : 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(board.displayName)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text(board.englishName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Toggle("当前控制页", isOn: currentControlBoardSelection)
                        .toggleStyle(.checkbox)
                        .help("勾选表示当前设备控制页面关联的是这块开发板。")
                    }
                    .frame(width: 102, alignment: .leading)

                    Spacer()

                    backButton
                }

                ZStack {
                    sectionContent(for: selectedSection)
                        .id(selectedSection.id)
                        .transition(sectionContentTransition)
                }
                .padding(.top, selectedSection == .developmentEnvironment ? 0 : 8)
                .padding(.horizontal, 14)
                .padding(.vertical, selectedSection == .developmentEnvironment ? 12 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedSection.tint(for: board).opacity(0.035))
                            .padding(1)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .clipped()
                .animation(.spring(response: 0.38, dampingFraction: 0.84), value: selectedSection)
            }
            .padding(.trailing, 4)

            VStack(alignment: .trailing, spacing: 10) {
                ForEach(availableSections) { section in
                    let tint = section.tint(for: board)
                    let expanded = sectionIsExpanded(section)
                    Button {
                        selectSection(section)
                    } label: {
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [tint.opacity(0.98), tint.opacity(0.78)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: expanded ? 82 : 7, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(tint.opacity(0.16), lineWidth: 1)
                                )

                            if expanded {
                                Text(section.rawValue)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 82, height: 32)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .frame(width: 82, height: 32, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                            hoveredSection = hovering ? section : (hoveredSection == section ? nil : hoveredSection)
                        }
                    }
                }
            }
            .padding(.top, 88)
        }
        .padding(.top, selectedSection == .developmentEnvironment ? 12 : 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            LocalScrollMonitorView(onScroll: handleScrollDelta)
                .allowsHitTesting(false)
        )
        .onAppear {
            if !availableSections.contains(selectedSection) {
                selectedSection = .overview
            }
            refreshOverviewModelReady()
            syncOuterHeroVisibility()
            revealAllNavButtons = true
            selectSection(selectedSection, animated: false)
            DispatchQueue.main.async {
                selectSection(selectedSection)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    revealAllNavButtons = false
                }
            }
        }
        .onChange(of: board.id) { _, _ in
            refreshOverviewModelReady()
        }
        .onChange(of: selectedSection) { _, newValue in
            syncOuterHeroVisibility()
            if newValue == .overview {
                refreshOverviewModelReady()
            }
        }
        .onDisappear {
            hideOuterHero.wrappedValue = false
        }
    }

    @ViewBuilder
    private func sectionContent(for section: SupportedBoardDetailSection) -> some View {
        switch section {
        case .overview:
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        LinearGradient(
                            colors: boardModelPresentationProfile(for: board).previewBackground,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        BoardModelSceneContainer(
                            board: board,
                            allowsZoom: false,
                            doubleClickAction: {
                                showDetachedModel(board)
                            },
                            onSceneReady: {
                                overviewModelReady = true
                            }
                        )
                        .frame(width: boardModelPresentationProfile(for: board).previewSize, height: boardModelPresentationProfile(for: board).previewSize)
                        .opacity(overviewModelReady ? 1 : 0.001)

                        if !overviewModelReady {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.regular)
                                    .tint(.white)
                                Text("3D 模型加载中…")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                        }
                    }
                    .frame(width: boardModelPresentationProfile(for: board).previewSize, height: boardModelPresentationProfile(for: board).previewSize)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    Text("拖动旋转，双击可打开独立 3D 查看窗口。")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(overviewSummaryTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))

                    ForEach(overviewSpecificationLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(board.accentStart)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .summary:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    detailMetricCard(
                        title: "厂家",
                        value: board.manufacturer,
                        detail: board.variantDisplayNames.first ?? board.displayName
                    )
                    detailMetricCard(
                        title: "插件版本",
                        value: remoteVersion,
                        detail: installedVersion == nil ? "本地未安装" : "本地 \(installedVersion!)"
                    )
                    detailMetricCard(
                        title: "集成状态",
                        value: integrationLabel,
                        detail: board.integrationReady ? "控制能力已可用" : "等待后续接入"
                    )
                }

                Text(board.detailSummary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    detailBullet("开发板名称：\(board.displayName)")
                    detailBullet("厂家名称：\(board.manufacturer)")
                    detailBullet("当前控制链路：\(board.integrationStatus)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .capabilities:
            VStack(alignment: .leading, spacing: 12) {
                Text("当前开发板计划复用或已接入的能力模块如下。后续增加新板卡时，优先按这些模块进行组合。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: capabilityColumns, alignment: .leading, spacing: 10) {
                    ForEach(board.capabilities, id: \.rawValue) { capability in
                        CapabilityChip(title: capability.displayName, tint: board.accentStart)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .variants:
            VStack(alignment: .leading, spacing: 12) {
                Text("该开发板系列当前覆盖的板型如下，后续识别和动作分发会按具体板型继续细分。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(board.variantDisplayNames, id: \.self) { variant in
                        HStack(spacing: 10) {
                            Image(systemName: "cpu.fill")
                                .foregroundStyle(board.accentStart)
                            Text(variant)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .developmentEnvironment:
            DevelopmentInstallPanelView(vm: vm, board: board, embedded: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func detailMetricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(board.accentStart)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

struct DetectedDeviceSelectionOverlay: View {
    let prompt: DeviceSelectionPrompt
    let chooseAction: (DetectedBoardCandidate) -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择要连接的设备")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("已同时检测到多个硬件接口，请选择当前要使用的开发板。")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("稍后再选", action: dismissAction)
                    .buttonStyle(.bordered)
            }

            VStack(spacing: 10) {
                ForEach(prompt.candidates) { candidate in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.displayName)
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                            Text("\(candidate.interfaceName) · \(candidate.transportName)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(candidate.sourceName)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("连接此设备") {
                            chooseAction(candidate)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }
}

struct DisconnectedBoardHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: ToolkitViewModel
    @Binding var detailBoard: SupportedBoard?
    @Binding var hideOuterHero: Bool
    let showDetachedModel: (SupportedBoard) -> Void
    @State private var searchText = ""
    @State private var selectedBoardID: String?

    private var searchFieldBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    private var searchFieldBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.accentColor.opacity(0.22)
    }

    private var searchFieldShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.accentColor.opacity(0.07)
    }

    private var filteredBoards: [SupportedBoard] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return vm.supportedBoards
        }

        let terms = trimmed.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        return vm.supportedBoards.filter { board in
            let haystacks = [
                board.displayName.lowercased(),
                board.englishName.lowercased(),
                board.manufacturer.lowercased(),
                board.shortSummary.lowercased(),
            ] + board.searchableTerms.map { $0.lowercased() }

            return terms.allSatisfy { term in
                haystacks.contains { $0.contains(term) }
            }
        }
    }

    private var selectedBoard: SupportedBoard? {
        guard let selectedBoardID else {
            return nil
        }
        return vm.supportedBoards.first(where: { $0.id == selectedBoardID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !(detailBoard != nil && hideOuterHero) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        TextField("搜索开发板名称、型号或厂家", text: $searchText)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(searchFieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(searchFieldBorder, lineWidth: 1.2)
                    )
                    .shadow(color: searchFieldShadow, radius: 8, x: 0, y: 4)

                    Button("立即检测") {
                        vm.refreshStatus()
                    }

                    Button("同步目录") {
                        Task { await vm.syncBoardPluginCatalog(force: true) }
                    }
                    Spacer()
                    Text("共 \(vm.supportedBoards.count) 款设备")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Group {
                if let detailBoard {
                    SupportedBoardDetailView(
                        vm: vm,
                        board: detailBoard,
                        remoteVersion: vm.boardPluginDisplayVersion(detailBoard.id),
                        installedVersion: vm.boardPluginInstalledVersion(detailBoard.id),
                        currentControlBoardSelection: Binding(
                            get: { vm.preferredControlBoardID == detailBoard.id },
                            set: { isOn in
                                vm.setPreferredControlBoard(isOn ? detailBoard.id : nil)
                            }
                        ),
                        hideOuterHero: $hideOuterHero,
                        backAction: {
                            self.detailBoard = nil
                            hideOuterHero = false
                        },
                        showDetachedModel: showDetachedModel
                    )
                    .padding(.top, hideOuterHero ? 10 : 0)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SupportedBoardsHeaderRow()

                        if filteredBoards.isEmpty {
                            VStack(spacing: 10) {
                                Spacer()
                                Image(systemName: "square.text.square")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("未找到匹配的开发板")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Text("请调整关键词后再试。")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(filteredBoards.enumerated()), id: \.element.id) { offset, board in
                                        SupportedBoardRowView(
                                            index: offset + 1,
                                            board: board,
                                            selected: selectedBoardID == board.id,
                                            remoteVersion: vm.boardPluginDisplayVersion(board.id),
                                            installedVersion: vm.boardPluginInstalledVersion(board.id),
                                            builtinInstalled: vm.installedBoardToolingMetadata(board.id)?.isBuiltin == true,
                                            operation: vm.boardPluginOperation(for: board.id),
                                            action: { vm.installOrRemoveBoardPlugin(board) },
                                            detailAction: { self.detailBoard = board }
                                        )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedBoardID = board.id
                                            }
                                            .simultaneousGesture(
                                                TapGesture(count: 2).onEnded {
                                                    selectedBoardID = board.id
                                                    self.detailBoard = board
                                                }
                                            )
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(item: $vm.boardPluginAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("关闭"))
            )
        }
    }
}

struct ConnectedBoardPlaceholderView: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard
    let showDetachedModel: (SupportedBoard) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardModelPreviewCard(board: board, doubleClickAction: {
                    showDetachedModel(board)
                })

                GroupBox("当前连接") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(vm.detectedHardwareDisplayName ?? board.displayName, systemImage: "cpu.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                        Text("\(vm.deviceConnectionText) · \(vm.deviceReachabilityText)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("能力模块") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 10) {
                        ForEach(board.capabilities, id: \.rawValue) { capability in
                            CapabilityChip(title: capability.displayName, tint: board.accentStart)
                        }
                    }
                    .padding(.top, 8)
                }

                GroupBox("接入状态") {
                    Text(board.integrationStatus)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private enum RebootPromptPhase {
    case confirm
    case submitting
}

struct ConnectedBoardDashboardView: View {
    @ObservedObject var vm: ToolkitViewModel
    @Binding var selectedTab: Int
    let showDetachedModel: (SupportedBoard) -> Void
    let requestRebootDevice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    Button {
                        vm.switchWorkspaceMode(.release)
                    } label: {
                        Label("发布版", systemImage: WorkspaceMode.release.symbolName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(minWidth: 82)
                            .background(vm.workspaceMode == .release ? Color.accentColor.opacity(0.18) : .clear)
                            .foregroundStyle(vm.workspaceMode == .release ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    if vm.hasDevelopmentWorkspace {
                        Divider()
                            .frame(height: 18)

                        Button {
                            vm.switchWorkspaceMode(.development)
                        } label: {
                            Label("开发版", systemImage: WorkspaceMode.development.symbolName)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .frame(minWidth: 82)
                                .background(vm.workspaceMode == .development ? Color.accentColor.opacity(0.18) : .clear)
                                .foregroundStyle(vm.workspaceMode == .development ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                if let board = vm.detectedBoard {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vm.detectedHardwareDisplayName ?? board.displayName)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                        Text(board.manufacturer)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Text(vm.localAgentRunning ? "DBT Agent 在线" : "DBT Agent 离线")
                    .font(.caption)
                    .foregroundStyle(vm.localAgentRunning ? .green : .secondary)
                if vm.detectedBoard?.id == "TaishanPi" {
                    let rebootDeviceState = vm.actionAvailabilityState(for: .rebootDevice)
                    Button("设备重启") { requestRebootDevice() }
                        .disabled(!rebootDeviceState.enabled)
                        .help(rebootDeviceState.reason ?? "通过控制服务或 SSH 请求设备重启")
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let board = vm.detectedBoard, board.id == "TaishanPi" {
                        Picker("", selection: $selectedTab) {
                            Text("总览").tag(0)
                            Text("刷写").tag(1)
                            Text("定制").tag(2)
                            Text("通知").tag(3)
                        }
                        .pickerStyle(.segmented)

                        if selectedTab == 0 {
                            OverviewTab(vm: vm)
                        } else if selectedTab == 1 {
                            FlashTab(vm: vm)
                        } else if selectedTab == 2 {
                            CustomizeTab(vm: vm)
                        } else {
                            ActivityTab(vm: vm)
                        }
                    } else if let board = vm.detectedBoard {
                        ConnectedBoardPlaceholderView(vm: vm, board: board, showDetachedModel: showDetachedModel)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("当前没有可显示的设备控制页", systemImage: "cpu")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                            Text("请先从初始化列表选择开发板，或连接已安装插件支持的硬件设备。")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct TaskOverlayView: View {
    @ObservedObject var vm: ToolkitViewModel

    var title: String {
        if vm.postFlashRecoveryActive {
            return vm.postFlashRecoveryTitle
        }
        if let task = vm.currentTask {
            return task.action ?? "后台任务"
        }
        return vm.pendingTaskTitle.isEmpty ? "后台任务" : vm.pendingTaskTitle
    }

    var isRunning: Bool {
        if vm.postFlashRecoveryActive {
            return !vm.postFlashRecoveryFinished
        }
        if !vm.pendingTaskTitle.isEmpty {
            return true
        }
        return vm.currentTask?.status != "finished"
    }

    var statusText: String {
        if vm.postFlashRecoveryActive {
            return vm.postFlashRecoveryStatus
        }
        return vm.taskStatusText(for: vm.currentTask)
    }

    var progressText: String {
        if vm.postFlashRecoveryActive {
            return vm.postFlashRecoveryProgress
        }
        return vm.taskProgressLine(for: vm.currentTask)
    }

    var detailLines: [String] {
        if vm.postFlashRecoveryActive {
            return vm.postFlashRecoveryLines
        }
        return vm.taskTimelineLines(for: vm.currentTask)
    }

    var progressValue: Double? {
        if vm.postFlashRecoveryActive {
            return vm.postFlashRecoveryProgressValue
        }
        return vm.taskProgressValue(for: vm.currentTask)
    }

    var statusColor: Color {
        if vm.postFlashRecoveryActive {
            if isRunning {
                return .orange
            }
            return vm.postFlashRecoverySucceeded ? .green : .red
        }
        return isRunning ? .orange : (vm.currentTask?.ok == true ? .green : .red)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(statusColor)
                        }
                    }
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let progressValue, isRunning {
                        ProgressView(value: progressValue)
                            .progressViewStyle(.linear)
                    }
                    Text(progressText)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(detailLines.prefix(5).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .topLeading)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack {
                    Spacer()
                    if !isRunning {
                        Button("关闭") { vm.dismissCurrentTaskOverlay() }
                    }
                }
            }
            .padding(16)
            .frame(width: 430)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 18)
        }
    }
}

struct ContentView: View {
    @ObservedObject var vm: ToolkitViewModel
    let showDetachedModel: (SupportedBoard) -> Void
    @State private var selectedTab = 0
    @State private var detailBoard: SupportedBoard?
    @State private var hideCatalogHero = false
    @State private var rebootPromptPhase: RebootPromptPhase?
    @State private var rebootPromptProgress: Double = 0
    @State private var rebootPromptStatus = "正在下发重启指令…"

    var footerMessage: String {
        vm.inlineErrorMessage.isEmpty ? vm.lastActionSummary : vm.inlineErrorMessage
    }

    var footerIsError: Bool {
        !vm.inlineErrorMessage.isEmpty
    }

    var heroAction: (() -> Void)? {
        if vm.isShowingBoardCatalog {
            guard vm.heroActionAvailable else {
                return nil
            }
            return {
                if let board = vm.heroTargetBoard {
                    vm.showControlPage(for: board)
                }
            }
        }
        return {
            vm.showSupportedBoardCatalog()
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 12) {
                if !(vm.isShowingBoardCatalog && hideCatalogHero) {
                    ToolkitHomeHeroCard(
                        title: vm.productDisplayName,
                        subtitle: vm.headerSubtitle,
                        heroState: vm.heroState,
                        badgeTitle: vm.heroBadgeTitle,
                        busy: vm.busy && !vm.taskOverlayVisible
                        ,
                        actionHint: vm.heroActionHint,
                        action: heroAction
                    )
                    .padding(.top, 0)
                    .padding(.bottom, 4)
                }

                Group {
                    if vm.isShowingBoardCatalog {
                        DisconnectedBoardHubView(
                            vm: vm,
                            detailBoard: $detailBoard,
                            hideOuterHero: $hideCatalogHero,
                            showDetachedModel: showDetachedModel
                        )
                    } else {
                        ConnectedBoardDashboardView(
                            vm: vm,
                            selectedTab: $selectedTab,
                            showDetachedModel: showDetachedModel,
                            requestRebootDevice: { presentRebootPrompt() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, vm.isShowingBoardCatalog && hideCatalogHero ? 6 : 14)
            .padding(.bottom, 41)
            .frame(width: BoardCatalogLayout.popoverSize.width, height: BoardCatalogLayout.popoverSize.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .allowsHitTesting(!vm.taskOverlayBlocking && rebootPromptPhase == nil)

            HStack(alignment: .center, spacing: 8) {
                if footerIsError {
                    Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(vm.footerFlashOn ? .orange : .red)
                }
                Text(footerMessage)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(footerIsError ? (vm.footerFlashOn ? .orange : .red) : .secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .frame(width: BoardCatalogLayout.popoverSize.width - 28, alignment: .leading)
            .padding(.leading, 14)
            .padding(.bottom, 10)

            if vm.taskOverlayVisible {
                TaskOverlayView(vm: vm)
            }

            if let rebootPromptPhase {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                ZStack {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: rebootPromptPhase == .confirm ? "arrow.clockwise.circle" : "arrow.clockwise.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(rebootPromptPhase == .confirm ? "确认重启开发板？" : rebootPromptStatus)
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                        }

                        if rebootPromptPhase == .submitting {
                            VStack(alignment: .leading, spacing: 10) {
                                ProgressView(value: rebootPromptProgress)
                                    .progressViewStyle(.linear)
                                Text("请稍候…")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Spacer()
                            if rebootPromptPhase == .confirm {
                                Button("取消") {
                                    dismissRebootPrompt()
                                }
                                .keyboardShortcut(.cancelAction)

                                Button("确认重启") {
                                    submitRebootDevice()
                                }
                                .keyboardShortcut(.defaultAction)
                            }
                        }
                    }
                    .padding(22)
                    .frame(width: 410)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if let prompt = vm.deviceSelectionPrompt {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                DetectedDeviceSelectionOverlay(
                    prompt: prompt,
                    chooseAction: { candidate in
                        vm.chooseDetectedBoard(candidate)
                    },
                    dismissAction: {
                        vm.dismissDeviceSelectionPrompt()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onChange(of: vm.connectedBoardID) { _, _ in
            selectedTab = 0
        }
        .onChange(of: vm.isShowingBoardCatalog) { _, isShowingCatalog in
            if !isShowingCatalog {
                detailBoard = nil
                hideCatalogHero = false
            }
        }
    }

    private func presentRebootPrompt() {
        guard rebootPromptPhase == nil else {
            return
        }
        rebootPromptStatus = "正在下发重启指令…"
        rebootPromptProgress = 0
        rebootPromptPhase = .confirm
    }

    private func dismissRebootPrompt() {
        rebootPromptPhase = nil
        rebootPromptProgress = 0
        rebootPromptStatus = "正在下发重启指令…"
    }

    private func submitRebootDevice() {
        guard rebootPromptPhase != .submitting else {
            return
        }
        rebootPromptPhase = .submitting
        rebootPromptProgress = 0.16
        rebootPromptStatus = "正在下发重启指令…"
        Task {
            do {
                try await vm.rebootDevice()
                await MainActor.run {
                    rebootPromptStatus = "重启指令已下发"
                    withAnimation(.linear(duration: 2.0)) {
                        rebootPromptProgress = 1.0
                    }
                }
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    dismissRebootPrompt()
                }
            } catch {
                await MainActor.run {
                    dismissRebootPrompt()
                }
            }
        }
    }
}

@MainActor
final class WindowCloseGuard: NSObject, NSWindowDelegate {
    let canClose: () -> Bool

    init(canClose: @escaping () -> Bool) {
        self.canClose = canClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        canClose()
    }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let vm: ToolkitViewModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private let statusIndicatorView = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
    private var boardModelWindowController: NSWindowController?
    private var versionInfoWindowController: NSWindowController?
    private var featureInfoWindowController: NSWindowController?
    private var contactInfoWindowController: NSWindowController?
    private var developmentInstallWindowController: NSWindowController?
    private var developmentInstallWindowCloseGuard: WindowCloseGuard?
    private var updateWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObserver: NSObjectProtocol?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    init(vm: ToolkitViewModel) {
        self.vm = vm
        super.init()
        configurePopover()
        configureMenu()
        configureStatusItem()
        bindViewModel()
        updateStatusItemAppearance()
    }

    deinit {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.contentSize = BoardCatalogLayout.popoverSize
        popover.contentViewController = NSHostingController(rootView: ContentView(vm: vm, showDetachedModel: { [weak self] board in
            self?.showBoardModelWindow(board)
        }))
        popover.delegate = self
    }

    private func configureMenu() {
        let versionItem = NSMenuItem(title: "版本信息", action: #selector(showVersionInfo), keyEquivalent: "")
        versionItem.target = self
        contextMenu.addItem(versionItem)

        let featureItem = NSMenuItem(title: "功能说明", action: #selector(showFeatureInfo), keyEquivalent: "")
        featureItem.target = self
        contextMenu.addItem(featureItem)

        let contactItem = NSMenuItem(title: "联系方式", action: #selector(showContactInfo), keyEquivalent: "")
        contactItem.target = self
        contextMenu.addItem(contactItem)

        let updateItem = NSMenuItem(title: "软件更新", action: #selector(showUpdateWindow), keyEquivalent: "")
        updateItem.target = self
        contextMenu.addItem(updateItem)

        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemAppearance()
            }
        }
        configureStatusIndicator(on: button)
    }

    private func bindViewModel() {
        Publishers.CombineLatest(vm.$status, vm.$localAgentRunning)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItemAppearance()
            }
            .store(in: &cancellables)
    }

    private func installClickMonitors() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor in
                    self?.handleOutsideClick(event)
                }
            }
        }
        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }
                self.handleOutsideClick(event)
                return event
            }
        }
    }

    private func shouldKeepPopoverOpen(for event: NSEvent) -> Bool {
        guard popover.isShown else {
            return true
        }

        if vm.fileDialogActive {
            return true
        }

        if let popoverWindow = popover.contentViewController?.view.window {
            if event.window === popoverWindow {
                return true
            }
            if popoverWindow.frame.contains(NSEvent.mouseLocation) {
                return true
            }
        }

        if let modelWindow = boardModelWindowController?.window {
            if event.window === modelWindow {
                return true
            }
            if modelWindow.frame.contains(NSEvent.mouseLocation) {
                return true
            }
        }

        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let buttonScreenRect = buttonWindow.convertToScreen(buttonRect)
            if buttonScreenRect.contains(NSEvent.mouseLocation) {
                return true
            }
        }

        return false
    }

    private func handleOutsideClick(_ event: NSEvent) {
        guard popover.isShown else {
            return
        }
        if shouldKeepPopoverOpen(for: event) {
            return
        }
        closePopover()
    }

    private func tintColor() -> NSColor {
        if !vm.localAgentRunning {
            return .systemOrange
        }
        switch vm.status?.usb?.mode ?? "absent" {
        case "loader":
            return .systemBlue
        case "usb-ecm":
            return vm.status?.board?.ping == true ? .systemGreen : .systemOrange
        case "absent":
            return .secondaryLabelColor
        default:
            return .systemOrange
        }
    }

    private enum StatusIndicatorState {
        case online
        case warning
        case hidden
    }

    private func currentStatusIndicatorState() -> StatusIndicatorState {
        guard vm.localAgentRunning else {
            return .warning
        }
        let usbMode = (vm.status?.usb?.mode ?? "absent").lowercased()
        if usbMode == "absent" {
            return .warning
        }
        if vm.status?.board?.ping == true || vm.status?.board?.ssh_port_open == true || vm.status?.board?.control_service == true {
            return .online
        }
        if usbMode == "loader" || usbMode == "usb-ecm" || usbMode == "detecting" || vm.status?.usbnet?.configured == true {
            return .warning
        }
        return .hidden
    }

    private func configureStatusIndicator(on button: NSStatusBarButton) {
        guard statusIndicatorView.superview !== button else {
            return
        }
        statusIndicatorView.wantsLayer = true
        statusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        statusIndicatorView.isHidden = true
        button.addSubview(statusIndicatorView)
        NSLayoutConstraint.activate([
            statusIndicatorView.widthAnchor.constraint(equalToConstant: 3.5),
            statusIndicatorView.heightAnchor.constraint(equalToConstant: 3.5),
            statusIndicatorView.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: -1.9),
            statusIndicatorView.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 0.9),
        ])
    }

    private func updateStatusIndicatorAppearance() {
        guard let layer = statusIndicatorView.layer else {
            return
        }
        let state = currentStatusIndicatorState()
        switch state {
        case .online:
            statusIndicatorView.isHidden = false
            layer.backgroundColor = NSColor.systemGreen.cgColor
            layer.borderColor = NSColor.clear.cgColor
            layer.borderWidth = 0
            layer.cornerRadius = 1.75
        case .warning:
            statusIndicatorView.isHidden = false
            layer.backgroundColor = NSColor.systemOrange.cgColor
            layer.borderColor = NSColor.clear.cgColor
            layer.borderWidth = 0
            layer.cornerRadius = 1.75
        case .hidden:
            statusIndicatorView.isHidden = true
        }
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else {
            return
        }
        configureStatusIndicator(on: button)
        button.image = makeStatusBarImage()
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = nil
        button.title = ""
        button.toolTip = vm.statusHeadline
        updateStatusIndicatorAppearance()
    }

    private func makeStatusBarImage() -> NSImage? {
        let canvasSize = NSSize(width: 24, height: 24)
        let composite = NSImage(size: canvasSize)
        composite.lockFocus()
        defer {
            composite.unlockFocus()
        }
        let primaryColor = NSColor.black
        primaryColor.setStroke()
        primaryColor.setFill()

        let tabletRect = NSRect(x: 2.1, y: 5.0, width: 15.6, height: 12.0)
        let tablet = NSBezierPath(roundedRect: tabletRect, xRadius: 2.4, yRadius: 2.4)
        tablet.lineWidth = 1.9
        tablet.stroke()

        let screenRect = NSRect(x: 4.4, y: 6.8, width: 11.8, height: 8.4)
        let screen = NSBezierPath(roundedRect: screenRect, xRadius: 1.1, yRadius: 1.1)
        screen.lineWidth = 1.2
        screen.stroke()

        let cable = NSBezierPath()
        cable.lineWidth = 1.9
        cable.lineCapStyle = .round
        cable.move(to: NSPoint(x: 17.7, y: 10.7))
        cable.curve(
            to: NSPoint(x: 22.2, y: 6.2),
            controlPoint1: NSPoint(x: 19.6, y: 10.7),
            controlPoint2: NSPoint(x: 20.8, y: 8.0)
        )
        cable.stroke()

        let plug = NSBezierPath(roundedRect: NSRect(x: 20.7, y: 4.9, width: 2.1, height: 2.4), xRadius: 0.6, yRadius: 0.6)
        plug.fill()
        composite.isTemplate = true
        return composite
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }
        installClickMonitors()
        popover.contentSize = BoardCatalogLayout.popoverSize
        if let hosting = popover.contentViewController as? NSHostingController<ContentView> {
            hosting.rootView = ContentView(vm: vm, showDetachedModel: { [weak self] board in
                self?.showBoardModelWindow(board)
            })
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            closePopover()
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showBoardModelWindow(_ board: SupportedBoard) {
        let rootView = BoardModelStandaloneWindowView(
            board: board,
            closeAction: { [weak self] in
                self?.boardModelWindowController?.close()
            }
        )

        if let controller = boardModelWindowController, let window = controller.window {
            window.title = "\(board.displayName) 3D 视图"
            window.contentViewController = NSHostingController(rootView: rootView)
            window.level = .statusBar
            if let popoverWindow = popover.contentViewController?.view.window, window.parent !== popoverWindow {
                popoverWindow.addChildWindow(window, ordered: .above)
            }
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(board.displayName) 3D 视图"
        window.center()
        window.setContentSize(NSSize(width: 920, height: 720))
        window.level = .statusBar
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.contentViewController = NSHostingController(rootView: rootView)
        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.addChildWindow(window, ordered: .above)
        }

        let controller = NSWindowController(window: window)
        boardModelWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window === self.boardModelWindowController?.window else {
                    return
                }
                self.boardModelWindowController = nil
            }
        }
    }

    private func presentInfoWindow(page: ToolkitInfoPage) {
        let existingController: NSWindowController? = {
            switch page {
            case .version:
                return versionInfoWindowController
            case .features:
                return featureInfoWindowController
            case .contact:
                return contactInfoWindowController
            }
        }()

        if let existingController {
            existingController.showWindow(nil)
            existingController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferredSize = page.preferredSize
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: preferredSize.width, height: preferredSize.height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = page.windowTitle
        window.center()
        window.setContentSize(preferredSize)
        window.contentViewController = NSHostingController(rootView: ToolkitInfoWindowView(page: page))

        let controller = NSWindowController(window: window)
        switch page {
        case .version:
            versionInfoWindowController = controller
        case .features:
            featureInfoWindowController = controller
        case .contact:
            contactInfoWindowController = controller
        }
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window != nil else {
                    return
                }
                switch page {
                case .version:
                    self.versionInfoWindowController = nil
                case .features:
                    self.featureInfoWindowController = nil
                case .contact:
                    self.contactInfoWindowController = nil
                }
            }
        }
    }

    @objc private func showVersionInfo() {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        presentInfoWindow(page: .version(appVersion: shortVersion, buildVersion: buildVersion))
    }

    @objc private func showFeatureInfo() {
        presentInfoWindow(page: .features)
    }

    @objc private func showContactInfo() {
        presentInfoWindow(page: .contact)
    }

    @objc private func showDevelopmentInstallWindow() {
        if let controller = developmentInstallWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            Task { await vm.refreshDevelopmentInstallStatus() }
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Development Board Toolchain 发布环境安装"
        window.center()
        window.setContentSize(NSSize(width: 760, height: 540))
        let closeGuard = WindowCloseGuard { [weak vm] in
            guard let vm else {
                return true
            }
            if !vm.pendingTaskTitle.isEmpty {
                return false
            }
            if let task = vm.currentTask, vm.isInstallerTask(task), task.status != "finished" {
                return false
            }
            return true
        }
        developmentInstallWindowCloseGuard = closeGuard
        window.delegate = closeGuard
        window.contentViewController = NSHostingController(rootView: DevelopmentInstallWindowView(vm: vm))

        let controller = NSWindowController(window: window)
        developmentInstallWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await vm.refreshDevelopmentInstallStatus() }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window === self.developmentInstallWindowController?.window else {
                    return
                }
                self.developmentInstallWindowController = nil
                self.developmentInstallWindowCloseGuard = nil
            }
        }
    }

    @objc private func showUpdateWindow() {
        vm.refreshToolkitUpdateStatus()
        if let controller = updateWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            vm.startAutomaticToolkitUpdateFlow()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 170),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Development Board Toolchain 软件更新"
        window.center()
        window.setContentSize(NSSize(width: 420, height: 170))
        window.contentViewController = NSHostingController(rootView: ToolkitUpdateWindowView(vm: vm))

        let controller = NSWindowController(window: window)
        updateWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        vm.startAutomaticToolkitUpdateFlow()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window === self.updateWindowController?.window else {
                    return
                }
                self.updateWindowController = nil
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let vm = ToolkitViewModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        vm.startBackgroundMonitoring()
        _ = notification
        statusBarController = StatusBarController(vm: vm)
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
    }
}

@main
struct DevelopmentBoardToolchainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
