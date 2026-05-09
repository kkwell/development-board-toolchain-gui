import AppKit
import Combine
import Darwin
import Foundation
import IOKit
import SceneKit
import SwiftUI
import SystemConfiguration
import UniformTypeIdentifiers
import UserNotifications

private enum ToolkitChromeColors {
    private static func dynamicColor(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let components = isDark ? dark : light
            return NSColor(
                calibratedRed: components.0,
                green: components.1,
                blue: components.2,
                alpha: 1
            )
        }
    }

    static let windowBackground = dynamicColor(
        light: (0.948, 0.955, 0.965),
        dark: (0.102, 0.112, 0.126)
    )
    static let panelBackground = dynamicColor(
        light: (0.979, 0.984, 0.990),
        dark: (0.136, 0.147, 0.165)
    )
    static let inputBackground = dynamicColor(
        light: (0.968, 0.974, 0.982),
        dark: (0.157, 0.170, 0.190)
    )
    static let overlayBackground = dynamicColor(
        light: (0.960, 0.967, 0.977),
        dark: (0.120, 0.132, 0.150)
    )
}

private extension Color {
    static var toolkitWindowBackground: Color {
        Color(nsColor: ToolkitChromeColors.windowBackground)
    }

    static var toolkitPanelBackground: Color {
        Color(nsColor: ToolkitChromeColors.panelBackground)
    }

    static var toolkitInputBackground: Color {
        Color(nsColor: ToolkitChromeColors.inputBackground)
    }

    static var toolkitOverlayBackground: Color {
        Color(nsColor: ToolkitChromeColors.overlayBackground)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    static let defaultsKey = "embedLabsGUI.language"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var resourceName: String { rawValue }

    var menuTitle: String {
        switch self {
        case .zhHans:
            return "中文"
        case .en:
            return "English"
        }
    }

    var displayTitle: String {
        switch self {
        case .zhHans:
            return "中文"
        case .en:
            return "English"
        }
    }

    static var stored: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        return .zhHans
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .stored
}

private extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

private enum AppStrings {
    static let productName = "Embed Labs"

    static func productNormalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "Development Board Toolchain", with: productName)
            .replacingOccurrences(of: "Development board toolchain", with: productName)
            .replacingOccurrences(of: "development board toolchain", with: productName)
    }

    static func localized(_ key: String, language: AppLanguage = .stored) -> String {
        let normalizedKey = productNormalized(key)
        guard language == .en else {
            return normalizedKey
        }
        guard let url = Bundle.main.url(forResource: language.resourceName, withExtension: "lproj"),
              let bundle = Bundle(url: url) else {
            return englishFallback(for: normalizedKey)
        }
        let translated = bundle.localizedString(forKey: key, value: nil, table: nil)
        if translated != key {
            return productNormalized(translated)
        }
        let normalizedTranslated = bundle.localizedString(forKey: normalizedKey, value: nil, table: nil)
        if normalizedTranslated != normalizedKey {
            return productNormalized(normalizedTranslated)
        }
        return englishFallback(for: normalizedKey)
    }

    static func englishFallback(for key: String) -> String {
        var result = productNormalized(key)
        let replacements: [(String, String)] = [
            ("当前开发板仍处于 USB ECM 运行态，但主机 USB 网络尚未恢复完成。请先恢复 USB 网络后再刷写。", "The board is still in USB ECM runtime mode, but the host USB network has not recovered yet. Restore USB networking before flashing."),
            ("当前开发板仍处于 USB ECM 运行态，但控制服务和 SSH 均不可用。现有刷写链路无法自动切换到 Loader，直接刷写会超时。请先恢复控制服务/SSH，或手动让开发板进入 Loader 模式后再刷写。", "The board is still in USB ECM runtime mode, but neither the control service nor SSH is available. The current flash workflow cannot switch to Loader automatically and would time out. Restore the control service/SSH, or manually put the board into Loader mode before flashing."),
            ("当前开发板处于 USB ECM 运行态，刷写前会先通过控制服务切换到 Loader。", "The board is in USB ECM runtime mode and will switch to Loader through the control service before flashing."),
            ("当前开发板处于 USB ECM 运行态，控制服务未响应，但 SSH 可用；刷写前会通过 SSH fallback 请求进入 Loader。", "The board is in USB ECM runtime mode. The control service is not responding, but SSH is available; SSH fallback will request Loader before flashing."),
            ("当前开发板处于 USB ECM 运行态，但控制服务和 SSH 均不可用。请先恢复控制链路，或手动进入 Loader 后再刷写。", "The board is in USB ECM runtime mode, but both the control service and SSH are unavailable. Restore the control link or enter Loader manually before flashing."),
            ("当前开发板已处于 Loader 模式，将直接执行刷写。", "The board is already in Loader mode. Flashing will start directly."),
            ("当前开发板已处于 Maskrom 模式，刷写前会先通过 MiniLoaderAll.bin 拉起 Loader，再继续执行刷写。", "The board is in Maskrom mode. MiniLoaderAll.bin will start Loader before flashing continues."),
            ("当前已检测到 Rockchip USB 刷写链路，可直接执行刷写。", "Rockchip USB flashing link detected. Flashing can start directly."),
            ("当前设备已处于 RP2350 单 USB 刷写链路，可直接执行刷写。", "The device is already on the RP2350 single-USB flashing link. Flashing can start directly."),
            ("当前设备已处于 Loader 模式，可直接执行刷写。", "The device is already in Loader mode. Flashing can start directly."),
            ("当前设备已通过 USB ECM 连接，可执行刷写。", "The device is connected through USB ECM. Flashing can start."),
            ("请先连接 TaishanPi，或让开发板进入 Loader / Maskrom / USB ECM 后再执行镜像刷写。", "Connect TaishanPi first, or put the board into Loader / Maskrom / USB ECM before flashing images."),
            ("请先连接 RP2350 设备，或让开发板进入 RP2350 单 USB / BOOTSEL 后再执行刷写。", "Connect an RP2350 device first, or put the board into RP2350 single-USB / BOOTSEL mode before flashing."),
            ("请先让设备进入可刷写状态后再执行镜像刷写。", "Put the device into a flashable mode before flashing images."),
            ("请先让开发板进入可刷写状态后再执行镜像刷写。", "Put the board into a flashable mode before flashing images."),
            ("当前未检测到可用于刷写的 TaishanPi 连接。请确认开发板已进入 Loader、Maskrom 或 USB ECM 状态。", "No flashable TaishanPi connection was detected. Confirm the board is in Loader, Maskrom, or USB ECM mode."),
            ("当前未检测到可用于刷写的 RP2350 设备连接。请确认开发板已进入 RP2350 单 USB 或 BOOTSEL 状态。", "No flashable RP2350 device connection was detected. Confirm the board is in RP2350 single-USB or BOOTSEL mode."),
            ("当前未检测到可用于刷写的开发板连接。请确认开发板已进入可刷写状态。", "No flashable board connection was detected. Confirm the board is in a flashable mode."),
            ("镜像目录中没有可刷写的镜像文件", "No flashable image files were found in the image directory"),
            ("镜像文件不存在", "Image file does not exist"),
            ("未找到 parameter.txt", "parameter.txt was not found"),
            ("对应镜像文件，期望目录", "image file. Expected directory"),
            ("未找到", "Not found"),
            ("仍在后台执行，请等待完成或超时清理后再提交新的刷写任务。", "is still running in the background. Wait for it to finish or for timeout cleanup before submitting another flash task."),
            ("正在执行，请等待当前刷写任务结束。", "is running. Wait for the current flash task to finish."),
            ("刷写任务", "Flash task"),
            ("未发现用户镜像，请先生成或导入。", "No user image found. Generate or import one first."),
            ("未选择 .img 镜像文件。", "No .img image file selected."),
            ("请选择 .img 文件。", "Choose a .img file."),
            ("IMG 镜像文件不存在", "IMG image file does not exist"),
            ("IMG 镜像文件为空", "IMG image file is empty"),
            ("用户 IMG 镜像烧录", "User IMG Image Flashing"),
            ("选择 .img 文件", "Choose .img File"),
            ("选择一个完整的 TaishanPi .img 镜像文件", "Choose one complete TaishanPi .img image file"),
            ("已选择 IMG 镜像：", "Selected IMG image:"),
            ("选择 .img 后由底层自动识别 RKFW/RKAF 或 raw 格式并执行全量刷写。", "After a .img is selected, the runtime detects RKFW/RKAF or raw format and performs a full flash."),
            ("会覆盖 eMMC 全部内容；请保持 USB 和供电连接，刷写期间窗口会持续显示进度。", "This overwrites the whole eMMC. Keep USB and power connected; the progress window stays visible throughout flashing."),
            ("全量刷写 IMG", "Flash IMG"),
            ("按 .img 镜像执行整机刷写", "Full flash from the .img image"),
            ("IMG 全量刷写", "IMG Full Flash"),
            ("未发现 Mac LLVM 初始镜像，请先挂载或安装 Mac LLVM 离线环境包。", "No Mac LLVM factory image found. Mount or install the Mac LLVM offline environment package first."),
            ("缺少 Linux GCC 初始镜像时会先自动同步。", "Linux GCC factory images are synced automatically when missing."),
            ("按 parameter 刷写全部分区", "Flash all partitions from parameter.txt"),
            ("仅刷 boot", "Flash boot only"),
            ("仅刷 rootfs", "Flash rootfs only"),
            ("仅刷 userdata", "Flash userdata only"),
            ("用户镜像刷写", "User Image Flashing"),
            ("Mac LLVM 初始镜像恢复", "Mac LLVM Factory Image Restore"),
            ("Linux GCC 初始镜像恢复", "Linux GCC Factory Image Restore"),
            ("恢复全部", "Restore All"),
            ("全部", "All"),
            ("启动 Logo", "Boot Logo"),
            ("未选择 logo 文件", "No logo file selected"),
            ("未选择设备树文件", "No device tree file selected"),
            ("选择文件", "Choose File"),
            ("旋转角度", "Rotation"),
            ("比例", "Scale"),
            ("更新后直接刷 Boot", "Flash Boot after update"),
            ("执行 Logo 更新", "Update Logo"),
            ("执行设备树更新", "Update Device Tree"),
            ("设备树", "Device Tree"),
            ("刷入默认 UF2，恢复当前自动控制和调试基础能力", "Flash the default UF2 to restore automatic control and debugging capabilities"),
            ("后续通过问答生成的功能，会以这套初始程序能力为基础进行自动编译、部署和调试。", "Features generated through later prompts will use this initial firmware capability as the base for automatic build, deployment, and debugging."),
            ("先选择导出位置，再回读板载 Flash 为 UF2", "Choose an export location, then read back onboard Flash as UF2"),
            ("将当前板载 Flash 导出为 UF2，便于备份、比对和问题回溯。", "Export onboard Flash as UF2 for backup, comparison, and troubleshooting."),
            ("初始程序路径", "Initial firmware path"),
            ("初始程序", "Initial Firmware"),
            ("保存 Flash", "Save Flash"),
            ("当前没有找到初始程序 UF2", "No initial firmware UF2 found"),
            ("初始程序 UF2 文件不存在", "Initial firmware UF2 file does not exist"),
            ("当前未找到初始程序 UF2", "No initial firmware UF2 found"),
            ("后台处理中", "Processing in background"),
            ("等待操作", "Waiting for action"),
            ("状态探测", "Status Probe"),
            ("状态跟踪", "Status Tracking"),
            ("状态监控", "Status Monitor"),
            ("刷新连接状态失败", "Failed to refresh connection status"),
            ("刷新板卡状态失败", "Failed to refresh board status"),
            ("刷新主机状态失败", "Failed to refresh host status"),
            ("正在刷新开发板状态", "refreshing board status"),
            ("本次保留当前页面状态", "keeping the current page state this time"),
            ("状态刷新暂时超时", "status refresh temporarily timed out"),
            ("后台状态探测失败", "Background status probe failed"),
            ("设备 IP", "Device IP"),
            ("当前没有可复制的设备地址", "No device address is available to copy"),
            ("IP 地址已复制", "IP address copied"),
            ("USB 网络", "USB Network"),
            ("检测到 USB ECM，正在自动恢复主机网络", "USB ECM detected, restoring host network automatically"),
            ("已自动恢复", "Recovered automatically"),
            ("自动恢复未完成，可手动重试", "Automatic recovery did not finish; retry manually"),
            ("自动恢复失败，可手动点击恢复", "Automatic recovery failed; click recover manually"),
            ("插件目录", "Plugin Catalog"),
            ("插件安装", "Plugin Install"),
            ("插件删除", "Plugin Remove"),
            ("插件安装完成", "plugin installed"),
            ("插件已删除", "plugin removed"),
            ("远端插件目录同步失败", "Failed to sync remote plugin catalog"),
            ("任务已启动", "Task started"),
            ("任务已完成", "Task completed"),
            ("执行失败", "Execution failed"),
            ("执行超时", "Execution timed out"),
            ("后台等待超时", "Background wait timed out"),
            ("后台轮询失败", "Background polling failed"),
            ("后台继续确认", "Continuing confirmation in background"),
            ("已转入后台等待", "Moved to background wait"),
            ("仍在后台确认状态", "Still confirming status in background"),
            ("已建立实时订阅", "Live subscription established"),
            ("主机预检", "Host Preflight"),
            ("网络权限安装", "Network Permission Install"),
            ("当前登录用户为空", "Current login user is empty"),
            ("正在请求系统管理员授权", "Requesting administrator authorization"),
            ("安装 OpenCode 插件", "Install OpenCode Plugin"),
            ("未检测到 npm", "npm was not detected"),
            ("SSH 授权", "SSH Authorization"),
            ("正在确认控制服务或 SSH 链路", "Checking control service or SSH link"),
            ("控制链路已就绪，正在提交任务", "Control link is ready, submitting task"),
            ("设备重启", "Device Reboot"),
            ("开发版构建并刷写", "Development Build and Flash"),
            ("开发版构建", "Development Build"),
            ("RP2350 状态检测", "RP2350 Status Check"),
            ("Flash 回读", "Flash Readback"),
            ("初始镜像准备失败", "Factory image preparation failed"),
            ("设备已识别", "Device Detected"),
            ("设备已断开", "Device Disconnected"),
            ("等待识别", "Waiting for Detection"),
            ("当前激活设备", "Active Device"),
            ("当前激活控制设备", "Active Control Device"),
            ("当前在线", "Online"),
            ("设备未连接", "Device Disconnected"),
            ("单 USB 状态", "Single USB Status"),
            ("单 USB 连接", "Single USB Connection"),
            ("RP2350 单 USB", "RP2350 Single USB"),
            ("串口序列号", "Serial Number"),
            ("串口", "Serial Port"),
            ("运行态", "Runtime"),
            ("等待检测", "Waiting for"),
            ("等待连接", "Waiting for Connection"),
            ("选择设备", "Choose Device"),
            ("厂家", "Vendor"),
            ("连接", "Connection"),
            ("接口", "Interface"),
            ("位置", "Location"),
            ("设备 ID", "Device ID"),
            ("当前", "Current"),
            ("台", "device(s)"),
            ("在线", "Online"),
            ("泰山派", "TaishanPi"),
            ("本地 DBT Agent", "Local Embed Labs Agent"),
            ("DBT Agent", "Embed Labs Agent"),
            ("开发板", "Board"),
            ("控制服务", "Control Service"),
            ("控制链路", "Control Link"),
            ("编译环境", "Build Environment"),
            ("初始镜像", "Factory Image"),
            ("用户镜像", "User Image"),
            ("刷写", "Flash"),
            ("状态", "Status"),
            ("设置", "Settings"),
            ("软件更新", "Software Update"),
            ("联系方式", "Contact"),
            ("版本信息", "Version"),
            ("等待", "Waiting"),
            ("未连接", "Disconnected"),
            ("已连接", "Connected"),
            ("正常", "Normal"),
            ("异常", "Abnormal"),
            ("可用", "Available"),
            ("不支持", "Unsupported"),
            ("检查", "Check"),
            ("安装", "Install"),
            ("删除", "Remove"),
            ("取消", "Cancel"),
            ("关闭", "Close"),
            ("确认", "Confirm"),
            ("打开", "Open"),
            ("复制", "Copy"),
            ("完成", "Completed"),
            ("失败", "Failed"),
            ("中文", "Chinese"),
            ("英文", "English"),
        ]
        for (source, target) in replacements {
            result = result.replacingOccurrences(of: source, with: target)
        }
        result = result
            .replacingOccurrences(of: "：", with: ": ")
            .replacingOccurrences(of: "，", with: ", ")
            .replacingOccurrences(of: "。", with: ". ")
            .replacingOccurrences(of: "；", with: "; ")
            .replacingOccurrences(of: "、", with: ", ")
        return result
    }
}

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
        let slot: Int?
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
        let device_id: String?
        let device_uid: String?
        let board_id: String?
        let variant_id: String?
        let connected: Bool?
        let transport_locator: String?
        let display_label: String?
        let display_name: String?
        let manufacturer: String?
        let interface_name: String?
        let transport_name: String?
        let source_name: String?
    }

    struct RP2350RuntimePort: Decodable {
        let device: String?
        let description: String?
        let serial_number: String?
        let vid: Int?
        let pid: Int?
    }

    struct RP2350: Decodable {
        let action: String?
        let board_id: String?
        let variant_id: String?
        let state: String?
        let connected: Bool?
        let bootsel_present: Bool?
        let runtime_resettable: Bool?
        let summary_for_user: String?
        let runtime_port: RP2350RuntimePort?
    }

    let repo_root: String?
    let service: Service?
    let updated_at: String?
    let usb: USB?
    let usbnet: USBNet?
    let board: Board?
    let host: Host?
    let device: Device?
    let device_id: String?
    let active_device_id: String?
    let devices: [Device]?
    let rp2350: RP2350?
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
            return "UF2 刷入"
        case .serialConsole:
            return "USB 串口"
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

    var conciseModelLabel: String {
        guard let modelDirectoryName, !modelDirectoryName.isEmpty, modelDirectoryName != displayName else {
            return displayName
        }
        return "\(displayName) / \(modelDirectoryName)"
    }

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
        shortSummary: "面向 RP2350A 的轻量开发板，已验证单 USB 的 UF2 刷入与串口联动流程。",
        detailSummary: "ColorEasyPICO2 作为独立 BoardProfile 接入，GUI 侧按 RP2350 单 USB 流程展示 UF2 刷入、串口调试和设备状态。刷写与串口共用同一条 USB 连接，不再保留占位说明。",
        integrationStatus: "RP2350 单 USB 流程已验证，UF2 刷入与串口调试统一按同一条 USB 展示。",
        integrationReady: true,
        thumbnailLabel: "PICO2",
        thumbnailSymbol: "memorychip.fill",
        accentStart: Color(red: 0.98, green: 0.53, blue: 0.22),
        accentEnd: Color(red: 0.90, green: 0.24, blue: 0.33),
        capabilities: [.usbProbe, .uf2MassStorage, .uf2Deploy, .serialConsole],
        searchableTerms: ["pico", "pico2", "coloreasy", "rp2350", "rp2350a", "single-usb", "single usb", "uf2", "serial", "coloreasypico2", "嘉立创", "jlc"]
    )

    static let pico2W = SupportedBoard(
        id: "Pico2W",
        englishName: "Pico 2 W",
        displayName: "Pico 2 W",
        manufacturer: "Raspberry Pi",
        modelDirectoryName: nil,
        variantDisplayNames: ["Pico 2 W"],
        shortSummary: "Raspberry Pi Pico 2 W，基于 RP2350 并带有 Wi‑Fi 模块，适合后续扩展无线联网控制场景。",
        detailSummary: "Pico 2 W 作为 Pico 2 系列的 Wi‑Fi 型号，当前 GUI 已按 RP2350 单 USB 流程接入总览、固件和状态页面，并额外保留无线扩展说明。底层能力仍统一走 RP2350 家族协议。",
        integrationStatus: "RP2350 单 USB 流程已接入，当前作为 Raspberry Pi Pico 2 W 型号展示和控制。",
        integrationReady: true,
        thumbnailLabel: "PICO 2 W",
        thumbnailSymbol: "dot.radiowaves.left.and.right",
        accentStart: Color(red: 0.31, green: 0.46, blue: 0.96),
        accentEnd: Color(red: 0.16, green: 0.74, blue: 0.80),
        capabilities: [.usbProbe, .uf2MassStorage, .uf2Deploy, .serialConsole, .networkReachability],
        searchableTerms: ["pico 2 w", "pico2w", "raspberry pi", "rp2350", "wifi", "wireless", "uf2", "serial"]
    )

    static let catalog: [SupportedBoard] = [
        .taishanPi,
        .colorEasyPICO2,
        .pico2W,
    ]
}

private func isRP2350BoardID(_ boardID: String?) -> Bool {
    switch boardID {
    case "ColorEasyPICO2", "Pico2W", "RaspberryPiPico2W":
        return true
    default:
        return false
    }
}

private func localBoardID(forPluginBoardID boardID: String?) -> String? {
    switch boardID {
    case "RaspberryPiPico2W":
        return "Pico2W"
    default:
        return boardID
    }
}

private func pluginBoardID(forLocalBoardID boardID: String?) -> String? {
    switch boardID {
    case "Pico2W":
        return "RaspberryPiPico2W"
    default:
        return boardID
    }
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
}

struct DetectedBoardCandidate: Identifiable, Equatable {
    let id: String
    let deviceID: String?
    let boardID: String
    let variantID: String?
    let displayName: String
    let manufacturer: String
    let interfaceName: String
    let transportName: String
    let transportLocator: String?
    let sourceName: String
    let priority: Int

    var conciseLabel: String {
        guard let variantID, !variantID.isEmpty, variantID != boardID else {
            return boardID
        }
        return "\(boardID) / \(variantID)"
    }

    var selectionLabel: String {
        if let transportLocator, !transportLocator.isEmpty {
            return "\(conciseLabel) / \(transportLocator)"
        }
        return conciseLabel
    }

    var shortTransportLabel: String? {
        guard let transportLocator, !transportLocator.isEmpty else {
            return nil
        }
        let trimmed = transportLocator.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return transportLocator
        }
        return trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    }
}

struct DeviceSelectionPrompt: Identifiable, Equatable {
    let id = UUID()
    let candidates: [DetectedBoardCandidate]
}

struct RP2350FlashTargetPrompt: Identifiable, Equatable {
    let id = UUID()
    let boardID: String
    let variantID: String
    let boardDisplayName: String
    let candidates: [DetectedBoardCandidate]
}

struct RP2350BoardStatusContext {
    let connected: Bool
    let connectionLabel: String
    let stateLabel: String
    let runtimePort: String
    let summary: String
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
    let device_id: String?
    let active_device_id: String?
    let devices: [ToolkitStatus.Device]?
    let updated_at: String?
    let runtime_status: ToolkitStatus?
    let last_reconcile_at: String?
    let last_probe_at: String?
    let refresh_in_progress: Bool?
    let staleness_ms: Int?
}

struct AgentActionPreflightResponse: Decodable {
    let ok: Bool?
    let ready: Bool?
    let operation_id: String?
    let board_id: String?
    let variant_id: String?
    let message: String?
    let status_summary: AgentStatusSummaryResponse?
}

struct ToolkitTask: Decodable {
    let id: String?
    let action: String?
    let status: String?
    let status_label: String?
    let progress: Double?
    let progress_stage: String?
    let progress_text: String?
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

    var activityTitle: String {
        switch self {
        case .flash:
            return "刷写恢复"
        }
    }

    var initialLine: String {
        switch self {
        case .flash:
            return "刷写已完成，等待设备退出 Loader 并重启"
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
    let activeDeviceID: String
    let activeBoardID: String
    let connectedDeviceCount: Int
    let connectedDeviceSignature: String
    let rp2350State: String
    let rp2350Connected: Bool
    let dockerReady: Bool
    let usbnetHelperInstalled: Bool
}

enum TaishanPiDevelopmentMode: String, CaseIterable, Identifiable {
    case dockerLinux = "docker_linux"
    case macLLVM = "mac_llvm"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dockerLinux:
            return "Linux GCC"
        case .macLLVM:
            return "Mac LLVM"
        }
    }

    var buildModeArgument: String {
        switch self {
        case .dockerLinux:
            return "docker"
        case .macLLVM:
            return "local-llvm"
        }
    }

    var subtitle: String {
        switch self {
        case .dockerLinux:
            return "Docker 容器 + Linux 发布工作区"
        case .macLLVM:
            return "Apple Silicon 原生 LLVM 工具链"
        }
    }
}

struct DevelopmentInstallStatus: Equatable {
    var dockerReady = false
    var officialImageReady = false
    var releaseVolumeReady = false
    var hostImagesReady = false
    var rkflashtoolReady = false
    var llvmSDKRoot = "/Volumes/LLVM-TSPI/sdk-tools"
    var llvmSDKMounted = false
    var llvmSDKCaseSensitive = false
    var llvmEntryScriptsReady = false
    var llvmCrossWrappersReady = false
    var llvmHostWrappersReady = false
    var llvmClangReady = false
    var llvmLLDReady = false
    var llvmObjcopyReady = false
    var llvmReadelfReady = false
    var llvmPython3Ready = false
    var llvmDtcReady = false
    var llvmFakerootReady = false
    var llvmMke2fsReady = false
    var llvmTune2fsReady = false
    var llvmFactoryImagesReady = false
    var llvmCustomImagesReady = false
    var llvmBootProbeImagesReady = false
    var codexAvailable = false
    var codexPluginInstalled = false
    var openCodeAvailable = false
    var npmReady = false
    var openCodePluginInstalled = false
    var updatedAt = ""

    var dockerEnvironmentReady: Bool {
        dockerReady &&
        officialImageReady &&
        releaseVolumeReady &&
        hostImagesReady &&
        rkflashtoolReady
    }

    var dockerEnvironmentPartial: Bool {
        dockerReady ||
        officialImageReady ||
        releaseVolumeReady ||
        hostImagesReady ||
        rkflashtoolReady
    }

    var llvmHostToolsReady: Bool {
        llvmClangReady &&
        llvmLLDReady &&
        llvmObjcopyReady &&
        llvmReadelfReady &&
        llvmPython3Ready &&
        llvmDtcReady &&
        llvmFakerootReady &&
        llvmMke2fsReady &&
        llvmTune2fsReady
    }

    var llvmSDKReady: Bool {
        llvmSDKMounted &&
        llvmSDKCaseSensitive &&
        llvmEntryScriptsReady &&
        llvmCrossWrappersReady &&
        llvmHostWrappersReady
    }

    var llvmEnvironmentReady: Bool {
        llvmSDKReady &&
        llvmHostToolsReady &&
        llvmFactoryImagesReady
    }

    var llvmEnvironmentPartial: Bool {
        llvmSDKMounted ||
        llvmEntryScriptsReady ||
        llvmCrossWrappersReady ||
        llvmHostWrappersReady ||
        llvmClangReady ||
        llvmLLDReady ||
        llvmObjcopyReady ||
        llvmReadelfReady ||
        llvmPython3Ready ||
        llvmDtcReady ||
        llvmFakerootReady ||
        llvmMke2fsReady ||
        llvmTune2fsReady ||
        llvmFactoryImagesReady ||
        llvmCustomImagesReady ||
        llvmBootProbeImagesReady
    }
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
    case invalidJSON(String)
    case commandFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
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

struct RP2350MonitorPin: Identifiable, Equatable {
    var id: Int { gpio }
    let gpio: Int
    let owner: Int
}

struct RP2350MonitorChannel: Identifiable, Equatable {
    let id: Int
    let type: String
    let active: Bool
    let detail: String
}

struct RP2350MonitorEventLine: Identifiable, Equatable {
    let id = UUID()
    let kind: String
    let text: String
}

struct RP2350MonitorWiFiProfile: Identifiable, Equatable {
    var id: Int { slot }
    let slot: Int
    let valid: Bool
    let active: Bool
    let ssid: String
    let lastError: String

    var label: String {
        let base = valid ? "slot \(slot): \(ssid)" : "slot \(slot): 未配置"
        let activeSuffix = active ? " / 当前" : ""
        let errorSuffix = lastError.isEmpty ? "" : " / \(lastError)"
        return base + activeSuffix + errorSuffix
    }
}

struct RP2350MonitorWiFiScanResult: Identifiable, Equatable {
    var id: String { "\(ssid)-\(channel)-\(rssi)" }
    let ssid: String
    let rssi: Int
    let channel: Int
    let auth: Int

    var label: String {
        "\(ssid) / RSSI \(rssi) / CH \(channel)"
    }
}

struct RP2350LogicCaptureChunk: Identifiable, Equatable {
    var id: Int { offsetWords }
    let captureID: Int
    let offsetWords: Int
    let words: Int
    let pinBase: Int
    let pinCount: Int
    let sampleRate: Int
    let samples: Int
    let recordBits: Int
    let hex: String
}

struct RP2350LogicTracePoint: Identifiable, Equatable {
    let id: Int
    let sampleIndex: Int
    let level: Bool
}

struct RP2350MonitorState {
    enum Availability: Equatable {
        case unknown
        case probing
        case supported
        case unsupported(String)
    }

    var availability: Availability = .unknown
    var serialDevice = ""
    var firmwareVersion = "-"
    var firmwareBoard = "-"
    var links: [String] = []
    var wifiSummary = "-"
    var wifiConfigured = false
    var wifiSSID = ""
    var wifiStationStatus = "unknown"
    var wifiStationIP = "0.0.0.0"
    var wifiAPActive = false
    var wifiAPSSID = ""
    var wifiAPIP = "192.168.4.1"
    var wifiTCPPort = "4242"
    var wifiActiveProfile = 0
    var wifiLastError = ""
    var wifiProfiles: [RP2350MonitorWiFiProfile] = []
    var wifiScanActive = false
    var wifiScanResults: [RP2350MonitorWiFiScanResult] = []
    var logicSupported = false
    var logicConfigured = false
    var logicRunning = false
    var logicComplete = false
    var logicCaptureID = 0
    var logicPinBase = 0
    var logicPinCount = 0
    var logicSampleRate = 0
    var logicSamples = 0
    var logicWords = 0
    var logicRecordBits = 32
    var logicTriggerPin = -1
    var logicTriggerLevel = true
    var logicBufferWordsMax = 0
    var logicBufferBytes = 0
    var logicChunkBytes = 0
    var logicCaptureChunks: [RP2350LogicCaptureChunk] = []
    var logicCaptureWords: [UInt32] = []
    var logicLastReadAt: Date?
    var bufferSummary = "-"
    var eventDepth = 0
    var droppedEvents = 0
    var newestSeq = 0
    var pins: [RP2350MonitorPin] = []
    var channels: [RP2350MonitorChannel] = []
    var recentLines: [RP2350MonitorEventLine] = []
    var lastResponse = "等待检测"
    var lastUpdated: Date?

    var supported: Bool {
        if case .supported = availability {
            return true
        }
        return false
    }

    var tabAvailable: Bool {
        supported || firmwareVersion != "-" || firmwareBoard != "-" || !links.isEmpty
    }

    var wifiStationOnline: Bool {
        wifiStationStatus.lowercased() == "up" && wifiStationIP != "0.0.0.0" && !wifiStationIP.isEmpty
    }

    var wifiServiceEndpoint: String {
        guard wifiStationOnline else { return "-" }
        return "\(wifiStationIP):\(wifiTCPPort)"
    }

    var wifiDetail: String {
        if wifiStationOnline {
            let ssid = wifiSSID.isEmpty ? "当前 Wi-Fi" : wifiSSID
            return "已连接 \(ssid)，控制服务地址 \(wifiServiceEndpoint)。该地址会自动填入 Wi-Fi 服务参数。"
        }
        if !wifiConfigured {
            if wifiAPActive {
                let ssid = wifiAPSSID.isEmpty ? "RP2350-Monitor" : wifiAPSSID
                return "Wi-Fi 未配置。可连接 AP \(ssid)（\(wifiAPIP)，HTTP 80 / TCP \(wifiTCPPort)）进入配置页，也可在下方通过 USB 写入 SSID/密码。"
            }
            return "Wi-Fi 未配置。请通过 USB 写入 SSID/密码，或开启 AP 后连接配置。"
        }
        let ssid = wifiSSID.isEmpty ? "已保存配置" : wifiSSID
        var detail = "\(ssid) 已配置，当前未连上路由器（状态：\(wifiStationStatus)）。"
        if !wifiLastError.isEmpty {
            detail += " 最近错误：\(wifiLastError)。"
        }
        if wifiAPActive {
            let ap = wifiAPSSID.isEmpty ? "RP2350-Monitor" : wifiAPSSID
            detail += " 可连接 AP \(ap)（\(wifiAPIP)）恢复配置，或通过 USB 重新连接。"
        }
        return detail
    }

    var wifiProfilesSummary: String {
        let labels = wifiProfiles.map(\.label)
        return labels.isEmpty ? "暂无 Wi-Fi 配置槽信息。" : labels.joined(separator: "；")
    }

    var wifiScanSummary: String {
        if wifiScanActive {
            return "正在扫描 2.4GHz Wi-Fi..."
        }
        let labels = wifiScanResults.prefix(4).map(\.label)
        return labels.isEmpty ? "暂无扫描结果。" : labels.joined(separator: "；")
    }

    var logicStatusLabel: String {
        if logicRunning { return "采集中" }
        if logicComplete { return "已完成" }
        if logicConfigured { return "已配置" }
        return "未配置"
    }

    var logicDurationText: String {
        guard logicSampleRate > 0, logicSamples > 0 else { return "-" }
        let seconds = Double(logicSamples) / Double(logicSampleRate)
        if seconds < 0.001 {
            return String(format: "%.1f us", seconds * 1_000_000)
        }
        if seconds < 1 {
            return String(format: "%.2f ms", seconds * 1000)
        }
        return String(format: "%.3f s", seconds)
    }

    var logicMemorySummary: String {
        guard logicBufferWordsMax > 0 else { return "-" }
        return "\(logicWords)/\(logicBufferWordsMax) words"
    }

    var logicCaptureSummary: String {
        if logicCaptureChunks.isEmpty {
            return "尚未读取捕获数据。"
        }
        return "已读取 \(logicCaptureWords.count) words，\(logicCaptureChunks.count) 个数据块。"
    }

    var isProbing: Bool {
        if case .probing = availability {
            return true
        }
        return false
    }

    var availabilityLabel: String {
        switch availability {
        case .unknown:
            return "未检测"
        case .probing:
            return "检测中"
        case .supported:
            return "可用"
        case .unsupported:
            if tabAvailable {
                return "链路异常"
            }
            return "不支持"
        }
    }

    var availabilityDetail: String {
        switch availability {
        case .unknown:
            return "尚未对当前 Pico 运行态串口执行 RP2350-Monitor hello 探测。"
        case .probing:
            return "正在通过 USB CDC JSONL 协议探测当前固件。"
        case .supported:
            let version = firmwareVersion == "-" ? "未知版本" : firmwareVersion
            return "已检测到 RP2350-Monitor 固件 \(version)，控制页已开放。"
        case let .unsupported(reason):
            return reason
        }
    }
}

struct RP2350MonitorTransactionResult {
    let lines: [String]
    let documents: [[String: Any]]
    let response: [String: Any]?
}

enum RP2350MonitorClient {
    static func transactSerial(
        device: String,
        payload: [String: Any],
        timeout: TimeInterval = 2.5
    ) async throws -> RP2350MonitorTransactionResult {
        if !device.hasPrefix("/dev/") {
            let endpoint = try parseTCPEndpoint(device)
            return try await transactTCP(host: endpoint.host, port: endpoint.port, payload: payload, timeout: timeout)
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try transactSerialSync(device: device, payload: payload, timeout: timeout)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func transactTCP(
        host: String,
        port: Int,
        payload: [String: Any],
        timeout: TimeInterval = 2.5
    ) async throws -> RP2350MonitorTransactionResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try transactTCPSync(host: host, port: port, payload: payload, timeout: timeout)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func transactSerialSync(
        device: String,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> RP2350MonitorTransactionResult {
        let fd = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            throw ToolkitGUIError.commandFailed("无法打开 Pico 串口：\(device)")
        }
        defer { close(fd) }

        try configureSerial(fd: fd)
        tcflush(fd, TCIOFLUSH)
        return try transactOpenDescriptor(fd: fd, payload: payload, timeout: timeout)
    }

    private static func transactTCPSync(
        host: String,
        port: Int,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> RP2350MonitorTransactionResult {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ToolkitGUIError.commandFailed("无法创建 Wi-Fi TCP 连接：errno \(errno)")
        }
        defer { close(fd) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw ToolkitGUIError.commandFailed("Wi-Fi IP 地址无效：\(host)")
        }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let connectResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connectResult < 0 && errno != EINPROGRESS {
            throw ToolkitGUIError.commandFailed("连接 RP2350-Monitor Wi-Fi \(host):\(port) 失败：errno \(errno)")
        }
        if connectResult < 0 {
            var pollItem = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let pollResult = poll(&pollItem, 1, Int32(max(500, Int(timeout * 1000))))
            guard pollResult > 0 else {
                throw ToolkitGUIError.timeout("连接 RP2350-Monitor Wi-Fi \(host):\(port) 超时")
            }
            var socketError: Int32 = 0
            var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength)
            guard socketError == 0 else {
                throw ToolkitGUIError.commandFailed("连接 RP2350-Monitor Wi-Fi \(host):\(port) 失败：errno \(socketError)")
            }
        }

        return try transactOpenDescriptor(fd: fd, payload: payload, timeout: timeout)
    }

    private static func transactOpenDescriptor(
        fd: Int32,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> RP2350MonitorTransactionResult {
        let commandName = payload["cmd"] as? String
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        var commandData = data
        commandData.append(0x0A)
        try writeAll(fd: fd, data: commandData)

        let deadline = Date().addingTimeInterval(timeout)
        var pending = Data()
        var lines: [String] = []
        var documents: [[String: Any]] = []
        var response: [String: Any]?
        var buffer = [UInt8](repeating: 0, count: 512)

        while Date() < deadline {
            var pollItem = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let remainingMS = max(50, min(250, Int(deadline.timeIntervalSinceNow * 1000)))
            let pollResult = poll(&pollItem, 1, Int32(remainingMS))
            if pollResult < 0 {
                if errno == EINTR {
                    continue
                }
                throw ToolkitGUIError.commandFailed("读取 Pico 串口失败：errno \(errno)")
            }
            if pollResult == 0 {
                continue
            }
            if (pollItem.revents & Int16(POLLIN)) == 0 {
                continue
            }

            let bufferCapacity = buffer.count
            let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.baseAddress else { return -1 }
                return read(fd, baseAddress, bufferCapacity)
            }
            if count < 0 {
                if errno == EAGAIN || errno == EINTR {
                    continue
                }
                throw ToolkitGUIError.commandFailed("读取 Pico 串口失败：errno \(errno)")
            }
            if count == 0 {
                continue
            }
            pending.append(buffer, count: count)
            while let newlineIndex = pending.firstIndex(of: 0x0A) {
                let lineData = pending[..<newlineIndex]
                pending.removeSubrange(...newlineIndex)
                let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !line.isEmpty else {
                    continue
                }
                lines.append(line)
                if let document = parseJSONLine(line) {
                    documents.append(document)
                    if document["type"] as? String == "resp",
                       document["cmd"] as? String == commandName {
                        response = document
                        return RP2350MonitorTransactionResult(lines: lines, documents: documents, response: response)
                    }
                }
            }
        }

        if let commandName {
            throw ToolkitGUIError.timeout("RP2350-Monitor 命令 \(commandName) 等待响应超时")
        }
        throw ToolkitGUIError.timeout("RP2350-Monitor 命令等待响应超时")
    }

    private static func parseTCPEndpoint(_ endpoint: String) throws -> (host: String, port: Int) {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ToolkitGUIError.commandFailed("Wi-Fi IP 地址不能为空。")
        }
        if let separator = trimmed.lastIndex(of: ":") {
            let host = String(trimmed[..<separator])
            let portText = String(trimmed[trimmed.index(after: separator)...])
            guard let port = Int(portText), port > 0, port <= 65535 else {
                throw ToolkitGUIError.commandFailed("Wi-Fi 端口无效：\(portText)")
            }
            return (host, port)
        }
        return (trimmed, DEFAULT_RPMON_TCP_PORT)
    }

    private static let DEFAULT_RPMON_TCP_PORT = 4242

    private static func configureSerial(fd: Int32) throws {
        var attrs = termios()
        guard tcgetattr(fd, &attrs) == 0 else {
            throw ToolkitGUIError.commandFailed("读取串口参数失败：errno \(errno)")
        }
        cfmakeraw(&attrs)
        cfsetspeed(&attrs, speed_t(B115200))
        attrs.c_cflag |= tcflag_t(CLOCAL | CREAD)
        guard tcsetattr(fd, TCSANOW, &attrs) == 0 else {
            throw ToolkitGUIError.commandFailed("配置串口参数失败：errno \(errno)")
        }
    }

    private static func writeAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let written = write(fd, baseAddress.advanced(by: offset), data.count - offset)
                if written < 0 {
                    if errno == EAGAIN || errno == EINTR {
                        continue
                    }
                    throw ToolkitGUIError.commandFailed("写入 Pico 串口失败：errno \(errno)")
                }
                offset += written
            }
        }
        tcdrain(fd)
    }

    private static func parseJSONLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
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

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                do {
                    try process.run()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
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

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
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
            product.contains("ethernet gadget") ||
            product.contains("rndis") ||
            product.contains("cdc ecm") ||
            product.contains("cdc-ecm") ||
            product.contains("usb network") ||
            product.contains("ncm") ||
            product.contains("tspi") ||
            product.contains("coloreasy") ||
            product.contains("pico") ||
            product.contains("pico2") ||
            product.contains("rp2350")
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
    private let runtimeBinaryName = "dbtctl"

    static func fileSafeTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
    private let localAgentPort = 18082
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
    @Published var taishanPiRawImagePath = ""
    @Published var rp2350UF2Path = ""
    @Published var rp2350ReadbackPath = ""
    @Published var rp2350LogLines = "6"
    @Published var rp2350Monitor = RP2350MonitorState()
    @Published var rp2350MonitorBusy = false
    @Published var rp2350MonitorTransportMode = "usb"
    @Published var rp2350MonitorTCPHost = ""
    @Published var rp2350MonitorTCPPort = "4242"
    @Published var rp2350MonitorWiFiSlot = "0"
    @Published var rp2350MonitorWiFiSSID = ""
    @Published var rp2350MonitorWiFiPassword = ""
    @Published var rp2350MonitorGPIOChannelID = "4"
    @Published var rp2350MonitorGPIOPin = "16"
    @Published var rp2350MonitorGPIODirection = "output"
    @Published var rp2350MonitorGPIOPull = "none"
    @Published var rp2350MonitorGPIOInitialLevel = false
    @Published var rp2350MonitorGPIOAnalyzerChannelID = "5"
    @Published var rp2350MonitorGPIOAnalyzerPin = "17"
    @Published var rp2350MonitorGPIOAnalyzerPins = "17"
    @Published var rp2350MonitorGPIOAnalyzerPull = "up"
    @Published var rp2350MonitorGPIOAnalyzerLive = false
    @Published var rp2350MonitorGPIOAnalyzerActivePins: [Int: Int] = [:]
    @Published var rp2350LogicPinBase = "16"
    @Published var rp2350LogicPinCount = "4"
    @Published var rp2350LogicSampleRate = "1000000"
    @Published var rp2350LogicSamples = "2048"
    @Published var rp2350LogicTriggerEnabled = false
    @Published var rp2350LogicTriggerPin = "16"
    @Published var rp2350LogicTriggerLevel = true
    @Published var rp2350MonitorUARTChannelID = "1"
    @Published var rp2350MonitorUARTInstance = "0"
    @Published var rp2350MonitorUARTTX = "0"
    @Published var rp2350MonitorUARTRX = "1"
    @Published var rp2350MonitorUARTBaud = "115200"
    @Published var rp2350MonitorUARTLoopback = false
    @Published var rp2350MonitorUARTHex = "48656c6c6f"
    @Published var rp2350MonitorSPIChannelID = "2"
    @Published var rp2350MonitorSPIInstance = "0"
    @Published var rp2350MonitorSPISCK = "2"
    @Published var rp2350MonitorSPIMOSI = "3"
    @Published var rp2350MonitorSPIMISO = "0"
    @Published var rp2350MonitorSPICS = "1"
    @Published var rp2350MonitorSPIBaud = "1000000"
    @Published var rp2350MonitorSPIHex = "9f000000"
    @Published var rp2350MonitorSPIReadLength = "4"
    @Published var rp2350MonitorI2CChannelID = "3"
    @Published var rp2350MonitorI2CInstance = "0"
    @Published var rp2350MonitorI2CSDA = "4"
    @Published var rp2350MonitorI2CSCL = "5"
    @Published var rp2350MonitorI2CBaud = "100000"
    @Published var rp2350MonitorI2CAddress = "0x50"
    @Published var rp2350MonitorI2CWriteHex = "00"
    @Published var rp2350MonitorI2CReadLength = "16"
    @Published var rp2350MonitorRawCommand = "{\"cmd\":\"status\"}"
    @Published var rp2350MonitorEventCount = "32"
    @Published var localArtifactsDir = ""
    @Published var localArtifactValidation = LocalArtifactValidationState()
    @Published var inlineErrorMessage = ""
    @Published var footerFlashOn = false
    @Published var pendingTaskTitle = ""
    @Published var selectedActivityEntry: ActivityEntry?
    @Published var currentTask: ToolkitTask?
    @Published var activeBackgroundFlashTaskID: String?
    @Published var activeBackgroundFlashTitle = ""
    @Published var fileDialogActive = false
    @Published var remoteBoardPluginEntries: [String: RemoteBoardPluginEntry] = [:]
    @Published var boardPluginCatalogVersions: [String: String] = [:]
    @Published var installedBoardPlugins: [String: String] = [:]
    @Published var installedBoardPluginMetadata: [String: InstalledBoardPluginMetadata] = [:]
    @Published var boardPluginOperations: [String: BoardPluginOperationState] = [:]
    @Published var boardPluginAlert: BoardPluginAlert?
    @Published var boardPluginCatalogCheckedAt = ""
    @Published var boardCatalogResetRequestID = UUID()
    @Published var detectedBoardCandidates: [DetectedBoardCandidate] = []
    @Published var connectedBoardID: String?
    @Published var connectedBoardVariantID: String?
    @Published var connectedBoardDisplayName: String?
    @Published var preferredControlBoardID: String?
    @Published var preferredControlDeviceID: String?
    @Published var showingSupportedBoardCatalog = true
    @Published var deviceSelectionPrompt: DeviceSelectionPrompt?
    @Published var rp2350FlashTargetPrompt: RP2350FlashTargetPrompt?
    @Published var taishanPiDevelopmentMode: TaishanPiDevelopmentMode = .dockerLinux
    @Published var developmentInstallStatus = DevelopmentInstallStatus()
    @Published var installerLastDetail = "等待检查"
    @Published var toolkitUpdateStatus = ToolkitUpdateStatus()
    @Published var updaterLastDetail = "等待检查"
    @Published var actionAvailability: [ActionPrecondition: ActionAvailabilityState] = [:]
    @Published var automaticToolkitUpdateInProgress = false
    @Published var appLanguage: AppLanguage = .stored
    @Published var postFlashRecoveryActive = false
    @Published var postFlashRecoveryFinished = false
    @Published var postFlashRecoverySucceeded = false
    @Published var postFlashRecoveryTitle = "设备恢复"
    @Published var postFlashRecoveryStatus = ""
    @Published var postFlashRecoveryProgress = ""
    @Published var postFlashRecoveryProgressValue: Double?
    @Published var postFlashRecoveryLines: [String] = []
    @Published var popoverCloseRequestID = UUID()

    private var didBootstrapLocalAgent = false
    private var localAgentStartInProgress = false
    private var lastLocalAgentStartAttemptAt: Date?
    private var didCleanupLocalAgentProcesses = false
    private var ownedLocalAgentPID: Int32?
    private var lastRefreshErrorSignature = ""
    private var lastSnapshot: StatusSnapshot?
    private var statusRefreshTask: Task<Void, Never>?
    private var lastStatusRefreshStartedAt: Date?
    private var queuedStatusRefreshPending = false
    private var queuedStatusRefreshSilent = true
    private var queuedStatusRefreshForce = false
    private var rp2350MonitorProbeTask: Task<Void, Never>?
    private var rp2350MonitorLastProbeDevice = ""
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
    private var backgroundTaskPolls: [String: Task<Void, Never>] = [:]
    private var automaticToolkitUpdateTask: Task<Void, Never>?
    private var automaticUSBNetRepairTask: Task<Void, Never>?
    private var postFlashRecoveryTask: Task<Void, Never>?
    private var boardPluginCatalogSyncTask: Task<Void, Never>?
    private var actionAvailabilityTask: Task<Void, Never>?
    private var dismissedFinishedTaskIDs: Set<String> = []
    private var monitoringStarted = false
    private var lastEventAt = Date()
    private var lastIncompatibleServiceRecoveryAt: Date?
    private var localAgentUnavailableReason: String?
    private var boardStateGraceUntil: Date?
    private var boardPingFalseCount = 0
    private var boardSSHFalseCount = 0
    private var boardControlFalseCount = 0
    private let boardFalseThreshold = 3
    private let taishanPiDevelopmentModeDefaultsKey = "taishanPiDevelopmentMode"
    private var hasUserSelectedTaishanPiDevelopmentMode = false
    private var selectedDetectedCandidateID: String?
    private var boardCatalogBaselineSignature: String?
    private var shouldRelaunchAfterToolkitUpdate = false
    private var lastAutomaticUSBNetRepairAt: Date?
    private var lastAutomaticUSBNetRepairSignature = ""
    private var lastLocalUSBRemovedAt: Date?
    private var suppressConnectedAgentStatusUntil: Date?
    private var lastBackgroundStatusNotificationAt: Date?
    private var lastBackgroundStatusNotificationMessage = ""
    private var recentActivityFingerprintAt: [String: Date] = [:]
    private var recentUserNotificationAt: [String: Date] = [:]
    private var rp2350ModeTransitionUntil: Date?
    private var taishanLoaderTransitionUntil: Date?

    private enum BoardLogicFamily {
        case taishanPi
        case colorEasyPICO2
        case generic
    }

    private var usesEventDrivenStatus: Bool {
        true
    }

    var rp2350ModeTransitionActive: Bool {
        guard let until = rp2350ModeTransitionUntil else { return false }
        return until > Date()
    }

    var rp2350ModeTransitionHint: String {
        "设备模式切换中，请等待状态更新完成"
    }

    var taishanLoaderTransitionActive: Bool {
        guard let until = taishanLoaderTransitionUntil else { return false }
        return until > Date()
    }

    var taishanLoaderTransitionHint: String {
        "正在进入 Loader 模式，请等待 USB 重新枚举"
    }

    private func boardLogicFamily(
        boardID: String? = nil,
        status: ToolkitStatus? = nil,
        agentStatus: AgentStatusSummaryResponse? = nil
    ) -> BoardLogicFamily {
        let resolvedBoardID = boardID
            ?? agentStatus?.board_id
            ?? agentStatus?.runtime_status?.device?.board_id
            ?? status?.device?.board_id
            ?? detectedBoard?.id
            ?? connectedBoardID

        switch resolvedBoardID {
        case "TaishanPi":
            return .taishanPi
        case let value where isRP2350BoardID(value):
            return .colorEasyPICO2
        default:
            return .generic
        }
    }

    private var boardLinkLooksHealthy: Bool {
        guard status?.usb?.mode == "usb-ecm", status?.usbnet?.configured == true else {
            return false
        }
        if taishanUSBECMTransportOnly() {
            return false
        }
        return status?.board?.ping == true ||
            status?.board?.ssh_port_open == true ||
            status?.board?.control_service == true
    }

    func taishanUSBECMTransportOnly(status: ToolkitStatus? = nil) -> Bool {
        let current = status ?? self.status
        guard boardLogicFamily(status: current) == .taishanPi else {
            return false
        }
        guard (current?.usb?.mode ?? "").lowercased() == "usb-ecm",
              current?.usbnet?.configured == true else {
            return false
        }
        return current?.board?.ping != true &&
            current?.board?.ssh_port_open != true &&
            current?.board?.control_service != true
    }

    var taishanUSBECMTransportOnlyWarningText: String {
        "当前仅检测到 USB ECM 枚举，板端没有响应 Ping / SSH / 控制服务。GUI 不能再通过运行态链路执行重启或切换 Loader；如需继续刷写，请先让开发板手动进入 Loader 或 Maskrom 模式。"
    }

    init() {
        preferredControlBoardID = UserDefaults.standard.string(forKey: "preferredControlBoardID")
        preferredControlDeviceID = UserDefaults.standard.string(forKey: "preferredControlDeviceID")
        if let raw = UserDefaults.standard.string(forKey: taishanPiDevelopmentModeDefaultsKey),
           let mode = TaishanPiDevelopmentMode(rawValue: raw) {
            taishanPiDevelopmentMode = mode
            hasUserSelectedTaishanPiDevelopmentMode = true
        }
        configureRP2350Defaults()
        loadInstalledBoardPlugins()
        requestNotificationPermission()
    }

    nonisolated static func toolkitSupportRootCandidates() -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let environment = ProcessInfo.processInfo.environment
        var candidates: [URL] = []
        if let override = environment["DBT_TOOLKIT_APP_SUPPORT_DIR"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        if let override = environment["RK356X_TOOLKIT_APP_SUPPORT_DIR"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        candidates.append(contentsOf: [
            home.appendingPathComponent("Library/development-board-toolchain", isDirectory: true),
        ])

        var seen = Set<String>()
        return candidates.filter {
            let path = $0.standardizedFileURL.path
            guard !seen.contains(path) else {
                return false
            }
            seen.insert(path)
            return true
        }
    }

    nonisolated static func resolveToolkitSupportRoot() -> URL {
        let fileManager = FileManager.default
        let candidates = toolkitSupportRootCandidates()
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    nonisolated static func sharedRuntimeRootURLStatic() -> URL {
        resolveToolkitSupportRoot().appendingPathComponent("runtime", isDirectory: true)
    }

    func rp2350BoardAssetsRootURL(boardID: String) -> URL {
        appSupportRootURL()
            .appendingPathComponent("families", isDirectory: true)
            .appendingPathComponent("rp2350", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent(boardID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
    }

    func legacyRuntimeAssetsRootURL() -> URL {
        sharedRuntimeRootURL().appendingPathComponent("assets", isDirectory: true)
    }

    func rp2350InitialProgramURL(boardID: String? = nil) -> URL {
        let resolvedBoardID = boardID
            ?? preferredControlBoardID
            ?? connectedBoardID
            ?? currentControlCandidate?.boardID
            ?? status?.device?.board_id
            ?? "ColorEasyPICO2"
        let normalizedBoardID: String
        switch resolvedBoardID {
        case "Pico2W", "RaspberryPiPico2W":
            normalizedBoardID = "RaspberryPiPico2W"
        default:
            normalizedBoardID = "ColorEasyPICO2"
        }
        let candidates = [
            rp2350BoardAssetsRootURL(boardID: normalizedBoardID).appendingPathComponent("initial.uf2", isDirectory: false),
            legacyRuntimeAssetsRootURL().appendingPathComponent("\(normalizedBoardID)/initial.uf2", isDirectory: false),
            rp2350BoardAssetsRootURL(boardID: "ColorEasyPICO2").appendingPathComponent("initial.uf2", isDirectory: false),
            legacyRuntimeAssetsRootURL().appendingPathComponent("ColorEasyPICO2/initial.uf2", isDirectory: false),
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    private func configureRP2350Defaults() {
        let candidateUF2 = rp2350InitialProgramURL()
        if rp2350UF2Path.isEmpty, FileManager.default.fileExists(atPath: candidateUF2.path) {
            rp2350UF2Path = candidateUF2.path
        }
    }

    private func refreshRP2350DefaultUF2Path(for boardID: String?) {
        guard isRP2350BoardID(boardID) else {
            return
        }
        let currentPath = rp2350UF2Path.trimmingCharacters(in: .whitespacesAndNewlines)
        let managedRoots = [
            appSupportRootURL()
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rp2350", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .path,
            legacyRuntimeAssetsRootURL().path,
        ]
        let shouldReplace = currentPath.isEmpty || managedRoots.contains(where: { currentPath.hasPrefix($0) })
        guard shouldReplace else {
            return
        }
        let candidateUF2 = rp2350InitialProgramURL(boardID: boardID)
        if FileManager.default.fileExists(atPath: candidateUF2.path) {
            rp2350UF2Path = candidateUF2.path
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func loadInstalledBoardPlugins() {
        ensureSeededBoardPlugins()
        let url = boardPluginRegistryURL()
        let registryInstalled: [String: String]
        if let data = try? Data(contentsOf: url),
           let registry = try? JSONDecoder().decode(InstalledBoardPluginsRegistry.self, from: data) {
            registryInstalled = registry.installed
        } else {
            registryInstalled = [:]
        }
        installedBoardPlugins = registryInstalled.merging(discoveredInstalledUserPluginVersions()) { current, _ in current }
        reloadInstalledBoardPluginMetadata()
    }

    func persistInstalledBoardPlugins() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: userBoardPluginsRootURL(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(InstalledBoardPluginsRegistry(installed: installedBoardPlugins))
        try data.write(to: boardPluginRegistryURL(), options: .atomic)
    }

    func reloadInstalledBoardPluginMetadata() {
        let mergedInstalled = installedBoardPlugins.merging(discoveredInstalledUserPluginVersions()) { current, _ in current }
        var validInstalled: [String: String] = [:]
        for (boardID, version) in mergedInstalled {
            let localID = localBoardID(forPluginBoardID: boardID) ?? boardID
            validInstalled[localID] = version
        }
        var metadata: [String: InstalledBoardPluginMetadata] = [:]

        for (boardID, version) in validInstalled {
            do {
                let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
                let installRoot = boardPluginInstallRootURL(for: boardID)
                let validated = try validateInstalledBoardPlugin(at: installRoot, expectedBoardID: pluginID, expectedVersion: version, pluginSource: "user")
                metadata[boardID] = validated
            } catch {
                validInstalled.removeValue(forKey: boardID)
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

    var localAgentBaseURL: URL {
        URL(string: "http://127.0.0.1:\(localAgentPort)")!
    }

    var remoteBoardPluginIndexURL: URL {
        URL(string: "https://raw.githubusercontent.com/kkwell/development-board-toolchain/main/board_plugins/index.json")!
    }

    func appSupportRootURL() -> URL {
        Self.resolveToolkitSupportRoot()
    }

    func rk356xTaishanPiVariantRootURL() -> URL {
        appSupportRootURL()
            .appendingPathComponent("families", isDirectory: true)
            .appendingPathComponent("rk356x", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent("TaishanPi", isDirectory: true)
            .appendingPathComponent("variants", isDirectory: true)
            .appendingPathComponent("1M-RK3566", isDirectory: true)
    }

    func legacyImagesRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("images", isDirectory: true)
    }

    func boardPluginsRootURL() -> URL {
        boardPluginStateRootURL()
    }

    func boardPluginStateRootURL() -> URL {
        appSupportRootURL()
            .appendingPathComponent("agent", isDirectory: true)
            .appendingPathComponent("catalog", isDirectory: true)
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
        boardPluginInstallRootURLs(for: boardID).first ??
            userBoardPluginsRootURL().appendingPathComponent(pluginBoardID(forLocalBoardID: boardID) ?? boardID, isDirectory: true)
    }

    func boardPluginInstallRootURLs(for boardID: String) -> [URL] {
        let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
        switch pluginID {
        case "TaishanPi":
            return ["1M-RK3566", "1F-RK3566", "3M-RK3576"].map { variantID in
                appSupportRootURL()
                    .appendingPathComponent("families", isDirectory: true)
                    .appendingPathComponent("rk356x", isDirectory: true)
                    .appendingPathComponent("boards", isDirectory: true)
                    .appendingPathComponent("TaishanPi", isDirectory: true)
                    .appendingPathComponent("variants", isDirectory: true)
                    .appendingPathComponent(variantID, isDirectory: true)
                    .appendingPathComponent("plugin", isDirectory: true)
            }
        case "ColorEasyPICO2":
            return [
                appSupportRootURL()
                    .appendingPathComponent("families", isDirectory: true)
                    .appendingPathComponent("rp2350", isDirectory: true)
                    .appendingPathComponent("boards", isDirectory: true)
                    .appendingPathComponent("ColorEasyPICO2", isDirectory: true)
                    .appendingPathComponent("plugin", isDirectory: true)
            ]
        case "RaspberryPiPico2W":
            return [
                appSupportRootURL()
                    .appendingPathComponent("families", isDirectory: true)
                    .appendingPathComponent("rp2350", isDirectory: true)
                    .appendingPathComponent("boards", isDirectory: true)
                    .appendingPathComponent("RaspberryPiPico2W", isDirectory: true)
                    .appendingPathComponent("plugin", isDirectory: true)
            ]
        default:
            return [userBoardPluginsRootURL().appendingPathComponent(pluginID, isDirectory: true)]
        }
    }

    func userBoardPluginsRootURL() -> URL {
        boardPluginsRootURL().appendingPathComponent("installed", isDirectory: true)
    }

    func sharedRuntimeRootURL() -> URL {
        appSupportRootURL().appendingPathComponent("runtime", isDirectory: true)
    }

    func imagesRootURL() -> URL {
        let structured = rk356xTaishanPiVariantRootURL().appendingPathComponent("images", isDirectory: true)
        let legacy = legacyImagesRootURL()
        if FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: structured.path) {
            return legacy
        }
        return structured
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

    func linuxGCCFactoryImageDirURL() -> URL {
        let modeSpecific = imagesRootURL()
            .appendingPathComponent("factory-gcc", isDirectory: true)
            .appendingPathComponent("current", isDirectory: true)
        if directoryHasTaishanPiImageSet(modeSpecific) {
            return modeSpecific
        }
        return factoryImageDirURL()
    }

    func macLLVMFactoryImageDirURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["LLVM_TSPI_FACTORY_IMAGE_DIR"],
            environment["DBT_LOCAL_LLVM_FACTORY_IMAGE_DIR"],
            imagesRootURL().appendingPathComponent("factory-llvm/current", isDirectory: true).path,
        ]
        .compactMap { value -> URL? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        return candidates.first(where: directoryHasTaishanPiImageSet)
            ?? imagesRootURL().appendingPathComponent("factory-llvm/current", isDirectory: true)
    }

    func customImageDirURL() -> URL {
        customImagesRootURL().appendingPathComponent("current", isDirectory: true)
    }

    func linuxGCCCustomImageDirURL() -> URL {
        let modeSpecific = imagesRootURL()
            .appendingPathComponent("custom-gcc", isDirectory: true)
            .appendingPathComponent("current", isDirectory: true)
        if directoryHasTaishanPiImageSet(modeSpecific) {
            return modeSpecific
        }
        return customImageDirURL()
    }

    func macLLVMCustomImageDirURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["DBT_LOCAL_IMAGE_OUTPUT_DIR"],
            environment["DBT_LOCAL_LLVM_CUSTOM_IMAGE_DIR"],
            imagesRootURL().appendingPathComponent("custom-llvm/current", isDirectory: true).path,
        ]
        .compactMap { value -> URL? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        return candidates.first(where: directoryHasTaishanPiImageSet)
            ?? imagesRootURL().appendingPathComponent("custom-llvm/current", isDirectory: true)
    }

    func taishanPiLLVMBootProbeImagesRootURL() -> URL {
        imagesRootURL().appendingPathComponent("custom-clang-bootprobe", isDirectory: true)
    }

    func taishanPiLLVMBootProbeImageDirURL() -> URL {
        taishanPiLLVMBootProbeImagesRootURL().appendingPathComponent("current", isDirectory: true)
    }

    func taishanPiLLVMReleaseRootURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["LLVM_TSPI_RELEASE_ROOT"],
            "/Volumes/LLVM-TSPI/tspi-rk3566-llvm-release-minimal"
        ]
        .compactMap { value -> URL? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        let fm = FileManager.default
        return candidates.first(where: { fm.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    func taishanPiLLVMSDKRootURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["LLVM_TSPI_RELEASE_ROOT"],
            "/Volumes/LLVM-TSPI/tspi-rk3566-llvm-release-minimal",
            environment["LLVM_TSPI_SDK_ROOT"],
            "/Volumes/LLVM-TSPI/sdk-tools",
            "/Users/kvell/kk-project/DBT-Agent-Project/llvm-build-tspi"
        ]
        .compactMap { value -> URL? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: value, isDirectory: true)
        }

        let fm = FileManager.default
        return candidates.first(where: { fm.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    func setTaishanPiDevelopmentMode(_ mode: TaishanPiDevelopmentMode) {
        let modes = availableTaishanPiDevelopmentModes
        if modes.count == 1, let onlyMode = modes.first, onlyMode != mode {
            taishanPiDevelopmentMode = onlyMode
            hasUserSelectedTaishanPiDevelopmentMode = false
            UserDefaults.standard.set(onlyMode.rawValue, forKey: taishanPiDevelopmentModeDefaultsKey)
            refreshActionAvailability()
            return
        }
        taishanPiDevelopmentMode = mode
        hasUserSelectedTaishanPiDevelopmentMode = true
        UserDefaults.standard.set(mode.rawValue, forKey: taishanPiDevelopmentModeDefaultsKey)
        if !localArtifactsDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validateLocalArtifactsDirectory()
        }
        refreshActionAvailability()
        Task {
            await refreshDevelopmentInstallStatus()
        }
    }

    func taishanPiBuildModeArguments() -> [String] {
        ["--build-mode", taishanPiDevelopmentMode.buildModeArgument]
    }

    var availableTaishanPiDevelopmentModes: [TaishanPiDevelopmentMode] {
        let readyModes = readyTaishanPiDevelopmentModes(using: developmentInstallStatus)
        if !readyModes.isEmpty {
            return readyModes
        }

        let partialModes = partialTaishanPiDevelopmentModes(using: developmentInstallStatus)
        if !partialModes.isEmpty {
            return partialModes
        }

        return TaishanPiDevelopmentMode.allCases
    }

    var canChooseTaishanPiDevelopmentMode: Bool {
        availableTaishanPiDevelopmentModes.count > 1
    }

    var taishanPiDevelopmentModeFixedSummary: String {
        if availableTaishanPiDevelopmentModes.count == 1 {
            return "\(taishanPiDevelopmentMode.title) 已按本机已安装环境自动选择"
        }
        return "等待开发环境检查"
    }

    private func readyTaishanPiDevelopmentModes(using status: DevelopmentInstallStatus) -> [TaishanPiDevelopmentMode] {
        var modes: [TaishanPiDevelopmentMode] = []
        if status.dockerEnvironmentReady {
            modes.append(.dockerLinux)
        }
        if status.llvmEnvironmentReady {
            modes.append(.macLLVM)
        }
        return modes
    }

    private func partialTaishanPiDevelopmentModes(using status: DevelopmentInstallStatus) -> [TaishanPiDevelopmentMode] {
        var modes: [TaishanPiDevelopmentMode] = []
        if status.dockerEnvironmentPartial {
            modes.append(.dockerLinux)
        }
        if status.llvmEnvironmentPartial {
            modes.append(.macLLVM)
        }
        return modes
    }

    private func autoSelectTaishanPiDevelopmentMode(using status: DevelopmentInstallStatus) {
        let readyModes = readyTaishanPiDevelopmentModes(using: status)
        if readyModes.count == 1, let mode = readyModes.first {
            taishanPiDevelopmentMode = mode
            hasUserSelectedTaishanPiDevelopmentMode = false
            UserDefaults.standard.set(mode.rawValue, forKey: taishanPiDevelopmentModeDefaultsKey)
            return
        }

        let partialModes = partialTaishanPiDevelopmentModes(using: status)
        if readyModes.isEmpty, partialModes.count == 1, let mode = partialModes.first {
            taishanPiDevelopmentMode = mode
            hasUserSelectedTaishanPiDevelopmentMode = false
            UserDefaults.standard.set(mode.rawValue, forKey: taishanPiDevelopmentModeDefaultsKey)
            return
        }

        guard !hasUserSelectedTaishanPiDevelopmentMode else {
            return
        }
        if status.llvmEnvironmentReady && !status.dockerEnvironmentReady {
            taishanPiDevelopmentMode = .macLLVM
            return
        }
        if status.dockerEnvironmentReady && !status.llvmEnvironmentReady {
            taishanPiDevelopmentMode = .dockerLinux
            return
        }
        if status.llvmEnvironmentPartial && !status.dockerEnvironmentPartial {
            taishanPiDevelopmentMode = .macLLVM
        }
    }

    private func volumeSupportsCaseSensitiveNames(at url: URL) -> Bool {
        let target = FileManager.default.fileExists(atPath: url.path) ? url : url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: target.path) else {
            return false
        }
        let values = try? target.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
        return values?.volumeSupportsCaseSensitiveNames == true
    }

    private func directoryHasTaishanPiImageSet(_ directory: URL) -> Bool {
        let fm = FileManager.default
        let required = [
            "MiniLoaderAll.bin",
            "parameter.txt",
            "boot.img",
            "uboot.img",
            "userdata.img",
        ]
        let rootfsCandidates = ["rootfs.img", "rootfs.ext4"]
        return required.allSatisfy { fm.fileExists(atPath: directory.appendingPathComponent($0).path) } &&
            rootfsCandidates.contains { fm.fileExists(atPath: directory.appendingPathComponent($0).path) }
    }

    private func executableAvailable(
        candidatePaths: [String],
        fallbackCommand: String? = nil
    ) async -> Bool {
        if candidatePaths.contains(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return true
        }
        guard let fallbackCommand, !fallbackCommand.isEmpty else {
            return false
        }
        return await commandExists(fallbackCommand)
    }

    func bundledBoardPluginsRootURL() -> URL {
        let fileManager = FileManager.default
        let candidates = [
            sharedRuntimeRootURL().appendingPathComponent("builtin-plugin-seed", isDirectory: true),
            sharedRuntimeRootURL()
                .appendingPathComponent("board_plugins", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true),
        ]
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
            ?? URL(fileURLWithPath: "/nonexistent", isDirectory: true)
    }

    func ensureSeededBoardPlugins() {
        let fm = FileManager.default
        let sourceRoot = bundledBoardPluginsRootURL()
        let userRoot = userBoardPluginsRootURL()
        try? fm.createDirectory(at: userRoot, withIntermediateDirectories: true)

        let legacyBuiltinRoot = appSupportRootURL()
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("builtin", isDirectory: true)
        if fm.fileExists(atPath: legacyBuiltinRoot.path) {
            let legacyEntries = (try? fm.contentsOfDirectory(at: legacyBuiltinRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for entry in legacyEntries {
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                for target in boardPluginInstallRootURLs(for: entry.lastPathComponent) where !fm.fileExists(atPath: target.path) {
                    try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.copyItem(at: entry, to: target)
                }
                try? fm.removeItem(at: entry)
            }
            let remainingLegacyEntries = (try? fm.contentsOfDirectory(at: legacyBuiltinRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            if remainingLegacyEntries.isEmpty {
                try? fm.removeItem(at: legacyBuiltinRoot)
            }
        }

        guard fm.fileExists(atPath: sourceRoot.path) else { return }
        let registryHasInstalledEntries: Bool
        if let data = try? Data(contentsOf: boardPluginRegistryURL()),
           let registry = try? JSONDecoder().decode(InstalledBoardPluginsRegistry.self, from: data) {
            registryHasInstalledEntries = !registry.installed.isEmpty
        } else {
            registryHasInstalledEntries = false
        }
        let existingUserPlugins = discoveredInstalledUserPluginVersions()
        guard !registryHasInstalledEntries && existingUserPlugins.isEmpty else {
            return
        }
        let entries = (try? fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let variantRoot = entry.appendingPathComponent("variants", isDirectory: true)
            if entry.lastPathComponent == "TaishanPi", fm.fileExists(atPath: variantRoot.path) {
                for variantID in ["1M-RK3566", "1F-RK3566", "3M-RK3576"] {
                    let sourceVariant = variantRoot
                        .appendingPathComponent(variantID, isDirectory: true)
                        .appendingPathComponent("plugin", isDirectory: true)
                    guard fm.fileExists(atPath: sourceVariant.path) else { continue }
                    let target = appSupportRootURL()
                        .appendingPathComponent("families", isDirectory: true)
                        .appendingPathComponent("rk356x", isDirectory: true)
                        .appendingPathComponent("boards", isDirectory: true)
                        .appendingPathComponent("TaishanPi", isDirectory: true)
                        .appendingPathComponent("variants", isDirectory: true)
                        .appendingPathComponent(variantID, isDirectory: true)
                        .appendingPathComponent("plugin", isDirectory: true)
                    guard !fm.fileExists(atPath: target.path) else { continue }
                    try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.copyItem(at: sourceVariant, to: target)
                }
                continue
            }
            for target in boardPluginInstallRootURLs(for: entry.lastPathComponent) where !fm.fileExists(atPath: target.path) {
                try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.copyItem(at: entry, to: target)
            }
        }
    }

    func discoveredInstalledUserPluginVersions() -> [String: String] {
        let fm = FileManager.default
        var entries: [URL] = []
        for board in SupportedBoard.catalog {
            entries.append(contentsOf: boardPluginInstallRootURLs(for: board.id))
        }
        let root = userBoardPluginsRootURL()
        if fm.fileExists(atPath: root.path) {
            entries.append(contentsOf: (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
        }
        var discovered: [String: String] = [:]
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true, entry.lastPathComponent != "downloads" else { continue }
            guard let manifestURL = try? findBoardPluginFile(named: "manifest.json", under: entry),
                  let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(BoardPluginManifest.self, from: data) else {
                continue
            }
            let localID = localBoardID(forPluginBoardID: manifest.id) ?? localBoardID(forPluginBoardID: entry.lastPathComponent) ?? entry.lastPathComponent
            discovered[localID] = manifest.version
        }
        return discovered
    }

    func boardPluginInstalledVersion(_ boardID: String) -> String? {
        let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
        return installedBoardPluginMetadata[boardID]?.version ??
            installedBoardPlugins[boardID] ??
            installedBoardPluginMetadata[pluginID]?.version ??
            installedBoardPlugins[pluginID]
    }

    func boardPluginCatalogVersion(_ boardID: String) -> String? {
        let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
        return boardPluginCatalogVersions[boardID] ?? boardPluginCatalogVersions[pluginID]
    }

    func boardPluginDisplayVersion(_ boardID: String) -> String {
        boardPluginCatalogVersion(boardID) ?? boardPluginInstalledVersion(boardID) ?? "-"
    }

    func isBoardPluginInstalled(_ boardID: String) -> Bool {
        boardPluginInstalledVersion(boardID) != nil
    }

    func isBoardIntegrationBundled(_ boardID: String) -> Bool {
        supportedBoard(for: boardID)?.integrationReady == true
    }

    func boardPluginLocalStatusText(_ boardID: String) -> String {
        if let version = boardPluginInstalledVersion(boardID), !version.isEmpty {
            return "本地 \(version)"
        }
        return isBoardIntegrationBundled(boardID) ? "应用内置" : "未安装"
    }

    func remoteBoardPluginEntry(_ boardID: String) -> RemoteBoardPluginEntry? {
        let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
        return remoteBoardPluginEntries[boardID] ?? remoteBoardPluginEntries[pluginID]
    }

    func installedBoardToolingMetadata(_ boardID: String) -> InstalledBoardPluginMetadata? {
        let pluginID = pluginBoardID(forLocalBoardID: boardID) ?? boardID
        return installedBoardPluginMetadata[boardID] ?? installedBoardPluginMetadata[pluginID]
    }

    func canRemoveBoardPlugin(_ boardID: String) -> Bool {
        return installedBoardToolingMetadata(boardID) != nil
    }

    func activeVariantID(for boardID: String) -> String? {
        if let preferredControlDeviceID,
           let candidate = activeControlDeviceCandidates.first(where: { $0.deviceID == preferredControlDeviceID }) ??
            detectedBoardCandidates.first(where: { $0.deviceID == preferredControlDeviceID }),
           candidate.boardID == boardID {
            return candidate.variantID
        }
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
        if let reason = activeFlashTaskDisabledReason() {
            return ActionAvailabilityState(enabled: false, reason: reason)
        }
        let base = actionAvailabilityState(for: .flash(target))
        guard base.enabled else {
            return base
        }
        if let localError = localFlashPrerequisiteError(target, source: source) {
            return ActionAvailabilityState(enabled: false, reason: localError)
        }
        return base
    }

    func rawImageFlashAvailabilityState() -> ActionAvailabilityState {
        if let reason = activeFlashTaskDisabledReason() {
            return ActionAvailabilityState(enabled: false, reason: reason)
        }
        let base = actionAvailabilityState(for: .flash("all"))
        guard base.enabled else {
            return base
        }
        if let error = rawImageFlashPrerequisiteError() {
            return ActionAvailabilityState(enabled: false, reason: error)
        }
        return base
    }

    private func currentOperationRoute() -> (boardID: String?, variantID: String?, deviceID: String?) {
        let selectedCandidate = currentControlCandidate
        let boardID = preferredControlBoardID ?? connectedBoardID ?? selectedCandidate?.boardID
        let variantID = boardID.flatMap { activeVariantID(for: $0) } ?? boardID
        let deviceID = selectedCandidate?.deviceID ?? preferredControlDeviceID ?? status?.active_device_id ?? status?.device_id
        return (boardID, variantID, deviceID)
    }

    private func activeFlashTaskDisabledReason() -> String? {
        if let activeBackgroundFlashTaskID, !activeBackgroundFlashTaskID.isEmpty {
            let title = activeBackgroundFlashTitle.isEmpty ? "刷写任务" : activeBackgroundFlashTitle
            return "\(title)仍在后台执行，请等待完成或超时清理后再提交新的刷写任务。"
        }
        if isFlashTaskRunning {
            let title: String
            if !pendingTaskTitle.isEmpty {
                title = pendingTaskTitle
            } else if let currentTask {
                title = taskActionDisplayName(currentTask)
            } else {
                title = "刷写任务"
            }
            return "\(title)正在执行，请等待当前刷写任务结束。"
        }
        return nil
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

    private func rawImageFlashPrerequisiteError() -> String? {
        let path = taishanPiRawImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return "未选择 .img 镜像文件。"
        }
        guard path.lowercased().hasSuffix(".img") else {
            return "请选择 .img 文件。"
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return "IMG 镜像文件不存在：\(path)"
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? NSNumber,
           size.int64Value <= 0 {
            return "IMG 镜像文件为空：\(path)"
        }
        return nil
    }

    private func localAgentOperationPreflightMessage(operationID: String, boardID: String?, variantID: String?) async -> String? {
        do {
            let response = try await postLocalAgentActionPrecheck(operationID: operationID, boardID: boardID, variantID: variantID)
            if let summary = response.status_summary {
                applyLocalAgentStatusSummary(summary, silent: true)
            }
            return response.ready == true ? nil : (response.message ?? "本地 DBT Agent 动作预检未通过")
        } catch {
            return error.localizedDescription
        }
    }

    private var controlPageTargetBoardID: String? {
        preferredControlBoardID ?? connectedBoardID
    }

    private func controlPageBoardFamily() -> BoardLogicFamily {
        let resolvedBoardID = controlPageTargetBoardID
            ?? currentControlCandidate?.boardID
            ?? liveDetectedBoard?.id
            ?? status?.device?.board_id
        return boardLogicFamily(boardID: resolvedBoardID, status: status)
    }

    private func controlPageHasMatchingLiveSignal() -> Bool {
        if let targetBoardID = controlPageTargetBoardID {
            if let candidate = currentControlCandidate,
               boardMatches(candidate.boardID, targetBoardID: targetBoardID) {
                return true
            }
            if let candidate = currentLiveCandidate,
               boardMatches(candidate.boardID, targetBoardID: targetBoardID) {
                return true
            }
            if let boardID = liveDetectedBoard?.id,
               boardMatches(boardID, targetBoardID: targetBoardID) {
                return true
            }
            if let boardID = status?.device?.board_id,
               boardMatches(boardID, targetBoardID: targetBoardID) {
                return true
            }
        } else if currentLiveCandidate != nil || liveDetectedBoard != nil {
            return true
        }

        let usbMode = (status?.usb?.mode ?? "").lowercased()
        let rpState = (status?.rp2350?.state ?? status?.usb?.mode ?? "").lowercased()
        switch controlPageBoardFamily() {
        case .taishanPi:
            return usbMode == "loader" ||
                usbMode == "maskrom" ||
                usbMode == "usb-ecm" ||
                usbMode == "rockchip-other" ||
                status?.usbnet?.configured == true ||
                status?.board?.ping == true ||
                status?.board?.ssh_port_open == true ||
                status?.board?.control_service == true
        case .colorEasyPICO2:
            return status?.rp2350?.connected == true ||
                rpState == "bootsel" ||
                rpState == "rp2350-bootsel" ||
                rpState == "runtime-resettable" ||
                rpState == "rp2350-runtime" ||
                isRP2350SingleUSBMode(rpState)
        case .generic:
            return currentLiveCandidate != nil || liveDetectedBoard != nil || hasRockchipSignalFromStatus()
        }
    }

    private func disconnectedFlashTransportReason() -> String {
        switch controlPageBoardFamily() {
        case .taishanPi:
            return "当前未检测到可用于刷写的 TaishanPi 连接。请确认开发板已进入 Loader、Maskrom 或 USB ECM 状态。"
        case .colorEasyPICO2:
            return "当前未检测到可用于刷写的 RP2350 设备连接。请确认开发板已进入 RP2350 单 USB 或 BOOTSEL 状态。"
        case .generic:
            return "当前未检测到可用于刷写的开发板连接。请确认开发板已进入可刷写状态。"
        }
    }

    private func disconnectedFlashTransportSummary() -> String {
        switch controlPageBoardFamily() {
        case .taishanPi:
            return "请先连接 TaishanPi，或让开发板进入 Loader / Maskrom / USB ECM 后再执行镜像刷写。"
        case .colorEasyPICO2:
            return "请先连接 RP2350 设备，或让开发板进入 RP2350 单 USB / BOOTSEL 后再执行刷写。"
        case .generic:
            return "请先让设备进入可刷写状态后再执行镜像刷写。"
        }
    }

    private func liveBoardConnectionReady() -> Bool {
        controlPageHasMatchingLiveSignal()
    }

    private func liveUSBControlReady() -> Bool {
        guard liveBoardConnectionReady() else { return false }
        return status?.board?.control_service == true
    }

    private func liveUSBOrSSHReady() -> Bool {
        guard liveBoardConnectionReady() else { return false }
        return status?.board?.control_service == true || status?.board?.ssh_port_open == true
    }

    private func deviceRebootAvailabilityState() -> ActionAvailabilityState {
        guard liveBoardConnectionReady() else {
            return ActionAvailabilityState(
                enabled: false,
                reason: "当前未检测到可用的设备重启链路。请确认开发板已连接。"
            )
        }
        let usbMode = (status?.usb?.mode ?? "").lowercased()
        if boardLogicFamily(status: status) == .taishanPi,
           usbMode == "loader" || usbMode == "maskrom" {
            return .enabledState
        }
        if liveUSBOrSSHReady() {
            return .enabledState
        }
        return ActionAvailabilityState(
            enabled: false,
            reason: "当前未检测到可用的设备重启链路。请确认 SSH / 控制服务已恢复，或让开发板处于 Loader / Maskrom 恢复模式。"
        )
    }

    private func flashTransportAvailabilityState() -> ActionAvailabilityState {
        guard liveBoardConnectionReady() else {
            return ActionAvailabilityState(
                enabled: false,
                reason: disconnectedFlashTransportReason()
            )
        }

        let usbMode = (status?.usb?.mode ?? "").lowercased()
        if isRP2350SingleUSBMode(usbMode) {
            return .enabledState
        }

        if controlPageBoardFamily() == .taishanPi {
            switch usbMode {
            case "loader", "maskrom", "rockchip-other":
                return .enabledState
            case "usb-ecm":
                if status?.usbnet?.configured != true {
                    return ActionAvailabilityState(
                        enabled: false,
                        reason: "当前开发板仍处于 USB ECM 运行态，但主机 USB 网络尚未恢复完成。请先恢复 USB 网络后再刷写。"
                    )
                }
                if status?.board?.control_service == true || status?.board?.ssh_port_open == true {
                    return .enabledState
                }
                return ActionAvailabilityState(
                    enabled: false,
                    reason: "当前开发板仍处于 USB ECM 运行态，但控制服务和 SSH 均不可用。现有刷写链路无法自动切换到 Loader，直接刷写会超时。请先恢复控制服务/SSH，或手动让开发板进入 Loader 模式后再刷写。"
                )
            default:
                return ActionAvailabilityState(
                    enabled: false,
                    reason: disconnectedFlashTransportReason()
                )
            }
        }

        if usbMode == "loader" || usbMode == "usb-ecm" || usbMode == "rockchip-other" {
            return .enabledState
        }

        return ActionAvailabilityState(
            enabled: false,
            reason: disconnectedFlashTransportReason()
        )
    }

    private func liveFlashTransportReady() -> Bool {
        flashTransportAvailabilityState().enabled
    }

    func flashTransportSummaryText() -> String {
        guard liveBoardConnectionReady() else {
            return disconnectedFlashTransportSummary()
        }
        let usbMode = (status?.usb?.mode ?? "").lowercased()
        if isRP2350SingleUSBMode(usbMode) {
            return "当前设备已处于 RP2350 单 USB 刷写链路，可直接执行刷写。"
        }
        if controlPageBoardFamily() == .taishanPi {
            switch usbMode {
            case "loader":
                return "当前开发板已处于 Loader 模式，将直接执行刷写。"
            case "maskrom":
                return "当前开发板已处于 Maskrom 模式，刷写前会先通过 MiniLoaderAll.bin 拉起 Loader，再继续执行刷写。"
            case "rockchip-other":
                return "当前已检测到 Rockchip USB 刷写链路，可直接执行刷写。"
            case "usb-ecm":
                if status?.board?.control_service == true {
                    return "当前开发板处于 USB ECM 运行态，刷写前会先通过控制服务切换到 Loader。"
                }
                if status?.board?.ssh_port_open == true {
                    return "当前开发板处于 USB ECM 运行态，控制服务未响应，但 SSH 可用；刷写前会通过 SSH fallback 请求进入 Loader。"
                }
                return "当前开发板处于 USB ECM 运行态，但控制服务和 SSH 均不可用。请先恢复控制链路，或手动进入 Loader 后再刷写。"
            default:
                return "请先让开发板进入可刷写状态后再执行镜像刷写。"
            }
        }
        if usbMode == "loader" {
            return "当前设备已处于 Loader 模式，可直接执行刷写。"
        }
        if usbMode == "usb-ecm" {
            return "当前设备已通过 USB ECM 连接，可执行刷写。"
        }
        return "请先让设备进入可刷写状态后再执行镜像刷写。"
    }

    func flashTransportIndicatorColor() -> Color {
        let usbMode = (status?.usb?.mode ?? "").lowercased()
        if usbMode == "loader" || usbMode == "maskrom" {
            return .blue
        }
        return flashTransportAvailabilityState().enabled ? .green : .orange
    }

    func refreshActionAvailability() {
        actionAvailabilityTask?.cancel()
        actionAvailabilityTask = nil

        let usbMode = (status?.usb?.mode ?? "").lowercased()
        let usbControlReady = liveUSBControlReady()
        let rebootDeviceTransport = deviceRebootAvailabilityState()
        let flashTransport = flashTransportAvailabilityState()
        let flashTransportReady = flashTransport.enabled

        var next: [ActionPrecondition: ActionAvailabilityState] = [:]
        next[.checkHost] = .enabledState
        next[.ensureUSBNet] = usbMode == "usb-ecm"
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到 USB ECM 连接，无法恢复主机静态地址。")
        next[.authorizeKey] = usbControlReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用的 USB 控制服务。请确认开发板已联机并完成 USB ECM 初始化。")
        let loaderSwitchReady = liveUSBOrSSHReady()
        next[.rebootLoader] = loaderSwitchReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: "当前未检测到可用的控制服务或 SSH。请确认开发板已联机并完成 USB ECM 初始化。")
        next[.rebootDevice] = rebootDeviceTransport

        for target in ["all", "boot", "rootfs", "userdata"] {
            next[.flash(target)] = flashTransportReady ? .enabledState : flashTransport
        }

        let selectedCompileReady = taishanPiDevelopmentMode == .macLLVM
            ? developmentInstallStatus.llvmEnvironmentReady
            : developmentInstallStatus.dockerEnvironmentReady
        let compileNotReadyMessage = taishanPiDevelopmentMode == .macLLVM
            ? "Mac LLVM 环境未就绪，无法执行构建同步。"
            : "Linux GCC / Docker 环境未就绪，无法执行构建同步。"
        next[.buildSync] = selectedCompileReady
            ? .enabledState
            : ActionAvailabilityState(enabled: false, reason: compileNotReadyMessage)

        if !selectedCompileReady {
            next[.buildSyncFlash] = ActionAvailabilityState(enabled: false, reason: compileNotReadyMessage)
        } else if !flashTransportReady {
            next[.buildSyncFlash] = flashTransport
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
    var officialVolumeName: String { "tspi-rk356x-official-workspace" }

    func runSystemShell(_ script: String) async throws -> (Int32, String) {
        try await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-lc", script],
            currentDirectoryURL: appSupportRootURL(),
            environment: ProcessInfo.processInfo.environment
        )
    }

    private func shellQuotedArgument(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func privilegedCommandFailureMessage(from output: String) -> String {
        let marker = "__DBT_PRIVILEGED_ERROR__"
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(marker) else {
            return trimmed.isEmpty ? "管理员授权执行失败。" : trimmed
        }
        let payload = String(trimmed.dropFirst(marker.count))
        guard let separator = payload.firstIndex(of: ":") else {
            return payload.isEmpty ? "管理员授权执行失败。" : payload
        }
        let code = String(payload[..<separator])
        let message = String(payload[payload.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if code == "-128" || message.localizedCaseInsensitiveContains("user canceled") || message.contains("取消") {
            return "已取消管理员授权。"
        }
        if message.isEmpty {
            return "管理员授权执行失败（\(code)）。"
        }
        return message
    }

    private func runPrivilegedRuntimeCommand(arguments: [String]) async throws -> String {
        let runtimeCLI = sharedRuntimeRootURL().appendingPathComponent(runtimeBinaryName)
        guard FileManager.default.isExecutableFile(atPath: runtimeCLI.path) else {
            throw ToolkitGUIError.commandFailed("未找到可执行的 runtime 命令：\(runtimeCLI.path)")
        }
        let command = ([runtimeCLI.path] + arguments).map(shellQuotedArgument).joined(separator: " ")
        let script = """
        try
            return do shell script \(appleScriptStringLiteral(command)) with administrator privileges
        on error errMsg number errNum
            return "__DBT_PRIVILEGED_ERROR__" & errNum & ":" & errMsg
        end try
        """
        let (_, output) = try await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script],
            currentDirectoryURL: appSupportRootURL(),
            environment: ProcessInfo.processInfo.environment
        )
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("__DBT_PRIVILEGED_ERROR__") {
            throw ToolkitGUIError.commandFailed(privilegedCommandFailureMessage(from: trimmed))
        }
        return trimmed
    }

    func extractJSONObject(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    func commandExists(_ command: String) async -> Bool {
        guard let result = try? await runSystemShell("command -v \(command) >/dev/null 2>&1") else {
            return false
        }
        return result.0 == 0
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

    func localAgentControlBinaryURL() -> URL {
        localAgentRootURL().appendingPathComponent("bin/dbt-agentctl")
    }

    func localAgentConfigURL() -> URL {
        localAgentRootURL().appendingPathComponent("config/dbt-agentd.local.json")
    }

    func localAgentRunRootURL() -> URL {
        localAgentRootURL().appendingPathComponent("run", isDirectory: true)
    }

    func localAgentPIDFileURL() -> URL {
        localAgentRunRootURL().appendingPathComponent("dbt-agentd.pid")
    }

    func setLocalAgentUnavailableReason(_ reason: String?) {
        let normalized = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        localAgentUnavailableReason = (normalized?.isEmpty == false) ? normalized : nil
    }

    func localAgentMissingInstallMessage(controlURL: URL, binaryURL: URL, configURL: URL) -> String {
        let runtimeCommand = sharedRuntimeRootURL().appendingPathComponent(runtimeBinaryName)
        if FileManager.default.fileExists(atPath: runtimeCommand.path) {
            return "未检测到本地 DBT Agent 安装。当前 GUI 需要共享 runtime 和本地 agent 同时存在。请重新运行完整安装器，或检查 \(controlURL.path)、\(binaryURL.path) 与 \(configURL.path)。"
        }
        return "未检测到本地 DBT Agent 安装。请先完成 runtime 和 agent 安装，再重试。期望路径：\(controlURL.path)、\(binaryURL.path) 与 \(configURL.path)。"
    }

    func localAgentUnavailableUserMessage() -> String {
        localAgentUnavailableReason ?? "本地 DBT Agent 暂不可用。请确认本地 agent 已安装并已启动。"
    }

    func setLocalAgentRunning(_ value: Bool) {
        if localAgentRunning != value {
            localAgentRunning = value
        }
    }

    func readLocalAgentPID() -> Int32? {
        let pidURL = localAgentPIDFileURL()
        guard let text = try? String(contentsOf: pidURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(text),
              pid > 0
        else {
            return nil
        }
        return pid
    }

    func writeLocalAgentPID(_ pid: Int32?) {
        let pidURL = localAgentPIDFileURL()
        if let pid {
            try? FileManager.default.createDirectory(at: localAgentRunRootURL(), withIntermediateDirectories: true)
            try? "\(pid)\n".write(to: pidURL, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: pidURL)
        }
    }

    func localAgentProcessArguments(pid: Int32) async -> String? {
        let script = "/bin/ps -p \(pid) -o args= 2>/dev/null"
        guard let result = try? await runLocalAgentShell(script), result.0 == 0 else {
            return nil
        }
        let args = result.1.trimmingCharacters(in: .whitespacesAndNewlines)
        return args.isEmpty ? nil : args
    }

    func isLocalAgentProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else {
            return false
        }
        return kill(pid, 0) == 0
    }

    private func childProcessIDs(of pid: Int32) -> [Int32] {
        guard pid > 0 else {
            return []
        }
        guard let result = try? ProcessExecutor.runSync(
            executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-P", String(pid)],
            currentDirectoryURL: URL(fileURLWithPath: "/"),
            environment: ProcessInfo.processInfo.environment
        ), result.0 == 0 else {
            return []
        }
        return result.1
            .split(whereSeparator: \.isWhitespace)
            .compactMap { Int32($0) }
            .filter { $0 > 0 }
    }

    private func descendantProcessIDs(of pid: Int32) -> [Int32] {
        var descendants: [Int32] = []
        var seen = Set<Int32>([pid])
        var stack = [pid]
        while let current = stack.popLast() {
            for child in childProcessIDs(of: current) where !seen.contains(child) {
                seen.insert(child)
                descendants.append(child)
                stack.append(child)
            }
        }
        return descendants
    }

    func terminateLocalAgentProcess(_ pid: Int32) {
        let descendants = descendantProcessIDs(of: pid)
        let processTree = Array(descendants.reversed()) + [pid]
        guard processTree.contains(where: { isLocalAgentProcessAlive($0) }) else {
            return
        }
        for processID in processTree where isLocalAgentProcessAlive(processID) {
            _ = kill(processID, SIGTERM)
        }
        for _ in 0..<15 {
            if !processTree.contains(where: { isLocalAgentProcessAlive($0) }) {
                return
            }
            usleep(100_000)
        }
        for processID in processTree where isLocalAgentProcessAlive(processID) {
            _ = kill(processID, SIGKILL)
        }
    }

    func isGUIManagedLocalAgentServiceProcess(pid: Int32) async -> Bool {
        guard let args = await localAgentProcessArguments(pid: pid) else {
            return false
        }
        let binaryPath = localAgentBinaryURL().path
        let configPath = localAgentConfigURL().path
        return args.contains(binaryPath) &&
            args.contains("--config \(configPath)") &&
            !args.contains("--mcp-serve")
    }

    func runLocalAgentShell(_ script: String) async throws -> (Int32, String) {
        try await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-lc", script],
            currentDirectoryURL: localAgentRootURL(),
            environment: ProcessInfo.processInfo.environment
        )
    }

    func localAgentListenerPID() async -> Int32? {
        let script = "/usr/sbin/lsof -nP -iTCP:\(localAgentPort) -sTCP:LISTEN -t 2>/dev/null | /usr/bin/head -n 1"
        guard let result = try? await runLocalAgentShell(script), result.0 == 0 else {
            return nil
        }
        let text = result.1.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(text), pid > 0 else {
            return nil
        }
        return pid
    }

    func cleanupStaleLocalAgentProcessesIfNeeded(force: Bool = false) async {
        if didCleanupLocalAgentProcesses && !force {
            return
        }
        let listenerPID = await localAgentListenerPID()
        let trackedPID = readLocalAgentPID()

        if let trackedPID {
            if !isLocalAgentProcessAlive(trackedPID) {
                if ownedLocalAgentPID == trackedPID {
                    ownedLocalAgentPID = nil
                }
                writeLocalAgentPID(listenerPID)
                didCleanupLocalAgentProcesses = true
                return
            }

            let trackedIsManagedService = await isGUIManagedLocalAgentServiceProcess(pid: trackedPID)
            if listenerPID != trackedPID, trackedIsManagedService {
                terminateLocalAgentProcess(trackedPID)
                if ownedLocalAgentPID == trackedPID {
                    ownedLocalAgentPID = nil
                }
            }
        }

        writeLocalAgentPID(listenerPID)
        didCleanupLocalAgentProcesses = true
    }

    func waitForLocalAgentHealthz(timeoutSeconds: TimeInterval = 6.0) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if (try? await fetchLocalAgentHealthz()) != nil {
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    func fetchLocalAgentHealthz() async throws {
        var request = URLRequest(url: localAgentURL(path: "healthz"))
        request.timeoutInterval = 2
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 不可用")
        }
        setLocalAgentUnavailableReason(nil)
        setLocalAgentRunning(true)
    }

    func ensureLocalAgentStartedIfNeeded() async {
        if localAgentStartInProgress {
            return
        }
        await cleanupStaleLocalAgentProcessesIfNeeded()
        if (try? await fetchLocalAgentHealthz()) != nil {
            didBootstrapLocalAgent = true
            setLocalAgentRunning(true)
            return
        }
        if let lastLocalAgentStartAttemptAt,
           Date().timeIntervalSince(lastLocalAgentStartAttemptAt) < 4
        {
            return
        }
        let controlURL = localAgentControlBinaryURL()
        let binaryURL = localAgentBinaryURL()
        let configURL = localAgentConfigURL()
        guard FileManager.default.fileExists(atPath: controlURL.path),
              FileManager.default.fileExists(atPath: binaryURL.path),
              FileManager.default.fileExists(atPath: configURL.path) else {
            setLocalAgentUnavailableReason(localAgentMissingInstallMessage(controlURL: controlURL, binaryURL: binaryURL, configURL: configURL))
            setLocalAgentRunning(false)
            return
        }
        localAgentStartInProgress = true
        defer { localAgentStartInProgress = false }
        lastLocalAgentStartAttemptAt = Date()
        do {
            await cleanupStaleLocalAgentProcessesIfNeeded(force: true)
            try FileManager.default.createDirectory(at: localAgentRunRootURL(), withIntermediateDirectories: true)
            let preStartPID = await localAgentListenerPID()
            let (code, output) = try await ProcessExecutor.run(
                executableURL: controlURL,
                arguments: ["service", "start", "--installed-root", localAgentRootURL().path, "--base-url", localAgentBaseURL.absoluteString],
                currentDirectoryURL: localAgentRootURL(),
                environment: ProcessInfo.processInfo.environment
            )
            guard code == 0 else {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ToolkitGUIError.commandFailed(trimmed.isEmpty ? "本地 DBT Agent 启动失败" : trimmed)
            }
            guard await waitForLocalAgentHealthz() else {
                if let listenerPID = await localAgentListenerPID(), preStartPID == nil {
                    terminateLocalAgentProcess(listenerPID)
                }
                writeLocalAgentPID(nil)
                throw ToolkitGUIError.commandFailed("本地 DBT Agent 启动超时")
            }
            let listenerPID = await localAgentListenerPID()
            if preStartPID == nil {
                ownedLocalAgentPID = listenerPID
            }
            writeLocalAgentPID(listenerPID)
            didBootstrapLocalAgent = true
            setLocalAgentUnavailableReason(nil)
            setLocalAgentRunning(true)
            await cleanupStaleLocalAgentProcessesIfNeeded(force: true)
            appendActivity(level: .success, title: "本地 DBT Agent", message: "已启动")
        } catch {
            ownedLocalAgentPID = nil
            let logURL = localAgentRunRootURL().appendingPathComponent("dbt-agentd.log")
            setLocalAgentUnavailableReason("本地 DBT Agent 启动失败。请检查 \(logURL.path)。错误：\(error.localizedDescription)")
            setLocalAgentRunning(false)
            appendActivity(level: .warning, title: "本地 DBT Agent", message: "启动失败", detail: error.localizedDescription)
        }
    }

    func stopOwnedLocalAgentIfNeeded() {
        guard let pid = ownedLocalAgentPID else {
            return
        }
        if readLocalAgentPID() == pid {
            writeLocalAgentPID(nil)
        }
        terminateLocalAgentProcess(pid)
        ownedLocalAgentPID = nil
    }

    func fetchLocalAgentStatusSummary() async throws -> AgentStatusSummaryResponse {
        var request = URLRequest(url: localAgentURL(path: "v1/status/summary"))
        request.timeoutInterval = 3
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 状态请求失败")
        }
        setLocalAgentRunning(true)
        return try JSONDecoder().decode(AgentStatusSummaryResponse.self, from: data)
    }

    func postLocalAgentActionPrecheck(
        operationID: String,
        boardID: String?,
        variantID: String?,
        deviceID: String? = nil
    ) async throws -> AgentActionPreflightResponse {
        let resolvedDeviceID = deviceID ?? currentOperationRoute().deviceID
        var payload: [String: Any] = ["operation_id": operationID]
        if let boardID, !boardID.isEmpty {
            payload["board_id"] = boardID
        }
        if let variantID, !variantID.isEmpty {
            payload["variant_id"] = variantID
        }
        if let resolvedDeviceID, !resolvedDeviceID.isEmpty {
            payload["device_id"] = resolvedDeviceID
        }

        var request = URLRequest(url: localAgentURL(path: "v1/actions/precheck"))
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 动作预检失败")
        }
        setLocalAgentRunning(true)
        return try JSONDecoder().decode(AgentActionPreflightResponse.self, from: data)
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
        setLocalAgentRunning(true)
        return envelope.task!
    }

    func postLocalAgentFlashJob(
        scope: String,
        source: FlashImageSource,
        boardID: String?,
        variantID: String?,
        deviceID: String? = nil,
        hostImageDir: String? = nil,
        hostImageFile: String? = nil
    ) async throws -> TaskResponse {
        let resolvedDeviceID = deviceID ?? currentOperationRoute().deviceID
        var payload: [String: Any] = [
            "image_source": source == .factory ? "factory" : "custom",
            "scope": scope,
            "build_mode": taishanPiDevelopmentMode.buildModeArgument
        ]
        if let hostImageFile, !hostImageFile.isEmpty {
            payload["host_image_file"] = hostImageFile
        } else if let hostImageDir, !hostImageDir.isEmpty {
            payload["host_image_dir"] = hostImageDir
        }
        if let boardID, !boardID.isEmpty {
            payload["board_id"] = boardID
        }
        if let variantID, !variantID.isEmpty {
            payload["variant_id"] = variantID
        }
        if let resolvedDeviceID, !resolvedDeviceID.isEmpty {
            payload["device_id"] = resolvedDeviceID
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
        setLocalAgentRunning(true)
        return envelope
    }

    func postLocalAgentRebootJob(
        target: String,
        boardID: String?,
        variantID: String?,
        deviceID: String? = nil
    ) async throws -> TaskResponse {
        let resolvedDeviceID = deviceID ?? currentOperationRoute().deviceID
        var payload: [String: Any] = [
            "target": target
        ]
        if let boardID, !boardID.isEmpty {
            payload["board_id"] = boardID
        }
        if let variantID, !variantID.isEmpty {
            payload["variant_id"] = variantID
        }
        if let resolvedDeviceID, !resolvedDeviceID.isEmpty {
            payload["device_id"] = resolvedDeviceID
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
        setLocalAgentRunning(true)
        return envelope
    }

    func postLocalAgentRuntimeJob(
        actionID: String,
        title: String,
        arguments: [String],
        deviceID: String? = nil,
        environmentOverrides: [String: String] = [:]
    ) async throws -> TaskResponse {
        let resolvedDeviceID = deviceID ?? currentOperationRoute().deviceID
        var payload: [String: Any] = [
            "action_id": actionID,
            "title": title,
            "arguments": arguments
        ]
        if let resolvedDeviceID, !resolvedDeviceID.isEmpty {
            payload["device_id"] = resolvedDeviceID
        }
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
        setLocalAgentRunning(true)
        return envelope
    }

    func postLocalAgentRP2350Job(
        action: String,
        boardID: String? = "ColorEasyPICO2",
        variantID: String? = "ColorEasyPICO2",
        deviceID: String? = nil,
        uf2Path: String? = nil,
        outputPath: String? = nil,
        lines: Int? = nil,
        follow: Bool? = nil
    ) async throws -> TaskResponse {
        await ensureLocalAgentStartedIfNeeded()
        guard localAgentRunning else {
            throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
        }
        let resolvedDeviceID = deviceID ?? currentOperationRoute().deviceID
        let resolvedBoardID = pluginBoardID(forLocalBoardID: boardID) ?? boardID ?? "ColorEasyPICO2"
        let resolvedVariantID = pluginBoardID(forLocalBoardID: variantID) ?? variantID ?? resolvedBoardID

        var payload: [String: Any] = [
            "action": action,
            "board_id": resolvedBoardID,
            "variant_id": resolvedVariantID,
        ]
        if let resolvedDeviceID, !resolvedDeviceID.isEmpty {
            payload["device_id"] = resolvedDeviceID
        }
        if let uf2Path, !uf2Path.isEmpty {
            payload["uf2_path"] = uf2Path
        }
        if let outputPath, !outputPath.isEmpty {
            payload["output_path"] = outputPath
        }
        if let lines {
            payload["lines"] = lines
        }
        if let follow {
            payload["follow"] = follow
        }

        var request = URLRequest(url: localAgentURL(path: "v1/jobs/rp2350"))
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ToolkitGUIError.commandFailed("RP2350 任务启动失败")
        }
        let envelope = try JSONDecoder().decode(TaskResponse.self, from: data)
        if http.statusCode != 200 || envelope.ok == false || envelope.task == nil {
            throw ToolkitGUIError.commandFailed(envelope.error ?? "RP2350 任务启动失败")
        }
        setLocalAgentRunning(true)
        return envelope
    }

    func runLocalAgentRP2350JobAndWait(
        action: String,
        boardID: String? = nil,
        variantID: String? = nil,
        deviceID: String? = nil,
        uf2Path: String? = nil,
        outputPath: String? = nil,
        lines: Int? = nil,
        follow: Bool? = nil,
        timeout: TimeInterval = 20
    ) async throws -> ToolkitTask {
        let envelope = try await postLocalAgentRP2350Job(
            action: action,
            boardID: boardID,
            variantID: variantID,
            deviceID: deviceID,
            uf2Path: uf2Path,
            outputPath: outputPath,
            lines: lines,
            follow: follow
        )
        guard let initialTask = envelope.task, let taskID = initialTask.id else {
            throw ToolkitGUIError.commandFailed("本地 DBT Agent 未返回 RP2350 任务信息")
        }
        let deadline = Date().addingTimeInterval(timeout)
        var latestTask = initialTask
        while !Task.isCancelled, Date() < deadline {
            latestTask = try await fetchLocalAgentTask(taskID)
            if latestTask.status == "finished" {
                guard latestTask.ok == true else {
                    throw ToolkitGUIError.commandFailed(latestTask.output_tail ?? "RP2350 任务执行失败")
                }
                return latestTask
            }
            try await Task.sleep(for: .milliseconds(700))
        }
        throw ToolkitGUIError.timeout("RP2350 任务超时")
    }

    private func bindRP2350BoardModelIfNeeded(boardID: String?, variantID: String?, deviceID: String?) async throws {
        guard let boardID, isRP2350BoardID(boardID) else {
            return
        }
        let selectedRPDevice: ToolkitStatus.Device? = {
            if let deviceID {
                return status?.devices?.first(where: { $0.device_id == deviceID })
            }
            return nil
        }()
        let transportText = [
            selectedRPDevice?.transport_name?.lowercased(),
            selectedRPDevice?.interface_name?.lowercased(),
            selectedRPDevice?.display_label?.lowercased(),
        ].compactMap { $0 }.joined(separator: " ")
        let routeRuntimeReady: Bool = {
            if !transportText.isEmpty {
                if transportText.contains("bootsel") { return false }
                return transportText.contains("rp2350") || transportText.contains("usb") || transportText.contains("serial")
            }
            let rpState = ((status?.rp2350?.state ?? status?.usb?.mode ?? "")).lowercased()
            return rpState.contains("runtime")
        }()
        guard routeRuntimeReady else {
            return
        }
        _ = try await runLocalAgentRP2350JobAndWait(
            action: "set_board_model",
            boardID: boardID,
            variantID: variantID ?? boardID,
            deviceID: deviceID,
            timeout: 12
        )
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
            throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
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

    private func queueRP2350Job(
        title: String,
        action: String,
        boardID: String? = nil,
        variantID: String? = nil,
        deviceID: String? = nil,
        uf2Path: String? = nil,
        outputPath: String? = nil,
        lines: Int? = nil,
        successMessage: String
    ) async throws {
        await ensureLocalAgentStartedIfNeeded()
        guard localAgentRunning else {
            throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
        }
        let resolvedRoute = currentOperationRoute()
        let resolvedBoardID = boardID ?? resolvedRoute.boardID
        let resolvedVariantID = variantID ?? resolvedRoute.variantID
        let resolvedDeviceID = deviceID ?? resolvedRoute.deviceID
        if action != "detect" && action != "set_board_model" {
            try await bindRP2350BoardModelIfNeeded(boardID: resolvedBoardID, variantID: resolvedVariantID, deviceID: resolvedDeviceID)
        }
        clearInlineError()
        taskPollTask?.cancel()
        dismissedFinishedTaskIDs.removeAll()
        currentTask = nil
        pendingTaskTitle = title
        let response = try await postLocalAgentRP2350Job(
            action: action,
            boardID: resolvedBoardID,
            variantID: resolvedVariantID,
            deviceID: resolvedDeviceID,
            uf2Path: uf2Path,
            outputPath: outputPath,
            lines: lines,
            follow: false
        )
        pendingTaskTitle = ""
        currentTask = response.task
        appendActivity(level: .info, title: title, message: successMessage, detail: response.task?.log_path)
        if let taskID = response.task?.id {
            pollTask(taskID)
        }
    }

    func applyLocalAgentStatusSummary(_ agentStatus: AgentStatusSummaryResponse, silent: Bool = false) {
        if let mergedRuntimeStatus = mergedRuntimeStatus(from: agentStatus) {
            applyStatusUpdate(mergedRuntimeStatus, silent: silent)
            return
        }

        let transportName: String? = {
            if isRP2350BoardID(agentStatus.board_id) {
                return agentStatus.connected_device == true ? "RP2350 单 USB" : nil
            }
            return agentStatus.usb_ecm_ready == true ? "USB ECM" : nil
        }()
        let nextDevice = ToolkitStatus.Device(
            device_id: agentStatus.device_id,
            device_uid: nil,
            board_id: agentStatus.board_id,
            variant_id: agentStatus.variant_id,
            connected: agentStatus.connected_device,
            transport_locator: nil,
            display_label: connectedBoardDisplayName,
            display_name: connectedBoardDisplayName,
            manufacturer: nil,
            interface_name: nil,
            transport_name: transportName,
            source_name: "dbt-agentd"
        )
        let merged = mergedStatus(
            usbnet: ToolkitStatus.USBNet(
                iface: status?.usbnet?.iface,
                current_ip: status?.usbnet?.current_ip,
                expected_ip: status?.usbnet?.expected_ip,
                board_ip: status?.usbnet?.board_ip,
                slot: status?.usbnet?.slot,
                configured: agentStatus.usb_ecm_ready
            ),
            board: ToolkitStatus.Board(
                ping: agentStatus.connected_device,
                ssh_port_open: agentStatus.ssh_ready,
                control_service: agentStatus.control_service_ready
            ),
            device: nextDevice,
            deviceID: agentStatus.device_id,
            activeDeviceID: agentStatus.active_device_id,
            devices: agentStatus.devices,
            summary: agentStatus.summary,
            deviceSummary: agentStatus.device_summary,
            updatedAt: agentStatus.updated_at
        )
        applyStatusUpdate(merged, silent: silent)
    }

    private func mergedRuntimeStatus(from agentStatus: AgentStatusSummaryResponse) -> ToolkitStatus? {
        guard let runtimeStatus = agentStatus.runtime_status else {
            return nil
        }
        let normalizedUSBNet = ToolkitStatus.USBNet(
            iface: runtimeStatus.usbnet?.iface,
            current_ip: runtimeStatus.usbnet?.current_ip,
            expected_ip: runtimeStatus.usbnet?.expected_ip,
            board_ip: runtimeStatus.usbnet?.board_ip,
            slot: runtimeStatus.usbnet?.slot,
            configured: agentStatus.usb_ecm_ready ?? runtimeStatus.usbnet?.configured
        )
        let normalizedBoard = ToolkitStatus.Board(
            ping: runtimeStatus.board?.ping,
            ssh_port_open: agentStatus.ssh_ready ?? runtimeStatus.board?.ssh_port_open,
            control_service: agentStatus.control_service_ready ?? runtimeStatus.board?.control_service
        )
        return ToolkitStatus(
            repo_root: runtimeStatus.repo_root,
            service: runtimeStatus.service,
            updated_at: agentStatus.updated_at ?? runtimeStatus.updated_at,
            usb: runtimeStatus.usb,
            usbnet: normalizedUSBNet,
            board: normalizedBoard,
            host: runtimeStatus.host,
            device: runtimeStatus.device,
            device_id: agentStatus.device_id ?? runtimeStatus.device_id,
            active_device_id: agentStatus.active_device_id ?? runtimeStatus.active_device_id,
            devices: agentStatus.devices ?? runtimeStatus.devices,
            rp2350: runtimeStatus.rp2350,
            summary: agentStatus.summary ?? runtimeStatus.summary,
            device_summary: agentStatus.device_summary ?? runtimeStatus.device_summary
        )
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
            try FileManager.default.createDirectory(at: boardPluginStateRootURL(), withIntermediateDirectories: true)
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
                let pluginID = pluginBoardID(forLocalBoardID: board.id) ?? board.id
                let downloadURL = derivedBoardPluginDownloadURL(boardID: board.id, version: version)
                let checksumURL = derivedBoardPluginChecksumURL(boardID: board.id, version: version)
                try FileManager.default.createDirectory(at: boardPluginDownloadsRootURL(), withIntermediateDirectories: true)
                let zipURL = boardPluginDownloadsRootURL().appendingPathComponent("\(pluginID)-\(version).zip")

                try await downloadBoardPluginArchive(from: downloadURL, to: zipURL, boardID: board.id)

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.72, message: "校验下载文件")
                let expectedSHA = try await fetchBoardPluginChecksum(from: checksumURL)
                let actualSHA = try sha256Hex(for: zipURL)
                guard actualSHA.caseInsensitiveCompare(expectedSHA) == .orderedSame else {
                    throw ToolkitGUIError.commandFailed("插件校验失败：SHA256 不匹配")
                }

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.84, message: "安装插件")
                let installRoots = boardPluginInstallRootURLs(for: board.id)
                guard let installRoot = installRoots.first else {
                    throw ToolkitGUIError.commandFailed("无法解析插件安装目录：\(board.id)")
                }
                for root in installRoots {
                    if FileManager.default.fileExists(atPath: root.path) {
                        try FileManager.default.removeItem(at: root)
                    }
                    try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try unzipBoardPluginArchive(zipURL: zipURL, destinationURL: root)
                }

                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .installing, progress: 0.93, message: "校验插件内容")
                let metadata = try validateInstalledBoardPlugin(at: installRoot, expectedBoardID: pluginID, expectedVersion: version)

                installedBoardPlugins[board.id] = version
                installedBoardPlugins.removeValue(forKey: pluginID)
                installedBoardPluginMetadata[board.id] = metadata
                installedBoardPluginMetadata.removeValue(forKey: pluginID)
                try persistInstalledBoardPlugins()
                boardPluginOperations[board.id] = BoardPluginOperationState(kind: .idle, progress: nil, message: "")
                appendActivity(level: .success, title: "插件安装", message: "\(board.displayName) 插件安装完成", detail: "版本 \(version)")
                refreshStatus(silent: true)
            } catch {
                for installRoot in boardPluginInstallRootURLs(for: board.id) {
                    if FileManager.default.fileExists(atPath: installRoot.path) {
                        try? FileManager.default.removeItem(at: installRoot)
                    }
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
            boardPluginAlert = BoardPluginAlert(title: "插件删除失败", message: "\(board.displayName) 当前未安装或状态不可删除。")
            return
        }

        boardPluginOperations[board.id] = BoardPluginOperationState(kind: .deleting, progress: nil, message: "正在删除")
        Task {
            do {
                for installRoot in boardPluginInstallRootURLs(for: board.id) {
                    if FileManager.default.fileExists(atPath: installRoot.path) {
                        try FileManager.default.removeItem(at: installRoot)
                    }
                }
                installedBoardPlugins.removeValue(forKey: board.id)
                let pluginID = pluginBoardID(forLocalBoardID: board.id) ?? board.id
                installedBoardPlugins.removeValue(forKey: pluginID)
                installedBoardPluginMetadata.removeValue(forKey: board.id)
                installedBoardPluginMetadata.removeValue(forKey: pluginID)
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
        remoteBoardPluginEntries = Dictionary(uniqueKeysWithValues: entries.map { (localBoardID(forPluginBoardID: $0.id) ?? $0.id, $0) })
        boardPluginCatalogVersions = Dictionary(uniqueKeysWithValues: entries.map { (localBoardID(forPluginBoardID: $0.id) ?? $0.id, $0.version ?? "") })
        boardPluginCatalogCheckedAt = checkedAt
        updateBoardRoutingFromCurrentState()
    }

    private func mergedBoardCatalog(with entries: [RemoteBoardPluginEntry]) -> [SupportedBoard] {
        let builtInByID = Dictionary(uniqueKeysWithValues: SupportedBoard.catalog.map { ($0.id, $0) })
        var merged: [SupportedBoard] = []
        var seen = Set<String>()

        for entry in entries {
            let localID = localBoardID(forPluginBoardID: entry.id) ?? entry.id
            let base = builtInByID[localID] ?? placeholderBoard(for: entry, localBoardID: localID)
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
            seen.insert(localID)
        }

        for board in SupportedBoard.catalog where !seen.contains(board.id) {
            merged.append(board)
        }

        return merged
    }

    private func placeholderBoard(for entry: RemoteBoardPluginEntry, localBoardID overrideLocalBoardID: String? = nil) -> SupportedBoard {
        let resolvedID = overrideLocalBoardID ?? localBoardID(forPluginBoardID: entry.id) ?? entry.id
        return SupportedBoard(
            id: resolvedID,
            englishName: resolvedID,
            displayName: entry.display_name ?? resolvedID,
            manufacturer: entry.manufacturer ?? "未知厂家",
            modelDirectoryName: nil,
            variantDisplayNames: entry.variants ?? [entry.display_name ?? resolvedID],
            shortSummary: "该开发板插件来自远端插件目录，当前 GUI 版本尚未内置详细说明。",
            detailSummary: "该开发板插件已从远端目录发现，但当前应用版本没有内置该开发板的详细资料。后续可通过插件形式补全识别、动作和展示信息。",
            integrationStatus: "已发现远端插件目录项，等待安装。",
            integrationReady: false,
            thumbnailLabel: resolvedID.uppercased(),
            thumbnailSymbol: "shippingbox.fill",
            accentStart: Color(red: 0.35, green: 0.45, blue: 0.62),
            accentEnd: Color(red: 0.22, green: 0.30, blue: 0.42),
            capabilities: [.usbProbe],
            searchableTerms: [resolvedID.lowercased()]
        )
    }

    func showSupportedBoardCatalog() {
        showingSupportedBoardCatalog = true
        boardCatalogBaselineSignature = candidateSignature(for: detectedBoardCandidates)
        boardCatalogResetRequestID = UUID()
    }

    func setPreferredControlBoard(_ boardID: String?) {
        preferredControlBoardID = boardID
        refreshRP2350DefaultUF2Path(for: boardID)
        if let boardID, !boardID.isEmpty {
            UserDefaults.standard.set(boardID, forKey: "preferredControlBoardID")
        } else {
            UserDefaults.standard.removeObject(forKey: "preferredControlBoardID")
        }
        if let boardID, !boardID.isEmpty {
            if let candidate =
                activeControlDeviceCandidates.first(where: { $0.boardID == boardID }) ??
                detectedBoardCandidates.first(where: { $0.boardID == boardID }) {
                selectedDetectedCandidateID = candidate.id
                connectedBoardID = boardID
                connectedBoardVariantID = candidate.variantID
                connectedBoardDisplayName = stableBoardDisplayName(for: boardID, variantID: candidate.variantID) ?? candidate.displayName
                if preferredControlDeviceID != candidate.deviceID {
                    preferredControlDeviceID = candidate.deviceID
                    UserDefaults.standard.set(candidate.deviceID, forKey: "preferredControlDeviceID")
                }
            } else {
                if let currentDeviceID = preferredControlDeviceID,
                   let currentCandidate =
                    activeControlDeviceCandidates.first(where: { $0.deviceID == currentDeviceID }) ??
                    detectedBoardCandidates.first(where: { $0.deviceID == currentDeviceID }),
                   currentCandidate.boardID != boardID {
                    setPreferredControlDevice(nil)
                }
                if let board = supportedBoard(for: boardID) {
                    connectedBoardID = board.id
                    connectedBoardVariantID = nil
                    connectedBoardDisplayName = board.conciseModelLabel
                }
            }
        }
        refreshActionAvailability()
    }

    func setPreferredControlDevice(_ deviceID: String?) {
        if preferredControlDeviceID == deviceID {
            return
        }
        preferredControlDeviceID = deviceID
        if let deviceID, !deviceID.isEmpty {
            UserDefaults.standard.set(deviceID, forKey: "preferredControlDeviceID")
        } else {
            UserDefaults.standard.removeObject(forKey: "preferredControlDeviceID")
        }
        if let deviceID,
           let candidate =
            activeControlDeviceCandidates.first(where: { $0.deviceID == deviceID }) ??
            detectedBoardCandidates.first(where: { $0.deviceID == deviceID }) {
            selectedDetectedCandidateID = candidate.id
            connectedBoardID = candidate.boardID
            connectedBoardVariantID = candidate.variantID
            connectedBoardDisplayName = stableBoardDisplayName(for: candidate.boardID, variantID: candidate.variantID) ?? candidate.displayName
            if preferredControlBoardID != candidate.boardID {
                preferredControlBoardID = candidate.boardID
                UserDefaults.standard.set(candidate.boardID, forKey: "preferredControlBoardID")
            }
            showingSupportedBoardCatalog = false
            boardCatalogBaselineSignature = nil
        }
        refreshActionAvailability()
    }

    func showControlPage(for board: SupportedBoard) {
        connectedBoardID = board.id
        connectedBoardVariantID = nil
        connectedBoardDisplayName = board.conciseModelLabel
        refreshRP2350DefaultUF2Path(for: board.id)
        setPreferredControlBoard(board.id)
        if let candidate = detectedBoardCandidates.first(where: { $0.boardID == board.id }) {
            setPreferredControlDevice(candidate.deviceID)
        } else {
            setPreferredControlDevice(nil)
        }
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
            preferredControlDeviceID == candidate.deviceID &&
            showingSupportedBoardCatalog == false &&
            deviceSelectionPrompt == nil
        if sameSelection {
            return
        }
        selectedDetectedCandidateID = candidate.id
        connectedBoardID = candidate.boardID
        connectedBoardVariantID = candidate.variantID
        connectedBoardDisplayName = stableBoardDisplayName(for: candidate.boardID, variantID: candidate.variantID) ?? candidate.displayName
        setPreferredControlBoard(candidate.boardID)
        setPreferredControlDevice(candidate.deviceID)
        showingSupportedBoardCatalog = false
        boardCatalogBaselineSignature = nil
        deviceSelectionPrompt = nil
    }

    private func refreshDetectedBoardState(_ candidate: DetectedBoardCandidate, preserveCatalogPresentation: Bool) {
        selectedDetectedCandidateID = candidate.id
        connectedBoardID = candidate.boardID
        connectedBoardVariantID = candidate.variantID
        connectedBoardDisplayName = stableBoardDisplayName(for: candidate.boardID, variantID: candidate.variantID) ?? candidate.displayName
        setPreferredControlDevice(candidate.deviceID)
        if !preserveCatalogPresentation {
            setPreferredControlBoard(candidate.boardID)
            showingSupportedBoardCatalog = false
            boardCatalogBaselineSignature = nil
        }
        deviceSelectionPrompt = nil
    }

    func dismissDeviceSelectionPrompt() {
        deviceSelectionPrompt = nil
    }

    private func updateBoardRoutingFromCurrentState() {
        let candidates = scanDetectedBoardCandidates()
        let targetBoardID = preferredControlBoardID ?? connectedBoardID
        if detectedBoardCandidates != candidates {
            detectedBoardCandidates = candidates
        }
        refreshActionAvailability()
        if candidates.isEmpty {
            if deviceSelectionPrompt != nil {
                deviceSelectionPrompt = nil
            }
            if rp2350FlashTargetPrompt != nil {
                rp2350FlashTargetPrompt = nil
            }
            selectedDetectedCandidateID = nil
            preferredControlDeviceID = nil
            return
        }

        if let selectedDetectedCandidateID,
           let selected = candidates.first(where: { $0.id == selectedDetectedCandidateID }),
           targetBoardID == nil || boardMatches(selected.boardID, targetBoardID: targetBoardID!)
        {
            connectedBoardID = selected.boardID
            connectedBoardVariantID = selected.variantID
            connectedBoardDisplayName = stableBoardDisplayName(for: selected.boardID, variantID: selected.variantID) ?? selected.displayName
            if preferredControlDeviceID == nil || preferredControlDeviceID == selected.deviceID {
                setPreferredControlDevice(selected.deviceID)
            }
            deviceSelectionPrompt = nil
            return
        }

        if let preferredControlDeviceID,
           let preferred = candidates.first(where: { $0.deviceID == preferredControlDeviceID }),
           targetBoardID == nil || boardMatches(preferred.boardID, targetBoardID: targetBoardID!)
        {
            selectedDetectedCandidateID = preferred.id
            connectedBoardID = preferred.boardID
            connectedBoardVariantID = preferred.variantID
            connectedBoardDisplayName = stableBoardDisplayName(for: preferred.boardID, variantID: preferred.variantID) ?? preferred.displayName
            deviceSelectionPrompt = nil
            return
        }

        if let connectedBoardID,
           let board = supportedBoard(for: connectedBoardID) {
            if let sameBoardCandidate = candidates.first(where: { $0.boardID == connectedBoardID }) {
                selectedDetectedCandidateID = sameBoardCandidate.id
                connectedBoardVariantID = sameBoardCandidate.variantID
                let currentPreferredMatchesBoard = candidates.contains {
                    $0.deviceID == preferredControlDeviceID && boardMatches($0.boardID, targetBoardID: connectedBoardID)
                }
                if preferredControlDeviceID == nil || !currentPreferredMatchesBoard {
                    setPreferredControlDevice(sameBoardCandidate.deviceID)
                }
            } else {
                selectedDetectedCandidateID = nil
            }
            connectedBoardDisplayName = board.conciseModelLabel
            deviceSelectionPrompt = nil
            return
        }

        if let preferredBoardID = preferredControlBoardID,
           let board = supportedBoard(for: preferredBoardID) {
            connectedBoardID = board.id
            if let sameBoardCandidate = candidates.first(where: { $0.boardID == preferredBoardID }) {
                selectedDetectedCandidateID = sameBoardCandidate.id
                connectedBoardVariantID = sameBoardCandidate.variantID
                setPreferredControlDevice(sameBoardCandidate.deviceID)
            } else {
                selectedDetectedCandidateID = nil
                connectedBoardVariantID = nil
            }
            connectedBoardDisplayName = board.conciseModelLabel
            deviceSelectionPrompt = nil
            return
        }

        if deviceSelectionPrompt != nil {
            deviceSelectionPrompt = nil
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

        let statusDevices: [ToolkitStatus.Device]
        if let devices = status?.devices, !devices.isEmpty {
            statusDevices = devices
        } else if let device = status?.device {
            statusDevices = [device]
        } else {
            statusDevices = []
        }

        for device in statusDevices where device.connected == true {
            guard let boardID = device.board_id,
                  isBoardPluginInstalled(boardID) || supportedBoard(for: boardID) != nil else {
                continue
            }
            let displayName = device.display_label ?? device.display_name ?? supportedBoard(for: boardID)?.displayName ?? boardID
            let manufacturer = device.manufacturer ?? supportedBoard(for: boardID)?.manufacturer ?? "未知厂家"
            let interfaceName = device.interface_name ?? status?.usbnet?.iface ?? "设备接口"
            let transportName = device.transport_name ?? status?.usb?.mode ?? "设备连接"
            let sourceName = device.source_name ?? "状态服务"
            let variantID = device.variant_id
            let deviceID = device.device_id
            candidates.append(
                DetectedBoardCandidate(
                    id: deviceID ?? "\(boardID)-status-\(variantID ?? "default")-\(interfaceName)",
                    deviceID: deviceID,
                    boardID: boardID,
                    variantID: variantID,
                    displayName: displayName,
                    manufacturer: manufacturer,
                    interfaceName: interfaceName,
                    transportName: transportName,
                    transportLocator: device.transport_locator,
                    sourceName: sourceName,
                    priority: 120
                )
            )
        }

        let candidatesWithStableIdentity = candidates.filter { $0.deviceID != nil }
        let semanticKeysWithStableIdentity = Set(
            candidatesWithStableIdentity.map { "\($0.boardID)::\($0.variantID ?? "default")" }
        )
        let filteredCandidates = candidates.filter { candidate in
            guard candidate.deviceID == nil else { return true }
            let semanticKey = "\(candidate.boardID)::\(candidate.variantID ?? "default")"
            return !semanticKeysWithStableIdentity.contains(semanticKey)
        }

        var deduped: [String: DetectedBoardCandidate] = [:]
        for candidate in filteredCandidates.sorted(by: { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id < rhs.id
            }
            return lhs.priority > rhs.priority
        }) {
            let dedupeKey: String
            if let deviceID = candidate.deviceID, !deviceID.isEmpty {
                dedupeKey = "device::\(deviceID)"
            } else if let transportLocator = candidate.transportLocator, !transportLocator.isEmpty {
                dedupeKey = "transport::\(candidate.boardID)::\(candidate.variantID ?? "default")::\(transportLocator)"
            } else {
                dedupeKey = "semantic::\(candidate.boardID)::\(candidate.variantID ?? "default")"
            }
            if deduped[dedupeKey] == nil {
                deduped[dedupeKey] = candidate
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
        return URL(string: "https://raw.githubusercontent.com/kkwell/development-board-toolchain/main/board_plugins/boards/\(boardID)/releases/\(version)/plugin.zip")!
    }

    private func derivedBoardPluginChecksumURL(boardID: String, version: String) -> URL {
        if let value = remoteBoardPluginEntry(boardID)?.checksum_url,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        return URL(string: "https://raw.githubusercontent.com/kkwell/development-board-toolchain/main/board_plugins/boards/\(boardID)/releases/\(version)/plugin.zip.sha256")!
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
            currentDirectoryURL: boardPluginStateRootURL(),
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
        return nil
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

    private func fallbackUSBNetStatus(from current: ToolkitStatus.USBNet? = nil) -> ToolkitStatus.USBNet {
        let base = current ?? status?.usbnet
        return ToolkitStatus.USBNet(
            iface: base?.iface,
            current_ip: base?.current_ip,
            expected_ip: base?.expected_ip,
            board_ip: base?.board_ip,
            slot: base?.slot,
            configured: base?.configured ?? false
        )
    }

    private func nonEmptyUSBNetValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty, trimmed != "-" else {
            return nil
        }
        return trimmed
    }

    func currentExpectedUSBHostIP() -> String? {
        nonEmptyUSBNetValue(status?.usbnet?.expected_ip)
    }

    func currentBoardUSBIP() -> String? {
        nonEmptyUSBNetValue(status?.usbnet?.board_ip)
    }

    func usbNetRecoveryProgressText() -> String {
        if let hostIP = currentExpectedUSBHostIP() {
            return "检测到 USB ECM，正在恢复主机地址 \(hostIP)…"
        }
        return "检测到 USB ECM，正在恢复主机 USB 网络…"
    }

    var usbNetHelperWarningText: String {
        if let hostIP = currentExpectedUSBHostIP() {
            return "未安装前，板子重启后 Mac 无法自动把 USB ECM 地址恢复到 \(hostIP)。"
        }
        return "未安装前，板子重启后 Mac 无法自动恢复 DBT 分配的 USB ECM 主机地址。"
    }

    func placeholderStatus() -> ToolkitStatus {
        ToolkitStatus(
            repo_root: status?.repo_root,
            service: status?.service,
            updated_at: ISO8601DateFormatter().string(from: Date()),
            usb: status?.usb ?? .init(mode: "absent", product: nil, pid: nil),
            usbnet: fallbackUSBNetStatus(),
            board: status?.board ?? .init(ping: false, ssh_port_open: false, control_service: false),
            host: status?.host,
            device: status?.device,
            device_id: status?.device_id,
            active_device_id: status?.active_device_id,
            devices: status?.devices,
            rp2350: status?.rp2350,
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
        deviceID: String? = nil,
        activeDeviceID: String? = nil,
        devices: [ToolkitStatus.Device]? = nil,
        summary: String? = nil,
        deviceSummary: String? = nil,
        updatedAt: String? = nil
    ) -> ToolkitStatus {
        let current = status ?? placeholderStatus()
        return ToolkitStatus(
            repo_root: current.repo_root,
            service: current.service,
            updated_at: updatedAt ?? ISO8601DateFormatter().string(from: Date()),
            usb: usb ?? current.usb,
            usbnet: usbnet ?? current.usbnet,
            board: board ?? current.board,
            host: host ?? current.host,
            device: device ?? current.device,
            device_id: deviceID ?? current.device_id,
            active_device_id: activeDeviceID ?? current.active_device_id,
            devices: devices ?? current.devices,
            rp2350: current.rp2350,
            summary: summary ?? current.summary,
            device_summary: deviceSummary ?? current.device_summary
        )
    }

    func imageDirURL(for source: FlashImageSource) -> URL {
        switch source {
        case .custom:
            return taishanPiDevelopmentMode == .macLLVM ? macLLVMCustomImageDirURL() : linuxGCCCustomImageDirURL()
        case .factory:
            return taishanPiDevelopmentMode == .macLLVM ? macLLVMFactoryImageDirURL() : linuxGCCFactoryImageDirURL()
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
        let imageDir = imageDirURL(for: .factory)
        let required = [
            imageDir.appendingPathComponent("parameter.txt").path,
            imageDir.appendingPathComponent("boot.img").path,
            imageDir.appendingPathComponent("userdata.img").path,
        ]
        if required.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) {
            return
        }
        if taishanPiDevelopmentMode == .macLLVM {
            throw ToolkitGUIError.commandFailed("未找到 Mac LLVM 初始镜像：\(imageDir.path)。请先挂载或安装 Mac LLVM 离线环境包。")
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

            let imageDir = linuxGCCFactoryImageDirURL()
            let requiredHostImages = [
                imageDir.appendingPathComponent("parameter.txt").path,
                imageDir.appendingPathComponent("boot.img").path,
                imageDir.appendingPathComponent("userdata.img").path,
            ]
            next.hostImagesReady = requiredHostImages.allSatisfy { FileManager.default.fileExists(atPath: $0) }

            if next.dockerReady {
                let volumeCheck = try await runSystemShell("docker volume inspect '\(officialVolumeName)' >/dev/null 2>&1")
                next.releaseVolumeReady = volumeCheck.0 == 0
            }

            let llvmSDKRoot = taishanPiLLVMSDKRootURL()
            let portableReleaseRoot = taishanPiLLVMReleaseRootURL()
            next.llvmSDKRoot = llvmSDKRoot.path
            next.llvmSDKMounted = FileManager.default.fileExists(atPath: llvmSDKRoot.path)
            next.llvmSDKCaseSensitive = volumeSupportsCaseSensitiveNames(at: llvmSDKRoot)
            next.llvmEntryScriptsReady =
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("build-llvm.sh").path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("llvm-env.sh").path)
                ) ||
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("scripts/portable-qmake.sh").path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("toolchain/qt6-rk3566-llvm-toolchain.cmake").path)
                )
            next.llvmCrossWrappersReady =
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent(".llvm-cross", isDirectory: true).path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent(".llvm-cross/bin", isDirectory: true).path)
                ) ||
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("toolchain/llvm-cross", isDirectory: true).path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("toolchain/llvm-cross/bin/aarch64-linux-gnu-gcc").path)
                )
            next.llvmHostWrappersReady =
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent(".llvm-host-tools", isDirectory: true).path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent(".llvm-host-tools/bin", isDirectory: true).path)
                ) ||
                (
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("toolchain/host-tools", isDirectory: true).path) &&
                    FileManager.default.fileExists(atPath: llvmSDKRoot.appendingPathComponent("toolchain/host-tools/bin/clang-aarch64-linux-gnu").path)
                )
            next.llvmClangReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/host-tools/bin/clang-aarch64-linux-gnu").path,
                    portableReleaseRoot.appendingPathComponent("toolchain/host-tools/bin/clang-aarch64-linux-gnu").path,
                    "/opt/homebrew/opt/llvm/bin/clang",
                    "/usr/local/opt/llvm/bin/clang"
                ],
                fallbackCommand: "clang"
            )
            next.llvmLLDReady = await executableAvailable(
                candidatePaths: [
                    "/opt/homebrew/opt/lld/bin/ld.lld",
                    "/usr/local/opt/lld/bin/ld.lld",
                    "/opt/homebrew/opt/llvm/bin/ld.lld",
                    "/usr/local/opt/llvm/bin/ld.lld",
                    llvmSDKRoot.appendingPathComponent("toolchain/llvm-cross/bin/aarch64-linux-gnu-gcc").path
                ],
                fallbackCommand: "ld.lld"
            )
            next.llvmObjcopyReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/llvm-cross/bin/aarch64-linux-gnu-objcopy").path,
                    llvmSDKRoot.appendingPathComponent(".llvm-cross/bin/aarch64-linux-gnu-objcopy").path,
                    "/opt/homebrew/opt/llvm/bin/llvm-objcopy",
                    "/usr/local/opt/llvm/bin/llvm-objcopy"
                ],
                fallbackCommand: "llvm-objcopy"
            )
            next.llvmReadelfReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/llvm-cross/bin/aarch64-linux-gnu-readelf").path,
                    llvmSDKRoot.appendingPathComponent(".llvm-cross/bin/aarch64-linux-gnu-readelf").path,
                    "/opt/homebrew/opt/llvm/bin/llvm-readelf",
                    "/usr/local/opt/llvm/bin/llvm-readelf"
                ],
                fallbackCommand: "llvm-readelf"
            )
            next.llvmPython3Ready = await executableAvailable(candidatePaths: [], fallbackCommand: "python3")
            next.llvmDtcReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/host-tools/bin/dtc").path,
                    llvmSDKRoot.appendingPathComponent(".llvm-host-tools/bin/dtc").path,
                    "/opt/homebrew/bin/dtc",
                    "/usr/local/bin/dtc"
                ],
                fallbackCommand: "dtc"
            )
            next.llvmFakerootReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/host/bin/fakeroot").path,
                    "/opt/homebrew/bin/fakeroot",
                    "/usr/local/bin/fakeroot"
                ],
                fallbackCommand: "fakeroot"
            )
            next.llvmMke2fsReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/host/sbin/mke2fs").path,
                    "/opt/homebrew/opt/e2fsprogs/sbin/mke2fs",
                    "/usr/local/opt/e2fsprogs/sbin/mke2fs",
                    "/opt/homebrew/sbin/mke2fs",
                    "/usr/local/sbin/mke2fs"
                ],
                fallbackCommand: "mke2fs"
            )
            next.llvmTune2fsReady = await executableAvailable(
                candidatePaths: [
                    llvmSDKRoot.appendingPathComponent("toolchain/host/sbin/tune2fs").path,
                    "/opt/homebrew/opt/e2fsprogs/sbin/tune2fs",
                    "/usr/local/opt/e2fsprogs/sbin/tune2fs",
                    "/opt/homebrew/sbin/tune2fs",
                    "/usr/local/sbin/tune2fs"
                ],
                fallbackCommand: "tune2fs"
            )
            next.llvmFactoryImagesReady = directoryHasTaishanPiImageSet(macLLVMFactoryImageDirURL())
            next.llvmCustomImagesReady = directoryHasTaishanPiImageSet(macLLVMCustomImageDirURL())
            next.llvmBootProbeImagesReady = directoryHasTaishanPiImageSet(taishanPiLLVMBootProbeImageDirURL())

            let home = NSHomeDirectory()
            let codexCandidates = [
                "\(home)/.codex/plugins/dbt-agent/.codex-plugin/plugin.json",
                "\(home)/.codex/.tmp/plugins/plugins/dbt-agent/.codex-plugin/plugin.json",
                "\(home)/plugins/dbt-agent/.codex-plugin/plugin.json",
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
            next.npmReady = await commandExists("npm")
            next.openCodeAvailable = await commandExists("opencode") || FileManager.default.fileExists(atPath: "\(home)/.config/opencode")
            next.openCodePluginInstalled =
                opencodeCandidates.allSatisfy { FileManager.default.fileExists(atPath: $0) } ||
                legacyOpenCodeCandidates.allSatisfy { FileManager.default.fileExists(atPath: $0) }

            developmentInstallStatus = next
            autoSelectTaishanPiDevelopmentMode(using: next)
            refreshActionAvailability()
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
        return "unknown"
    }

    private func preferredToolkitManifestURL() -> String {
        "https://github.com/kkwell/development-board-toolchain-gui/releases/latest/download/toolkit-manifest.json"
    }

    private func toolkitUpdateEnvironmentOverrides() -> [String: String] {
        ["RK356X_REMOTE_TOOLKIT_MANIFEST_URL": preferredToolkitManifestURL()]
    }

    func refreshToolkitUpdateStatus() {
        var next = toolkitUpdateStatus
        next.currentVersion = currentToolkitVersion()
        let runtimeCLI = sharedRuntimeRootURL().appendingPathComponent(runtimeBinaryName).path
        next.configured = FileManager.default.fileExists(atPath: runtimeCLI)
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
            refreshStatus(silent: true, force: true)
            return nil

        case .ensureUSBNet:
            return await localAgentOperationPreflightMessage(operationID: "usb_ecm", boardID: route.boardID, variantID: route.variantID)

        case .authorizeKey:
            return await localAgentOperationPreflightMessage(operationID: "usb_control", boardID: route.boardID, variantID: route.variantID)

        case .rebootLoader, .rebootDevice:
            return actionAvailabilityState(for: precondition).reason

        case .flash:
            if let localMessage = actionAvailabilityState(for: precondition).reason {
                return localMessage
            }
            return nil

        case .buildSync:
            if taishanPiDevelopmentMode == .macLLVM {
                return actionAvailabilityState(for: precondition).reason
            }
            return await localAgentOperationPreflightMessage(operationID: "docker_ready", boardID: route.boardID, variantID: route.variantID)

        case .buildSyncFlash:
            if taishanPiDevelopmentMode == .macLLVM {
                if let localMessage = actionAvailabilityState(for: precondition).reason {
                    return localMessage
                }
                return await localAgentOperationPreflightMessage(operationID: "flash_transport", boardID: route.boardID, variantID: route.variantID)
            }
            if let message = await localAgentOperationPreflightMessage(operationID: "docker_ready", boardID: route.boardID, variantID: route.variantID) {
                return message
            }
            if let localMessage = actionAvailabilityState(for: precondition).reason {
                return localMessage
            }
            return await localAgentOperationPreflightMessage(operationID: "flash_transport", boardID: route.boardID, variantID: route.variantID)

        case let .updateLogo(flashAfter):
            if let message = await localAgentOperationPreflightMessage(operationID: "docker_ready", boardID: route.boardID, variantID: route.variantID) {
                return message
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
            if let message = await localAgentOperationPreflightMessage(operationID: "docker_ready", boardID: route.boardID, variantID: route.variantID) {
                return message
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
        setLocalAgentRunning((try? await fetchLocalAgentHealthz()) != nil)
        eventStreamConnected = false
    }

    func refreshTransportStatus(silent: Bool = true) async {
        do {
            let agentStatus = try await fetchLocalAgentStatusSummary()
            if shouldIgnoreStaleConnectedAgentStatus(agentStatus) {
                return
            }
            let runtimeStatus = mergedRuntimeStatus(from: agentStatus) ?? agentStatus.runtime_status
            let nextUSB = runtimeStatus?.usb ?? ToolkitStatus.USB(mode: "absent", product: nil, pid: nil)
            let nextUSBNet = runtimeStatus?.usbnet ?? fallbackUSBNetStatus()
            let connected = nextUSB.mode == "usb-ecm" && nextUSBNet.configured == true
            let nextBoard = connected ? runtimeStatus?.board : ToolkitStatus.Board(ping: false, ssh_port_open: false, control_service: false)
            let merged = mergedStatus(
                usb: nextUSB,
                usbnet: nextUSBNet,
                board: nextBoard,
                device: runtimeStatus?.device,
                deviceID: agentStatus.device_id ?? runtimeStatus?.device_id,
                activeDeviceID: agentStatus.active_device_id ?? runtimeStatus?.active_device_id,
                devices: agentStatus.devices ?? runtimeStatus?.devices,
                summary: agentStatus.summary ?? runtimeStatus?.summary,
                deviceSummary: agentStatus.device_summary ?? runtimeStatus?.device_summary,
                updatedAt: agentStatus.updated_at
            )
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
            if shouldIgnoreStaleConnectedAgentStatus(agentStatus) {
                return
            }
            let runtimeStatus = mergedRuntimeStatus(from: agentStatus) ?? agentStatus.runtime_status
            let nextBoard = runtimeStatus?.board ?? ToolkitStatus.Board(ping: false, ssh_port_open: false, control_service: false)
            let merged = mergedStatus(
                board: nextBoard,
                device: runtimeStatus?.device,
                deviceID: agentStatus.device_id ?? runtimeStatus?.device_id,
                activeDeviceID: agentStatus.active_device_id ?? runtimeStatus?.active_device_id,
                devices: agentStatus.devices ?? runtimeStatus?.devices,
                summary: agentStatus.summary ?? runtimeStatus?.summary,
                deviceSummary: agentStatus.device_summary ?? runtimeStatus?.device_summary,
                updatedAt: agentStatus.updated_at
            )
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
            if shouldIgnoreStaleConnectedAgentStatus(agentStatus) {
                return
            }
            let runtimeStatus = mergedRuntimeStatus(from: agentStatus) ?? agentStatus.runtime_status
            let merged = mergedStatus(
                host: runtimeStatus?.host,
                device: runtimeStatus?.device,
                deviceID: agentStatus.device_id ?? runtimeStatus?.device_id,
                activeDeviceID: agentStatus.active_device_id ?? runtimeStatus?.active_device_id,
                devices: agentStatus.devices ?? runtimeStatus?.devices,
                summary: agentStatus.summary ?? runtimeStatus?.summary,
                deviceSummary: agentStatus.device_summary ?? runtimeStatus?.device_summary,
                updatedAt: agentStatus.updated_at
            )
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

    func appendActivity(level: ActivityLevel, title: String, message: String, detail: String? = nil, updateSummary: Bool = true) {
        let now = Date()
        let dedupeWindow = activityDedupeWindow(level: level, title: title, updateSummary: updateSummary)
        if dedupeWindow > 0 {
            let fingerprint = activityFingerprint(level: level, title: title, message: message, detail: detail)
            if let lastAt = recentActivityFingerprintAt[fingerprint],
               now.timeIntervalSince(lastAt) < dedupeWindow {
                if updateSummary {
                    lastActionSummary = "\(title): \(message)"
                }
                return
            }
            recentActivityFingerprintAt[fingerprint] = now
            recentActivityFingerprintAt = recentActivityFingerprintAt.filter { now.timeIntervalSince($0.value) < 600 }
        }

        let entry = ActivityEntry(level: level, title: title, message: message, detail: detail)
        activities.insert(entry, at: 0)
        if activities.count > 50 {
            activities.removeLast(activities.count - 50)
        }
        if updateSummary {
            lastActionSummary = "\(title): \(message)"
        }
    }

    private func activityDedupeWindow(level: ActivityLevel, title: String, updateSummary: Bool) -> TimeInterval {
        if title == "状态探测" {
            return 120
        }
        if !updateSummary, (level == .warning || level == .error) {
            return 60
        }
        return 0
    }

    private func activityFingerprint(level: ActivityLevel, title: String, message: String, detail: String?) -> String {
        "\(level.rawValue)\n\(title)\n\(message)\n\(detail ?? "")"
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

    func copyDeviceIPAddress() {
        guard let boardIP = currentBoardUSBIP() else {
            appendActivity(level: .warning, title: "设备 IP", message: "当前没有可复制的设备地址")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(boardIP, forType: .string)
        appendActivity(level: .success, title: "设备 IP", message: "IP 地址已复制", detail: boardIP)
    }

    func promptOpenSSHTerminal() {
        guard status?.board?.ssh_port_open == true else {
            appendActivity(level: .warning, title: "SSH", message: "当前 SSH 尚未恢复")
            return
        }
        guard let boardIP = currentBoardUSBIP() else {
            appendActivity(level: .warning, title: "SSH", message: "当前没有可用的开发板 IP")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = ""
        alert.informativeText = ""
        alert.icon = nil
        let accessory = NSHostingView(rootView: SSHConnectionPromptAccessoryView(boardIP: boardIP))
        accessory.frame = NSRect(x: 0, y: 0, width: 320, height: 108)
        alert.accessoryView = accessory
        alert.addButton(withTitle: "打开")
        alert.addButton(withTitle: "取消")
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            NSApp.activate(ignoringOtherApps: true)
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.openSSHTerminal(boardIP: boardIP)
            }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSSHTerminal(boardIP: boardIP)
        }
    }

    private func boardSSHKnownHostsURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".ssh", isDirectory: true)
            .appendingPathComponent("development-board-toolchain_known_hosts", isDirectory: false)
    }

    private func prepareBoardSSHKnownHosts(for boardIP: String) throws -> URL {
        let fileManager = FileManager.default
        let knownHostsURL = boardSSHKnownHostsURL()
        let parentURL = knownHostsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: knownHostsURL.path) {
            fileManager.createFile(atPath: knownHostsURL.path, contents: Data())
        }

        // Board images are reflashed frequently, so stale host keys at the USB ECM IP are expected.
        for host in [boardIP, "[\(boardIP)]:22"] {
            do {
                _ = try ProcessExecutor.runSync(
                    executableURL: URL(fileURLWithPath: "/usr/bin/ssh-keygen"),
                    arguments: ["-R", host, "-f", knownHostsURL.path],
                    currentDirectoryURL: appSupportRootURL(),
                    environment: ProcessInfo.processInfo.environment
                )
            } catch {
                // Best effort only. The follow-up SSH command still uses the GUI-owned known_hosts file.
            }
        }

        return knownHostsURL
    }

    private func sshTerminalCommand(boardIP: String, knownHostsURL: URL) -> String {
        [
            "/usr/bin/ssh",
            "-o", "UserKnownHostsFile=\(knownHostsURL.path)",
            "-o", "GlobalKnownHostsFile=/dev/null",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "WarnWeakCrypto=no",
            "-o", "LogLevel=ERROR",
            "root@\(boardIP)"
        ]
        .map(shellQuotedArgument)
        .joined(separator: " ")
    }

    private func openSSHTerminal(boardIP: String) {
        let knownHostsURL: URL
        do {
            knownHostsURL = try prepareBoardSSHKnownHosts(for: boardIP)
        } catch {
            presentInlineError("准备 SSH 主机密钥缓存失败: \(error.localizedDescription)")
            appendActivity(level: .error, title: "SSH", message: "准备 SSH 主机密钥缓存失败", detail: error.localizedDescription)
            return
        }
        let command = sshTerminalCommand(boardIP: boardIP, knownHostsURL: knownHostsURL)
        let script = """
        tell application "Terminal"
            reopen
            activate
            do script \(appleScriptStringLiteral(command))
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            popoverCloseRequestID = UUID()
            appendActivity(level: .success, title: "SSH", message: "已打开终端连接", detail: "ssh root@\(boardIP)（已自动刷新板卡 SSH host key）")
        } catch {
            presentInlineError("打开终端失败: \(error.localizedDescription)")
            appendActivity(level: .error, title: "SSH", message: "打开终端失败", detail: error.localizedDescription)
        }
    }

    private func pollTaskInBackground(
        _ taskID: String,
        title: String,
        timeout: TimeInterval? = nil,
        timeoutMessage: String? = nil,
        recoverOwnedAgentOnTimeout: Bool = false
    ) {
        backgroundTaskPolls[taskID]?.cancel()
        backgroundTaskPolls[taskID] = Task { [weak self] in
            guard let self else {
                return
            }
            let startedAt = Date()
            defer {
                Task { @MainActor [weak self] in
                    self?.backgroundTaskPolls.removeValue(forKey: taskID)
                }
            }
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                do {
                    let task = try await fetchLocalAgentTask(taskID)
                    if task.status == "finished" {
                        clearActiveBackgroundFlashTaskIfMatches(taskID)
                        if task.ok == true {
                            appendActivity(level: .success, title: title, message: "任务已完成", detail: task.output_tail)
                            sendUserNotification(title: title, message: "任务已完成")
                            if isFlashLikeAction(task.action) {
                                clearPostFlashRecovery()
                            }
                        } else {
                            let detail = task.output_tail ?? "任务执行失败"
                            presentInlineError(detail)
                            appendActivity(level: .error, title: title, message: "执行失败", detail: detail)
                            sendUserNotification(title: title, message: "执行失败")
                        }
                        await refreshTransportStatus(silent: true)
                        await refreshBoardStatus(silent: true)
                        return
                    }
                    if let timeout,
                       elapsed > timeout {
                        clearActiveBackgroundFlashTaskIfMatches(taskID)
                        let detail = timeoutMessage ?? "\(title)后台等待超时，请检查设备连接状态后重试。"
                        presentInlineError(detail)
                        appendActivity(level: .error, title: title, message: "后台等待超时", detail: detail)
                        sendUserNotification(title: title, message: "后台等待超时")
                        if recoverOwnedAgentOnTimeout {
                            await recoverOwnedLocalAgentAfterHungTask(title: title, taskID: taskID)
                        }
                        return
                    }
                } catch {
                    clearActiveBackgroundFlashTaskIfMatches(taskID)
                    presentInlineError(error.localizedDescription)
                    appendActivity(level: .error, title: title, message: "后台轮询失败", detail: error.localizedDescription)
                    return
                }
                try? await Task.sleep(for: taskPollingInterval(elapsed: elapsed))
            }
        }
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
        if activeBackgroundFlashTaskID?.isEmpty == false {
            return true
        }
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
        return isFlashLikeAction(task.action)
    }

    private func isFlashLikeAction(_ action: String?) -> Bool {
        let flashLikeActions = Set([
            "flash",
            "dev-build-sync-flash",
            "release-update-logo-flash",
            "release-update-dtb-flash"
        ])
        return flashLikeActions.contains(action ?? "")
    }

    private func isTaishanBoardContext() -> Bool {
        let route = currentOperationRoute()
        return route.boardID == "TaishanPi" ||
            status?.device?.board_id == "TaishanPi" ||
            connectedBoardID == "TaishanPi"
    }

    private func isTaishanLoaderModeContext() -> Bool {
        guard isTaishanBoardContext() else {
            return false
        }
        let mode = (status?.usb?.mode ?? "").lowercased()
        let transport = (status?.device?.transport_name ?? "").lowercased()
        let product = (status?.usb?.product ?? "").lowercased()
        return mode == "loader" ||
            mode == "maskrom" ||
            transport.contains("loader") ||
            transport.contains("maskrom") ||
            product.contains("download gadget")
    }

    private func flashForegroundDetachInterval(for task: ToolkitTask) -> TimeInterval? {
        guard (task.action ?? "") == "flash", isTaishanBoardContext() else {
            return nil
        }
        // TaishanPi full-image flashing can spend several minutes writing and then waiting
        // for USB ECM to re-enumerate. Keep the foreground progress visible so users do
        // not lose feedback during the most failure-prone part of the workflow.
        return nil
    }

    private func clearActiveBackgroundFlashTaskIfMatches(_ taskID: String) {
        guard activeBackgroundFlashTaskID == taskID else {
            return
        }
        activeBackgroundFlashTaskID = nil
        activeBackgroundFlashTitle = ""
    }

    func pollTask(_ taskID: String) {
        taskPollTask?.cancel()
        backgroundTaskPolls[taskID]?.cancel()
        backgroundTaskPolls[taskID] = nil
        taskPollTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard taskID.hasPrefix("agent_job_") else {
                presentInlineError("旧任务轮询接口已弃用，请重新执行当前操作。")
                return
            }
            let startedAt = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                do {
                    let task = try await fetchLocalAgentTask(taskID)
                    if let timeout = taskTimeoutInterval(task),
                       elapsed > timeout,
                       task.status != "finished" {
                        pendingTaskTitle = ""
                        currentTask = nil
                        clearActiveBackgroundFlashTaskIfMatches(taskID)
                        if task.action == "rp2350_enter_bootsel" || task.action == "rp2350_run" {
                            rp2350ModeTransitionUntil = Date().addingTimeInterval(5)
                            let message = "\(taskActionDisplayName(task))仍在后台确认状态，界面先继续可用。"
                            appendActivity(level: .info, title: taskActionDisplayName(task), message: "后台继续确认", detail: message)
                            sendUserNotification(title: taskActionDisplayName(task), message: "仍在后台确认状态")
                            startBackgroundTaskPoll(taskID, actionName: taskActionDisplayName(task))
                        } else {
                            let message = "\(taskActionDisplayName(task))超时，请检查设备连接状态后重试。"
                            presentInlineError(message)
                            appendActivity(level: .error, title: taskActionDisplayName(task), message: "执行超时", detail: message)
                        }
                        return
                    }
                    if let detachInterval = flashForegroundDetachInterval(for: task),
                       elapsed > detachInterval,
                       task.status != "finished" {
                        detachLongRunningFlashTaskToBackground(taskID: taskID, task: task, elapsed: elapsed)
                        return
                    }
                    handleTaskUpdate(task)
                    if task.status == "finished" {
                        return
                    }
                } catch {
                    presentInlineError(error.localizedDescription)
                    return
                }
                try? await Task.sleep(for: taskPollingInterval(elapsed: elapsed))
            }
        }
    }

    private func startBackgroundTaskPoll(_ taskID: String, actionName: String) {
        backgroundTaskPolls[taskID]?.cancel()
        backgroundTaskPolls[taskID] = Task { [weak self] in
            guard let self else { return }
            defer { self.backgroundTaskPolls[taskID] = nil }
            let startedAt = Date()
            let deadline = Date().addingTimeInterval(25)
            while !Task.isCancelled, Date() < deadline {
                let elapsed = Date().timeIntervalSince(startedAt)
                do {
                    let task = try await fetchLocalAgentTask(taskID)
                    if task.status == "finished" {
                        handleTaskUpdate(task)
                        return
                    }
                } catch {
                    return
                }
                try? await Task.sleep(for: taskPollingInterval(elapsed: elapsed))
            }
            sendUserNotification(title: actionName, message: "后台确认超时，请手动检查设备状态")
        }
    }

    private func taskPollingInterval(elapsed: TimeInterval) -> Duration {
        if elapsed < 2 {
            return .milliseconds(250)
        }
        if elapsed < 6 {
            return .milliseconds(500)
        }
        return .seconds(1)
    }

    private func detachLongRunningFlashTaskToBackground(taskID: String, task: ToolkitTask, elapsed: TimeInterval) {
        let title = taskActionDisplayName(task)
        let hardTimeout = taskTimeoutInterval(task) ?? 1_200
        let remainingTimeout = max(60, hardTimeout - elapsed)
        pendingTaskTitle = ""
        currentTask = nil
        activeBackgroundFlashTaskID = taskID
        activeBackgroundFlashTitle = title
        let modeText = isTaishanLoaderModeContext() ? "下载模式直刷" : "刷写"
        let message = "\(modeText)任务仍在执行，界面已切换为后台等待。请不要重复点击刷写或断开 USB。"
        appendActivity(level: .warning, title: title, message: "已转入后台等待", detail: message)
        sendUserNotification(title: title, message: "已转入后台等待")
        pollTaskInBackground(
            taskID,
            title: title,
            timeout: remainingTimeout,
            timeoutMessage: "\(title)后台等待超时。本地刷写进程没有按预期结束，请重新插拔开发板并重新进入 Loader 后再重试。",
            recoverOwnedAgentOnTimeout: true
        )
    }

    private func recoverOwnedLocalAgentAfterHungTask(title: String, taskID: String) async {
        guard let pid = ownedLocalAgentPID else {
            appendActivity(
                level: .warning,
                title: "本地 DBT Agent",
                message: "未自动清理非 GUI 本轮启动的服务进程",
                detail: "\(title) \(taskID)"
            )
            return
        }
        guard readLocalAgentPID() == pid,
              await isGUIManagedLocalAgentServiceProcess(pid: pid)
        else {
            appendActivity(
                level: .warning,
                title: "本地 DBT Agent",
                message: "当前服务进程不属于 GUI 管理范围，未自动清理",
                detail: "\(title) \(taskID)"
            )
            return
        }
        appendActivity(
            level: .warning,
            title: "本地 DBT Agent",
            message: "正在清理超时的 GUI 服务进程",
            detail: "\(title) \(taskID)"
        )
        stopOwnedLocalAgentIfNeeded()
        setLocalAgentRunning(false)
        await ensureLocalAgentStartedIfNeeded()
    }

    private func taskTimeoutInterval(_ task: ToolkitTask) -> TimeInterval? {
        switch task.action {
        case "flash":
            return 1_200
        case "dev-build-sync-flash":
            return 1_800
        case "release-update-logo-flash", "release-update-dtb-flash":
            return 900
        case "rp2350_enter_bootsel":
            return 10
        case "rp2350_run":
            return 10
        case "rp2350_flash", "rp2350_verify", "rp2350_save_flash":
            return 45
        default:
            return nil
        }
    }

    private func taskActionDisplayName(_ task: ToolkitTask) -> String {
        switch task.action {
        case "flash":
            return "镜像刷写"
        case "reboot-device":
            return "设备重启"
        case "reboot-loader":
            return "切换 Loader"
        case "dev-build-sync-flash":
            return "开发版构建并刷写"
        case "release-update-logo-flash":
            return "启动 Logo 刷写"
        case "release-update-dtb-flash":
            return "设备树刷写"
        case "rp2350_enter_bootsel":
            return "进入 BOOTSEL"
        case "rp2350_flash":
            return "UF2 刷写"
        case "rp2350_verify":
            return "UF2 校验"
        case "rp2350_save_flash":
            return "Flash 回读"
        case "rp2350_run":
            return "恢复运行态"
        default:
            return pendingTaskTitle.isEmpty ? "任务" : pendingTaskTitle
        }
    }

    func sendUserNotification(title: String, message: String) {
        let now = Date()
        let fingerprint = "\(title)\n\(message)"
        if let lastAt = recentUserNotificationAt[fingerprint],
           now.timeIntervalSince(lastAt) < 60 {
            return
        }
        recentUserNotificationAt[fingerprint] = now
        recentUserNotificationAt = recentUserNotificationAt.filter { now.timeIntervalSince($0.value) < 600 }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "dbt-agent-\(fingerprint.hashValue)",
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
            if task.action == "rp2350_enter_bootsel" || task.action == "rp2350_run" {
                rp2350ModeTransitionUntil = Date().addingTimeInterval(3)
            }
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
        refreshStatus(silent: true, force: true)
        scheduleFollowUpStatusRefreshes(for: task)
        Task {
            await refreshDevelopmentInstallStatus()
        }
        refreshToolkitUpdateStatus()
    }

    private func scheduleFollowUpStatusRefreshes(for task: ToolkitTask) {
        guard task.ok == true else {
            return
        }
        let action = task.action ?? ""
        guard action == "rp2350_enter_bootsel" ||
            action == "rp2350_run" ||
            action == "rp2350_flash" ||
            action == "rp2350_detect"
        else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(700))
            self.refreshStatus(silent: true, force: true)
            try? await Task.sleep(for: .milliseconds(900))
            self.refreshStatus(silent: true, force: true)
        }
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
        clearPostFlashRecovery()
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
        if let progress = normalizedTaskProgress(task.progress) {
            return progress
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
        let metadata = taskMetadataSummary(for: task)
        if let output = task.output_tail, !output.isEmpty {
            let compact = compactTaskOutput(
                output,
                action: task.action ?? "",
                isFinished: task.status == "finished",
                isSuccess: task.ok == true
            )
            let mergedProgress = metadata.progress ?? (compact.progress.isEmpty ? nil : compact.progress)
            let mergedLines = mergeTaskSummaryLines(metadata.lines, compact.lines)
            if let mergedProgress, !mergedProgress.isEmpty || !mergedLines.isEmpty {
                return (mergedProgress, mergedLines)
            }
            if !mergedLines.isEmpty {
                return ("正在等待任务状态更新…", mergedLines)
            }
        }
        if let logPath = task.log_path, !logPath.isEmpty {
            var lines = metadata.lines
            appendUniqueTaskSummaryLine("日志文件: \(logPath)", to: &lines)
            return (metadata.progress ?? "正在初始化日志流…", lines)
        }
        if let progress = metadata.progress {
            return (progress, metadata.lines)
        }
        if !metadata.lines.isEmpty {
            return ("正在等待任务状态更新…", metadata.lines)
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
                if isFlashLikeAction(task.action) {
                    if let progressText = taskMetadataText(task.progress_text) {
                        return progressText
                    }
                    return "刷写完成，已下发设备重启"
                }
                return "执行完成"
            }
            return "执行失败"
        }
        if let status = taskMetadataText(task.status_label) {
            return status
        }
        return ""
    }

    private func normalizedTaskProgress(_ progress: Double?) -> Double? {
        guard let progress, progress > 0 else {
            return nil
        }
        return min(max(progress, 0), 1)
    }

    private func taskMetadataSummary(for task: ToolkitTask) -> (progress: String?, lines: [String]) {
        let progress = taskMetadataText(task.progress_text) ?? taskMetadataText(task.status_label)
        var lines: [String] = []
        if let status = taskMetadataText(task.status_label), status != progress {
            lines.append(status)
        }
        if let stage = taskMetadataText(task.progress_stage), stage != progress, !lines.contains(stage) {
            lines.append(stage)
        }
        return (progress, lines)
    }

    private func mergeTaskSummaryLines(_ lhs: [String], _ rhs: [String]) -> [String] {
        var merged = lhs
        for line in rhs {
            appendUniqueTaskSummaryLine(line, to: &merged)
        }
        return merged
    }

    private func appendUniqueTaskSummaryLine(_ line: String?, to lines: inout [String]) {
        guard let line = taskMetadataText(line), !lines.contains(line) else {
            return
        }
        lines.append(line)
    }

    private func taskMetadataText(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if isFlashLikeAction(action) && isFinished && isSuccess {
            progress = "刷写完成，已下发设备重启"
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
        let connectedDevices = connectedDeviceRecords(from: status)
        return StatusSnapshot(
            usbMode: status.usb?.mode ?? "-",
            usbProduct: status.usb?.product ?? "-",
            usbPid: status.usb?.pid ?? "-",
            usbIface: status.usbnet?.iface ?? "-",
            hostIP: status.usbnet?.current_ip ?? "-",
            usbConfigured: status.usbnet?.configured ?? false,
            ping: status.board?.ping ?? false,
            ssh: status.board?.ssh_port_open ?? false,
            controlService: status.board?.control_service ?? false,
            activeDeviceID: status.active_device_id ?? status.device_id ?? "-",
            activeBoardID: status.device?.board_id ?? "-",
            connectedDeviceCount: connectedDevices.count,
            connectedDeviceSignature: connectedDevices
                .map { connectedDeviceSignatureComponent(for: $0) }
                .sorted()
                .joined(separator: "|"),
            rp2350State: status.rp2350?.state ?? "-",
            rp2350Connected: status.rp2350?.connected ?? false,
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
        if old.connectedDeviceCount != new.connectedDeviceCount {
            changes.append((.info, "设备数量变化", "\(old.connectedDeviceCount) -> \(new.connectedDeviceCount)"))
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
            refreshStatus(silent: true, force: true)
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
            updateBoardRoutingFromCurrentState()
            scheduleRP2350MonitorProbeIfNeeded()
            lastRefreshErrorSignature = ""
            return
        }
        status = stableStatus
        lastSnapshot = newSnapshot
        if newSnapshot.usbMode == "usb-ecm" && newSnapshot.usbConfigured &&
            newSnapshot.ping && newSnapshot.ssh {
            boardStateGraceUntil = nil
        }
        if rp2350UF2Path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configureRP2350Defaults()
        }
        updateBoardRoutingFromCurrentState()
        scheduleRP2350MonitorProbeIfNeeded()
        lastRefreshErrorSignature = ""
    }

    private func statusIsTaishanLoaderMode(_ status: ToolkitStatus) -> Bool {
        let usbMode = (status.usb?.mode ?? "").lowercased()
        let transport = (status.device?.transport_name ?? "").lowercased()
        let product = (status.usb?.product ?? "").lowercased()
        return usbMode == "loader" ||
            usbMode == "maskrom" ||
            transport.contains("loader") ||
            transport.contains("maskrom") ||
            product.contains("download gadget")
    }

    private func statusLooksTaishanOrTransitionCandidate(_ status: ToolkitStatus) -> Bool {
        boardLogicFamily(status: status) == .taishanPi ||
            boardLogicFamily(status: self.status) == .taishanPi ||
            currentOperationRoute().boardID == "TaishanPi" ||
            connectedBoardID == "TaishanPi" ||
            preferredControlBoardID == "TaishanPi"
    }

    private func taishanLoaderTransitionStatus(from newStatus: ToolkitStatus) -> ToolkitStatus {
        let current = self.status
        let device = current?.device ?? newStatus.device
        let devices = (current?.devices?.isEmpty == false) ? current?.devices : newStatus.devices
        let message = taishanLoaderTransitionHint
        let repoRoot = newStatus.repo_root ?? current?.repo_root
        let service = newStatus.service ?? current?.service
        let usbProduct = newStatus.usb?.product ?? current?.usb?.product
        let usbPID = newStatus.usb?.pid ?? current?.usb?.pid
        let usbnet = ToolkitStatus.USBNet(
            iface: newStatus.usbnet?.iface ?? current?.usbnet?.iface,
            current_ip: newStatus.usbnet?.current_ip ?? current?.usbnet?.current_ip,
            expected_ip: newStatus.usbnet?.expected_ip ?? current?.usbnet?.expected_ip,
            board_ip: newStatus.usbnet?.board_ip ?? current?.usbnet?.board_ip,
            slot: newStatus.usbnet?.slot ?? current?.usbnet?.slot,
            configured: false
        )
        let deviceID = current?.device_id ?? newStatus.device_id
        let activeDeviceID = current?.active_device_id ?? newStatus.active_device_id
        return ToolkitStatus(
            repo_root: repoRoot,
            service: service,
            updated_at: newStatus.updated_at,
            usb: .init(
                mode: "detecting",
                product: usbProduct,
                pid: usbPID
            ),
            usbnet: usbnet,
            board: .init(
                ping: false,
                ssh_port_open: false,
                control_service: false
            ),
            host: newStatus.host ?? current?.host,
            device: device,
            device_id: deviceID,
            active_device_id: activeDeviceID,
            devices: devices,
            rp2350: nil,
            summary: message,
            device_summary: message
        )
    }

    private func markTaishanLoaderTransitionStarted(duration: TimeInterval = 36) {
        taishanLoaderTransitionUntil = Date().addingTimeInterval(duration)
        if let current = status {
            let transitioning = taishanLoaderTransitionStatus(from: current)
            status = transitioning
            lastSnapshot = makeSnapshot(from: transitioning)
        }
    }

    private func clearTaishanLoaderTransition() {
        taishanLoaderTransitionUntil = nil
    }

    private func waitForPendingTaskVisibleSince(_ startedAt: Date, minimumDuration: TimeInterval = 1.2) async {
        let remaining = minimumDuration - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else {
            return
        }
        try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
    }

    func stabilizedStatus(from status: ToolkitStatus) -> ToolkitStatus {
        if taishanLoaderTransitionActive, statusLooksTaishanOrTransitionCandidate(status) {
            if statusIsTaishanLoaderMode(status) {
                clearTaishanLoaderTransition()
                return status
            }
            return taishanLoaderTransitionStatus(from: status)
        }

        switch boardLogicFamily(status: status) {
        case .taishanPi, .colorEasyPICO2:
            return status
        case .generic:
            break
        }

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
            device_id: status.device_id,
            active_device_id: status.active_device_id,
            devices: status.devices,
            rp2350: status.rp2350,
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
            refreshStatus(silent: true, force: true)
            await refreshDevelopmentInstallStatus()
        }
    }

    func handleSystemEvent(_ reason: String) {
        if isFlashTaskRunning {
            return
        }
        if reason == "usb-removed" {
            lastLocalUSBRemovedAt = Date()
            if taishanLoaderTransitionActive {
                boardStateGraceUntil = Date().addingTimeInterval(8)
                applyTransientUSBStateIfNeeded()
            } else {
                boardStateGraceUntil = nil
                stopBoardMonitoring()
                resetAutomaticUSBNetRepairState(cancelTask: true)
                if onlineConnectedDeviceCount <= 1 {
                    suppressConnectedAgentStatusUntil = Date().addingTimeInterval(4.5)
                    applyDisconnectedUSBState()
                }
            }
        } else if reason == "usb-added" {
            lastLocalUSBRemovedAt = nil
            suppressConnectedAgentStatusUntil = nil
            let liveBoardID = currentLiveCandidate?.boardID ?? status?.device?.board_id
            if taishanLoaderTransitionActive {
                boardStateGraceUntil = Date().addingTimeInterval(8)
                applyTransientUSBStateIfNeeded()
            } else if isRP2350BoardID(liveBoardID) {
                boardStateGraceUntil = nil
            } else {
                boardStateGraceUntil = Date().addingTimeInterval(8)
                applyTransientUSBStateIfNeeded()
            }
        } else if reason == "network", status?.usb?.mode == "usb-ecm" {
            if taishanLoaderTransitionActive {
                boardStateGraceUntil = Date().addingTimeInterval(5)
                applyTransientUSBStateIfNeeded()
            } else if onlineConnectedDeviceCount <= 1, currentUSBECMInterfaceMissing() {
                lastLocalUSBRemovedAt = Date()
                suppressConnectedAgentStatusUntil = Date().addingTimeInterval(4.5)
                boardStateGraceUntil = nil
                stopBoardMonitoring()
                resetAutomaticUSBNetRepairState(cancelTask: true)
                applyDisconnectedUSBState()
            } else {
                boardStateGraceUntil = Date().addingTimeInterval(5)
            }
        }
        pendingSystemRefreshTask?.cancel()
        pendingSystemRefreshTask = Task { [weak self] in
            let delay = reason.hasPrefix("usb") ? Duration.milliseconds(40) : Duration.milliseconds(120)
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else {
                return
            }
            self.refreshStatus(silent: true, force: true)
        }
    }

    func startLocalAgentMonitor() {
        localAgentMonitorTask?.cancel()
        localAgentMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isFlashTaskRunning, self.statusRefreshTask == nil {
                    self.refreshStatus(silent: true)
                }
                try? await Task.sleep(for: .seconds(self.localAgentMonitorInterval()))
            }
        }
    }

    private func localAgentMonitorInterval() -> TimeInterval {
        if isFlashTaskRunning {
            return 4
        }
        if !localAgentRunning || status == nil {
            return 3
        }
        if !pendingTaskTitle.isEmpty {
            return 3
        }
        if let currentTask, currentTask.status != "finished" {
            return 3
        }
        return 12
    }

    private func shouldThrottleStatusRefresh(silent: Bool, force: Bool) -> Bool {
        guard silent, !force, let lastStatusRefreshStartedAt else {
            return false
        }
        let minimumInterval: TimeInterval = (localAgentRunning && status != nil) ? 2.5 : 1.0
        return Date().timeIntervalSince(lastStatusRefreshStartedAt) < minimumInterval
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
                slot: current.usbnet?.slot,
                configured: false
            ),
            board: .init(
                ping: false,
                ssh_port_open: false,
                control_service: false
            ),
            host: current.host,
            device: current.device,
            device_id: current.device_id,
            active_device_id: current.active_device_id,
            devices: current.devices,
            rp2350: current.rp2350,
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
                slot: current.usbnet?.slot,
                configured: false
            ),
            board: .init(
                ping: false,
                ssh_port_open: false,
                control_service: false
            ),
            host: current.host,
            device: nil,
            device_id: nil,
            active_device_id: nil,
            devices: [],
            rp2350: nil,
            summary: "没有开发板设备连接",
            device_summary: "没有开发板设备连接"
        )
        status = disconnected
        lastSnapshot = makeSnapshot(from: disconnected)
    }

    private func shouldIgnoreStaleConnectedAgentStatus(_ agentStatus: AgentStatusSummaryResponse) -> Bool {
        if agentStatus.connected_device != true {
            lastLocalUSBRemovedAt = nil
            suppressConnectedAgentStatusUntil = nil
            return false
        }
        guard let suppressionUntil = suppressConnectedAgentStatusUntil else {
            return false
        }
        if Date() < suppressionUntil {
            return true
        }
        suppressConnectedAgentStatusUntil = nil
        lastLocalUSBRemovedAt = nil
        return false
    }

    private func currentUSBECMInterfaceMissing() -> Bool {
        guard let status,
              (status.usb?.mode ?? "").lowercased() == "usb-ecm",
              let iface = status.usbnet?.iface,
              !iface.isEmpty
        else {
            return false
        }
        return if_nametoindex(iface) == 0
    }

    private func connectedDeviceRecords(from status: ToolkitStatus) -> [ToolkitStatus.Device] {
        if let devices = status.devices, !devices.isEmpty {
            return devices.filter { $0.connected == true }
        }
        if let device = status.device, device.connected == true {
            return [device]
        }
        return []
    }

    private func connectedDeviceSignatureComponent(for device: ToolkitStatus.Device) -> String {
        if let deviceID = device.device_id, !deviceID.isEmpty {
            return deviceID
        }
        let boardID = device.board_id ?? "unknown"
        let locator = device.transport_locator ?? device.interface_name ?? device.display_label ?? boardID
        return "\(boardID)::\(locator)"
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

    func refreshStatus(silent: Bool = false, force: Bool = false) {
        if isFlashTaskRunning {
            return
        }
        if busy && !silent {
            return
        }
        let forceRefresh = force || !silent
        if shouldThrottleStatusRefresh(silent: silent, force: forceRefresh) {
            return
        }
        if statusRefreshTask != nil {
            if forceRefresh {
                queuedStatusRefreshPending = true
                queuedStatusRefreshSilent = queuedStatusRefreshSilent && silent
                queuedStatusRefreshForce = true
            }
            return
        }
        if !silent {
            busy = true
        }
        lastStatusRefreshStartedAt = Date()
        statusRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                let shouldReplay = self.queuedStatusRefreshPending
                let replaySilent = self.queuedStatusRefreshSilent
                let replayForce = self.queuedStatusRefreshForce
                self.queuedStatusRefreshPending = false
                self.queuedStatusRefreshSilent = true
                self.queuedStatusRefreshForce = false
                self.statusRefreshTask = nil
                if !silent {
                    self.busy = false
                }
                if shouldReplay {
                    self.refreshStatus(silent: replaySilent, force: replayForce)
                }
            }
            await ensureLocalAgentStartedIfNeeded()
            var localAgentApplied = false
            var statusFetchError: Error?
            do {
                let agentStatus = try await fetchLocalAgentStatusSummary()
                if !self.shouldIgnoreStaleConnectedAgentStatus(agentStatus) {
                    self.applyLocalAgentStatusSummary(agentStatus, silent: true)
                    localAgentApplied = true
                }
            } catch {
                statusFetchError = error
                if (try? await self.fetchLocalAgentHealthz()) != nil {
                    self.setLocalAgentRunning(true)
                } else {
                    self.setLocalAgentRunning(false)
                }
            }
            if !localAgentApplied {
                let message = self.localAgentRunning
                    ? "本地 DBT Agent 在线，但状态刷新暂时超时，本次保留当前页面状态。"
                    : "后台状态探测失败，本次保留当前页面状态。"
                if self.status == nil {
                    let fallbackMessage = self.localAgentRunning
                        ? "本地 DBT Agent 在线，正在刷新开发板状态"
                        : self.localAgentUnavailableUserMessage()
                    let fallbackStatus = self.mergedStatus(
                        summary: fallbackMessage,
                        deviceSummary: fallbackMessage,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    self.applyStatusUpdate(fallbackStatus, silent: true)
                } else {
                    self.notifyBackgroundStatusFailureIfNeeded(message)
                    self.appendActivity(level: .warning, title: "状态探测", message: message, detail: statusFetchError?.localizedDescription, updateSummary: false)
                }
            }
        }
    }

    private func notifyBackgroundStatusFailureIfNeeded(_ message: String) {
        let now = Date()
        if lastBackgroundStatusNotificationMessage == message,
           let lastAt = lastBackgroundStatusNotificationAt,
           now.timeIntervalSince(lastAt) < 60 {
            return
        }
        lastBackgroundStatusNotificationMessage = message
        lastBackgroundStatusNotificationAt = now
        sendUserNotification(title: AppStrings.productName, message: message)
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
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = title
                let routedLocalArgs = self.routedBoardArguments(for: localArgs)
                let args = routedLocalArgs
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
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
                let detail = response.task?.log_path ?? ""
                appendActivity(level: .success, title: title, message: successMessage, detail: detail)
                if let recoveryContext {
                    startPostFlashRecovery(recoveryContext)
                }
                if transitionTracking {
                    startTransitionWatch(reason: title, duration: 14, step: 1.0)
                }
                refreshStatus(silent: true, force: true)
            } catch {
                let detail = error.localizedDescription
                pendingTaskTitle = ""
                if title == "软件更新" || title == "初始镜像更新" {
                    updaterLastDetail = detail
                }
                presentInlineError(detail)
                appendActivity(level: .error, title: title, message: "执行失败", detail: detail)
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
        let route = currentOperationRoute()
        guard let boardID = route.boardID, !boardID.isEmpty else {
            return arguments
        }
        var routed = arguments
        if !arguments.contains("--board") {
            routed.append(contentsOf: ["--board", boardID])
        }
        if let variantID = route.variantID, !variantID.isEmpty, !arguments.contains("--variant") {
            routed.append(contentsOf: ["--variant", variantID])
        }
        if let deviceID = route.deviceID, !deviceID.isEmpty, !arguments.contains("--device-id") {
            routed.append(contentsOf: ["--device-id", deviceID])
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
            let title = "USB 网络"
            if let message = await validatePrecondition(.ensureUSBNet) {
                presentInlineError(message)
                appendActivity(level: .warning, title: title, message: message)
                return
            }
            busy = true
            pendingTaskTitle = title
            clearInlineError()
            appendActivity(level: .info, title: title, message: "正在尝试恢复主机 USB 网络")
            do {
                let task = try await runLocalAgentRuntimeJobAndWait(
                    actionID: "usbnet-ensure",
                    title: title,
                    arguments: ["usbnet", "ensure"],
                    timeout: 20
                )
                pendingTaskTitle = ""
                busy = false
                appendActivity(
                    level: .success,
                    title: title,
                    message: "主机 USB 网络已恢复",
                    detail: task.output_tail ?? task.log_path
                )
                startTransitionWatch(reason: "network", duration: 14, step: 1.0)
                refreshStatus(silent: true, force: true)
            } catch {
                pendingTaskTitle = ""
                busy = false
                let detail = error.localizedDescription
                if usbNetRecoveryNeedsPrivilegedHelper(detail) {
                    appendActivity(
                        level: .info,
                        title: title,
                        message: "恢复主机 USB 网络需要管理员授权，正在安装网络权限",
                        detail: detail
                    )
                    installUSBNetHelper()
                    return
                }
                presentInlineError(detail)
                appendActivity(level: .error, title: title, message: "恢复失败", detail: detail)
            }
        }
    }

    private func usbNetRecoveryNeedsPrivilegedHelper(_ detail: String) -> Bool {
        let normalized = detail.lowercased()
        return normalized.contains("requires root")
            || normalized.contains("privileged usb helper")
            || normalized.contains("run with sudo")
            || normalized.contains("a password is required")
            || normalized.contains("sudo")
    }

    func installUSBNetHelper() {
        Task {
            if let message = await validatePrecondition(.ensureUSBNet) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "网络权限安装", message: message)
                return
            }
            let targetUser = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !targetUser.isEmpty else {
                presentInlineError("无法确定当前登录用户，不能安装主机网络权限。")
                appendActivity(level: .error, title: "网络权限安装", message: "当前登录用户为空")
                return
            }
            busy = true
            clearInlineError()
            pendingTaskTitle = "网络权限安装"
            appendActivity(level: .info, title: "网络权限安装", message: "正在请求系统管理员授权")
            do {
                let detail = try await runPrivilegedRuntimeCommand(
                    arguments: ["usbnet-helper-install", "--user", targetUser, "--run", "ensure"]
                )
                pendingTaskTitle = ""
                busy = false
                appendActivity(
                    level: .success,
                    title: "网络权限安装",
                    message: "主机 USB 网络权限已安装",
                    detail: detail.isEmpty ? nil : detail
                )
                startTransitionWatch(reason: "网络权限安装", duration: 14, step: 1.0)
                sendUserNotification(title: "网络权限安装", message: "主机 USB 网络权限已安装")
                refreshStatus(silent: true, force: true)
            } catch {
                let detail = error.localizedDescription
                pendingTaskTitle = ""
                busy = false
                if detail == "已取消管理员授权。" {
                    appendActivity(level: .warning, title: "网络权限安装", message: detail)
                } else {
                    presentInlineError(detail)
                    appendActivity(level: .error, title: "网络权限安装", message: "执行失败", detail: detail)
                }
            }
        }
    }

    func checkDevelopmentEnvironment() {
        installerLastDetail = "准备检查发布环境..."
        runManagedAction(
            title: "发布环境检查",
            successMessage: "检查任务已提交",
            localArgs: ["release", "check-env"] + taishanPiBuildModeArguments(),
            asyncTask: true
        )
    }

    func installFullDevelopmentEnvironment() {
        installerLastDetail = "准备开始全量安装..."
        runManagedAction(
            title: "发布环境全量安装",
            successMessage: "全量安装任务已提交",
            localArgs: ["release", "install-environment"] + taishanPiBuildModeArguments(),
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
            localArgs: ["release", "install-environment", "--artifacts-dir", trimmed] + taishanPiBuildModeArguments(),
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
                let task = try await runWithTimeout(
                    seconds: 50,
                    failureMessage: "检查更新超时（50 秒），请检查网络连接或稍后重试。"
                ) {
                    try await self.runLocalAgentRuntimeJobAndWait(
                        actionID: "release-check-update",
                        title: "检查软件更新",
                        arguments: ["release", "check-update"],
                        environmentOverrides: self.toolkitUpdateEnvironmentOverrides(),
                        timeout: 45
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
                let task = try await self.runWithTimeout(
                    seconds: 50,
                    failureMessage: "检查更新超时（50 秒），请检查网络连接或稍后重试。"
                ) {
                    try await self.runLocalAgentRuntimeJobAndWait(
                        actionID: "release-check-update",
                        title: "检查软件更新",
                        arguments: ["release", "check-update"],
                        environmentOverrides: self.toolkitUpdateEnvironmentOverrides(),
                        timeout: 45
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
            asyncTask: true,
            environmentOverrides: toolkitUpdateEnvironmentOverrides()
        )
    }

    func performToolkitUpdate() {
        if toolkitUpdateStatus.updateAvailable {
            shouldRelaunchAfterToolkitUpdate = true
            installToolkitUpdate()
        } else {
            checkToolkitUpdate()
        }
    }

    func updateInitialImages() {
        updaterLastDetail = "准备下载并更新初始镜像..."
        runManagedAction(
            title: "初始镜像更新",
            successMessage: "初始镜像更新任务已提交",
            localArgs: ["release", "update-images"] + taishanPiBuildModeArguments(),
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
            localArgs: ["release", "build-image"] + taishanPiBuildModeArguments(),
            asyncTask: true
        )
    }

    func installReleaseVolume(profile: String) {
        let title = profile == "bsp-flex" ? "完整开发 Volume" : "基础 Volume"
        installerLastDetail = "准备初始化\(title)..."
        runManagedAction(
            title: title,
            successMessage: "\(title)初始化任务已提交",
            localArgs: ["release", "seed-volume", "--profile", profile] + taishanPiBuildModeArguments(),
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
            let title = "切换 Loader"
            let pendingStartedAt = Date()
            busy = true
            pendingTaskTitle = title
            clearInlineError()
            appendActivity(level: .info, title: title, message: "正在确认控制服务或 SSH 链路")
            defer { busy = false }

            if let message = await validatePrecondition(.rebootLoader) {
                await waitForPendingTaskVisibleSince(pendingStartedAt)
                pendingTaskTitle = ""
                presentInlineError(message)
                appendActivity(level: .warning, title: title, message: message)
                return
            }
            let route = currentOperationRoute()
            do {
                appendActivity(level: .info, title: title, message: "控制链路已就绪，正在提交任务")
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
                }
                let response = try await postLocalAgentRebootJob(
                    target: "loader",
                    boardID: route.boardID,
                    variantID: route.variantID,
                    deviceID: route.deviceID
                )
                markTaishanLoaderTransitionStarted(duration: 36)
                await waitForPendingTaskVisibleSince(pendingStartedAt)
                pendingTaskTitle = ""
                appendActivity(level: .info, title: title, message: "任务已启动", detail: response.task?.log_path)
                if let taskID = response.task?.id {
                    pollTaskInBackground(taskID, title: title)
                    startTransitionWatch(reason: title, duration: 24, step: 1.0)
                }
            } catch {
                let detail = error.localizedDescription
                await waitForPendingTaskVisibleSince(pendingStartedAt)
                pendingTaskTitle = ""
                presentInlineError(detail)
                appendActivity(level: .error, title: title, message: "执行失败", detail: detail)
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
                throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
            }
            clearInlineError()
            let response = try await postLocalAgentRebootJob(
                target: "device",
                boardID: route.boardID,
                variantID: route.variantID
            )
            let detail = response.task?.log_path ?? ""
            appendActivity(level: .info, title: title, message: "任务已启动", detail: detail)
            if let taskID = response.task?.id {
                pollTaskInBackground(taskID, title: title)
            }
        } catch {
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
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
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

    func flashSelectedRawImage() {
        Task {
            let route = currentOperationRoute()
            let imagePath = taishanPiRawImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if let message = await validatePrecondition(.flash("all")) {
                presentInlineError(message)
                appendActivity(level: .warning, title: "IMG 全量刷写", message: message)
                return
            }
            if let localError = rawImageFlashPrerequisiteError() {
                presentInlineError(localError)
                appendActivity(level: .warning, title: "IMG 全量刷写", message: localError)
                return
            }
            busy = true
            defer { busy = false }
            do {
                await ensureLocalAgentStartedIfNeeded()
                guard localAgentRunning else {
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "IMG 全量刷写"
                let response = try await postLocalAgentFlashJob(
                    scope: "raw",
                    source: .custom,
                    boardID: route.boardID,
                    variantID: route.variantID,
                    deviceID: route.deviceID,
                    hostImageFile: imagePath
                )
                pendingTaskTitle = ""
                currentTask = response.task
                let detail = response.task?.log_path ?? imagePath
                appendActivity(level: .info, title: "IMG 全量刷写", message: "任务已启动", detail: detail)
                if let taskID = response.task?.id {
                    pollTask(taskID)
                }
            } catch {
                pendingTaskTitle = ""
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "IMG 全量刷写", message: "执行失败", detail: detail)
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
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "开发版构建"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "dev-build-sync",
                    title: "开发版构建",
                    arguments: ["dev", "build-sync"] + taishanPiBuildModeArguments()
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
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
                }
                clearInlineError()
                taskPollTask?.cancel()
                dismissedFinishedTaskIDs.removeAll()
                currentTask = nil
                pendingTaskTitle = "开发版构建并刷写"
                let response = try await postLocalAgentRuntimeJob(
                    actionID: "dev-build-sync-flash",
                    title: "开发版构建并刷写",
                    arguments: ["dev", "build-sync-flash"] + taishanPiBuildModeArguments()
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

    private func rp2350ConnectedOrSelected() -> Bool {
        let route = currentOperationRoute()
        return isRP2350BoardID(route.boardID) || isRP2350BoardID(status?.device?.board_id)
    }

    private func rp2350CurrentState() -> String {
        (status?.rp2350?.state ?? status?.usb?.mode ?? "not-found").lowercased()
    }

    private func rp2350UF2PrerequisiteError() -> String? {
        let trimmed = rp2350UF2Path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "请先选择 UF2 固件文件。"
        }
        guard FileManager.default.fileExists(atPath: trimmed) else {
            return "UF2 文件不存在：\(trimmed)"
        }
        return nil
    }

    private func rp2350ReadbackPrerequisiteError() -> String? {
        let trimmed = rp2350ReadbackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "请先设置回读文件输出路径。"
        }
        return nil
    }

    private func rp2350ParsedLogLines() -> Int {
        let parsed = Int(rp2350LogLines.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 6
        return max(1, min(parsed, 200))
    }

    func rp2350Detect() {
        Task {
            busy = true
            defer { busy = false }
            do {
                try await queueRP2350Job(title: "RP2350 状态检测", action: "detect", successMessage: "检测任务已提交")
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "RP2350 状态检测", message: "执行失败", detail: detail)
            }
        }
    }

    func rp2350EnterBootsel() {
        Task {
            guard rp2350ConnectedOrSelected() else {
                let message = "当前没有检测到可操作的 RP2350 开发板。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "进入 BOOTSEL", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await queueRP2350Job(title: "进入 BOOTSEL", action: "enter_bootsel", successMessage: "BOOTSEL 切换任务已提交")
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "进入 BOOTSEL", message: "执行失败", detail: detail)
            }
        }
    }

    func rp2350ReturnToRuntime() {
        Task {
            guard rp2350ConnectedOrSelected() else {
                let message = "当前没有检测到可操作的 RP2350 开发板。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "恢复运行态", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await queueRP2350Job(title: "恢复运行态", action: "run", successMessage: "运行态恢复任务已提交")
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "恢复运行态", message: "执行失败", detail: detail)
            }
        }
    }

    func rp2350FlashUF2() {
        Task {
            if let message = rp2350UF2PrerequisiteError() {
                presentInlineError(message)
                appendActivity(level: .warning, title: "UF2 刷写", message: message)
                return
            }
            let route = currentOperationRoute()
            guard let boardID = route.boardID, !boardID.isEmpty else {
                let message = "当前没有选中的开发板类型。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "UF2 刷写", message: message)
                return
            }
            let variantID = route.variantID ?? boardID
            let candidates = rp2350FlashCandidates()
            guard !candidates.isEmpty else {
                let message = "当前没有检测到可刷写的 RP2350 设备。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "UF2 刷写", message: message)
                return
            }
            if candidates.count > 1 {
                rp2350FlashTargetPrompt = RP2350FlashTargetPrompt(
                    boardID: boardID,
                    variantID: variantID,
                    boardDisplayName: supportedBoard(for: boardID)?.displayName ?? boardID,
                    candidates: candidates
                )
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await performRP2350FlashUF2(
                    boardID: boardID,
                    variantID: variantID,
                    deviceID: candidates[0].deviceID
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "UF2 刷写", message: "执行失败", detail: detail)
            }
        }
    }

    private func performRP2350FlashUF2(boardID: String, variantID: String, deviceID: String?) async throws {
        try await queueRP2350Job(
            title: "UF2 刷写",
            action: "flash",
            boardID: boardID,
            variantID: variantID,
            deviceID: deviceID,
            uf2Path: rp2350UF2Path,
            successMessage: "UF2 刷写任务已提交"
        )
    }

    private func rp2350FlashCandidates() -> [DetectedBoardCandidate] {
        var seen = Set<String>()
        return activeControlDeviceCandidates
            .filter { isRP2350BoardID($0.boardID) && $0.deviceID != nil }
            .filter { candidate in
                guard let deviceID = candidate.deviceID else {
                    return false
                }
                return seen.insert(deviceID).inserted
            }
    }

    func confirmRP2350FlashTarget(_ candidate: DetectedBoardCandidate, prompt: RP2350FlashTargetPrompt) {
        rp2350FlashTargetPrompt = nil
        Task {
            busy = true
            defer { busy = false }
            do {
                try await performRP2350FlashUF2(
                    boardID: prompt.boardID,
                    variantID: prompt.variantID,
                    deviceID: candidate.deviceID
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "UF2 刷写", message: "执行失败", detail: detail)
            }
        }
    }

    func dismissRP2350FlashTargetPrompt() {
        rp2350FlashTargetPrompt = nil
    }

    func rp2350VerifyUF2() {
        Task {
            if let message = rp2350UF2PrerequisiteError() {
                presentInlineError(message)
                appendActivity(level: .warning, title: "UF2 校验", message: message)
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await queueRP2350Job(title: "UF2 校验", action: "verify", uf2Path: rp2350UF2Path, successMessage: "UF2 校验任务已提交")
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "UF2 校验", message: "执行失败", detail: detail)
            }
        }
    }

    func rp2350TailLogs() {
        Task {
            busy = true
            defer { busy = false }
            do {
                try await queueRP2350Job(title: "串口日志", action: "tail_logs", lines: rp2350ParsedLogLines(), successMessage: "串口日志读取任务已提交")
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .error, title: "串口日志", message: "执行失败", detail: detail)
            }
        }
    }

    private func rp2350MonitorSerialDevice() -> String? {
        if rp2350MonitorTransportMode == "wifi" {
            let host = rp2350MonitorTCPHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let port = rp2350MonitorTCPPort.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else {
                return nil
            }
            return port.isEmpty ? host : "\(host):\(port)"
        }

        return rp2350MonitorUSBSerialDevice()
    }

    private func rp2350MonitorUSBSerialDevice() -> String? {
        let rpState = (status?.rp2350?.state ?? "").lowercased()
        if rpState.contains("runtime"),
           let device = status?.rp2350?.runtime_port?.device,
           device.hasPrefix("/dev/") {
            return device
        }

        let rpDevices = (status?.devices ?? []).filter {
            $0.connected == true && isRP2350BoardID($0.board_id)
        }
        if let preferredControlDeviceID,
           let selected = rpDevices.first(where: { $0.device_id == preferredControlDeviceID }),
           let locator = selected.transport_locator,
           locator.hasPrefix("/dev/") {
            return locator
        }
        if let selected = rpDevices.first,
           let locator = selected.transport_locator,
           locator.hasPrefix("/dev/") {
            return locator
        }
        return nil
    }

    private func rp2350MonitorTransportUnavailableMessage() -> String {
        if rp2350MonitorTransportMode == "wifi" {
            return "Wi-Fi 控制通道未配置。请填写 RP2350-Monitor 的 IP 地址和端口。"
        }
        return "没有找到当前 Pico 的 USB CDC 运行态串口。请确认设备不是 BOOTSEL 状态。"
    }

    private func scheduleRP2350MonitorProbeIfNeeded() {
        guard rp2350MonitorTransportMode == "usb" else {
            rp2350MonitorProbeTask?.cancel()
            return
        }
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350MonitorProbeTask?.cancel()
            rp2350MonitorLastProbeDevice = ""
            if rp2350Monitor.isProbing {
                rp2350Monitor = RP2350MonitorState(
                    availability: .unsupported(rp2350MonitorTransportUnavailableMessage())
                )
            }
            return
        }
        guard device != rp2350MonitorLastProbeDevice || rp2350Monitor.availability == .unknown else {
            return
        }
        guard !rp2350MonitorBusy else {
            return
        }
        rp2350MonitorLastProbeDevice = device
        rp2350MonitorProbeTask?.cancel()
        rp2350MonitorProbeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            await self?.performRP2350MonitorProbe(force: false)
        }
    }

    func rp2350MonitorProbe() {
        Task { @MainActor in
            await performRP2350MonitorProbe(force: true)
        }
    }

    private func performRP2350MonitorProbe(force: Bool) async {
        guard !rp2350MonitorBusy else {
            return
        }
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
            return
        }
        rp2350MonitorBusy = true
        rp2350Monitor.availability = .probing
        rp2350Monitor.serialDevice = device
        defer { rp2350MonitorBusy = false }

        do {
            let hello = try await RP2350MonitorClient.transactSerial(
                device: device,
                payload: ["cmd": "hello"],
                timeout: 2.5
            )
            guard hello.response?["ok"] as? Bool == true else {
                throw ToolkitGUIError.commandFailed(hello.response?["msg"] as? String ?? "当前固件未响应 RP2350-Monitor hello")
            }
            let status = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "status"], timeout: 2.5)
            let pins = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "pins"], timeout: 2.5)
            let channels = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "channels"], timeout: 2.5)
            let logic = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "logic_status"], timeout: 2.5)
            applyRP2350MonitorResults(
                hello: hello,
                status: status,
                pins: pins,
                channels: channels,
                logic: logic,
                logicCapabilityChecked: true,
                responseTitle: "监控固件"
            )
            if force {
                appendActivity(level: .success, title: "RP2350-Monitor", message: "已检测到监控固件", detail: device)
            }
        } catch {
            let message = error.localizedDescription
            let knownMonitorProtocol = rp2350Monitor.tabAvailable
            let detail = knownMonitorProtocol
                ? "当前监控控制通道暂时不可用：\(message)"
                : "当前 Pico 固件未提供 RP2350-Monitor JSONL 协议：\(message)"
            rp2350Monitor.availability = .unsupported(detail)
            rp2350Monitor.lastResponse = message
            rp2350Monitor.lastUpdated = Date()
            if force {
                appendActivity(
                    level: .warning,
                    title: "RP2350-Monitor",
                    message: knownMonitorProtocol ? "监控控制通道异常" : "当前固件不支持监控页",
                    detail: message
                )
            }
        }
    }

    func rp2350MonitorRefresh() {
        Task { @MainActor in
            await rp2350MonitorRunRefresh(forceProbe: true)
        }
    }

    private func rp2350MonitorRunRefresh(forceProbe: Bool = false) async {
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
            return
        }
        if !rp2350Monitor.supported || forceProbe {
            await performRP2350MonitorProbe(force: forceProbe)
            return
        }
        var commands: [[String: Any]] = [
            ["cmd": "status"],
            ["cmd": "pins"],
            ["cmd": "channels"],
        ]
        if rp2350Monitor.logicSupported {
            commands.append(["cmd": "logic_status"])
        }
        await rp2350MonitorRunCommandSequence(
            title: "刷新监控状态",
            commands: commands,
            device: device,
            refreshAfter: false
        )
    }

    func rp2350MonitorReadEvents() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            let count = max(1, min(Int(rp2350MonitorEventCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 32, 64))
            await rp2350MonitorRunCommandSequence(
                title: "读取事件",
                commands: [["cmd": "events_read", "count": count]],
                device: device,
                refreshAfter: false
            )
        }
    }

    func rp2350MonitorWiFiScanViaUSB() {
        Task { @MainActor in
            guard let device = rp2350MonitorUSBSerialDevice() else {
                rp2350Monitor.availability = .unsupported("没有找到当前 Pico 的 USB CDC 运行态串口，无法通过 USB 扫描 Wi-Fi。")
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "扫描 Wi-Fi",
                commands: [["cmd": "wifi_scan"]],
                device: device,
                refreshAfter: true
            )
        }
    }

    func rp2350MonitorWiFiSaveAndConnectViaUSB() {
        Task { @MainActor in
            guard let device = rp2350MonitorUSBSerialDevice() else {
                rp2350Monitor.availability = .unsupported("没有找到当前 Pico 的 USB CDC 运行态串口，无法通过 USB 配置 Wi-Fi。")
                return
            }
            do {
                let slot = try parseMonitorInt(rp2350MonitorWiFiSlot, label: "Wi-Fi 槽位")
                guard (0...2).contains(slot) else {
                    throw ToolkitGUIError.commandFailed("Wi-Fi 槽位只能是 0、1 或 2。")
                }
                let ssid = rp2350MonitorWiFiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !ssid.isEmpty else {
                    throw ToolkitGUIError.commandFailed("Wi-Fi SSID 不能为空。")
                }
                await rp2350MonitorRunCommandSequence(
                    title: "保存并连接 Wi-Fi",
                    commands: [
                        [
                            "cmd": "wifi_set",
                            "slot": slot,
                            "ssid": ssid,
                            "password": rp2350MonitorWiFiPassword,
                            "save": true,
                        ],
                        ["cmd": "wifi_connect", "slot": slot],
                    ],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "Wi-Fi 配置参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorWiFiStartAPViaUSB() {
        Task { @MainActor in
            guard let device = rp2350MonitorUSBSerialDevice() else {
                rp2350Monitor.availability = .unsupported("没有找到当前 Pico 的 USB CDC 运行态串口，无法通过 USB 开启 AP。")
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "开启 Wi-Fi AP",
                commands: [["cmd": "wifi_ap"]],
                device: device,
                refreshAfter: true
            )
        }
    }

    func rp2350MonitorWiFiClearViaUSB() {
        Task { @MainActor in
            guard let device = rp2350MonitorUSBSerialDevice() else {
                rp2350Monitor.availability = .unsupported("没有找到当前 Pico 的 USB CDC 运行态串口，无法通过 USB 清除 Wi-Fi 配置。")
                return
            }
            do {
                let slot = try parseMonitorInt(rp2350MonitorWiFiSlot, label: "Wi-Fi 槽位")
                guard (0...2).contains(slot) else {
                    throw ToolkitGUIError.commandFailed("Wi-Fi 槽位只能是 0、1 或 2。")
                }
                await rp2350MonitorRunCommandSequence(
                    title: "清除 Wi-Fi 配置",
                    commands: [["cmd": "wifi_clear", "slot": slot]],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "Wi-Fi 槽位无效", detail: detail)
            }
        }
    }

    func rp2350MonitorSendRawCommand() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let command = try parseRP2350MonitorRawCommand()
                await rp2350MonitorRunCommandSequence(
                    title: "发送 JSON 命令",
                    commands: [command],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "JSON 命令无效", detail: detail)
            }
        }
    }

    func rp2350MonitorConfigureGPIO() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            guard let channelID = Int(rp2350MonitorGPIOChannelID.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let gpio = Int(rp2350MonitorGPIOPin.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                let message = "GPIO 通道 ID 和 GPIO 编号必须是整数。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: message)
                return
            }
            let config: [String: Any] = [
                "cmd": "channel_config",
                "id": channelID,
                "type": "gpio",
                "gpio": gpio,
                "direction": rp2350MonitorGPIODirection,
                "pull": rp2350MonitorGPIOPull,
                "initial": rp2350MonitorGPIOInitialLevel,
            ]
            await rp2350MonitorRunCommandSequence(
                title: "配置 GPIO",
                commands: [
                    config,
                    ["cmd": "channel_start", "id": channelID],
                ],
                device: device,
                refreshAfter: true
            )
        }
    }

    func rp2350MonitorGPIORead() {
        Task { @MainActor in
            await rp2350MonitorGPIOAction(level: nil)
        }
    }

    func rp2350MonitorGPIOWrite(level: Bool) {
        Task { @MainActor in
            await rp2350MonitorGPIOAction(level: level)
        }
    }

    private func rp2350MonitorGPIOAction(level: Bool?) async {
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
            return
        }
        guard let channelID = Int(rp2350MonitorGPIOChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            let message = "GPIO 通道 ID 必须是整数。"
            presentInlineError(message)
            appendActivity(level: .warning, title: "RP2350-Monitor", message: message)
            return
        }
        let command: [String: Any]
        if let level {
            command = ["cmd": "gpio_write", "id": channelID, "level": level]
        } else {
            command = ["cmd": "gpio_read", "id": channelID]
        }
        await rp2350MonitorRunCommandSequence(
            title: level == nil ? "读取 GPIO" : "写入 GPIO",
            commands: [command],
            device: device,
            refreshAfter: true
        )
    }

    func rp2350MonitorReleaseChannel() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            guard let channelID = Int(rp2350MonitorGPIOChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                let message = "GPIO 通道 ID 必须是整数。"
                presentInlineError(message)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: message)
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "释放通道",
                commands: [["cmd": "channel_release", "id": channelID]],
                device: device,
                refreshAfter: true
            )
        }
    }

    func rp2350MonitorConfigureGPIOAnalyzer() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let baseChannelID = try parseMonitorInt(rp2350MonitorGPIOAnalyzerChannelID, label: "GPIO 输入起始通道 ID")
                let pins = try parseMonitorIntList(
                    rp2350MonitorGPIOAnalyzerPins.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? rp2350MonitorGPIOAnalyzerPin
                        : rp2350MonitorGPIOAnalyzerPins,
                    label: "GPIO 输入引脚列表"
                )
                guard !pins.isEmpty else {
                    throw ToolkitGUIError.commandFailed("GPIO 输入引脚列表不能为空。")
                }
                let channelPins = Dictionary(uniqueKeysWithValues: pins.enumerated().map { offset, gpio in
                    (baseChannelID + offset, gpio)
                })
                rp2350MonitorGPIOAnalyzerActivePins = channelPins
                rp2350MonitorGPIOAnalyzerPin = pins.map(String.init).joined(separator: ",")
                rp2350MonitorGPIOAnalyzerPins = rp2350MonitorGPIOAnalyzerPin
                rp2350MonitorGPIOAnalyzerLive = true
                var commands: [[String: Any]] = []
                for (offset, gpio) in pins.enumerated() {
                    let channelID = baseChannelID + offset
                    commands.append([
                        "cmd": "channel_config",
                        "id": channelID,
                        "type": "gpio",
                        "gpio": gpio,
                        "direction": "input",
                        "pull": rp2350MonitorGPIOAnalyzerPull,
                    ])
                    commands.append(["cmd": "channel_start", "id": channelID])
                    commands.append(["cmd": "gpio_read", "id": channelID])
                }
                await rp2350MonitorRunCommandSequence(
                    title: "启动 GPIO 输入采集",
                    commands: commands,
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                rp2350MonitorGPIOAnalyzerLive = false
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "GPIO 输入配置无效", detail: detail)
            }
        }
    }

    func rp2350MonitorReadGPIOAnalyzerEvents() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channels = try rp2350MonitorGPIOAnalyzerChannelIDs()
                let count = max(1, min(Int(rp2350MonitorEventCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 32, 64))
                let commands = channels.map { ["cmd": "events_read", "channel": $0, "count": count] as [String: Any] }
                await rp2350MonitorRunCommandSequence(
                    title: "读取 GPIO 采集事件",
                    commands: commands,
                    device: device,
                    refreshAfter: false
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "GPIO 输入事件读取失败", detail: detail)
            }
        }
    }

    func rp2350MonitorReleaseGPIOAnalyzerChannel() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channels = try rp2350MonitorGPIOAnalyzerChannelIDs()
                let commands = channels.map { ["cmd": "channel_release", "id": $0] as [String: Any] }
                rp2350MonitorGPIOAnalyzerLive = false
                await rp2350MonitorRunCommandSequence(
                    title: "释放 GPIO 输入通道",
                    commands: commands,
                    device: device,
                    refreshAfter: true
                )
                rp2350MonitorGPIOAnalyzerActivePins = [:]
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "GPIO 输入通道释放失败", detail: detail)
            }
        }
    }

    func rp2350MonitorPollGPIOAnalyzer() {
        Task { @MainActor in
            guard rp2350MonitorGPIOAnalyzerLive, !rp2350MonitorBusy else {
                return
            }
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350MonitorGPIOAnalyzerLive = false
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channels = try rp2350MonitorGPIOAnalyzerChannelIDs()
                let count = max(1, min(Int(rp2350MonitorEventCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 32, 64))
                var commands: [[String: Any]] = []
                for channel in channels {
                    commands.append(["cmd": "gpio_read", "id": channel])
                    commands.append(["cmd": "events_read", "channel": channel, "count": count])
                }
                await rp2350MonitorRunCommandSequence(
                    title: "刷新 GPIO 输入",
                    commands: commands,
                    device: device,
                    refreshAfter: false,
                    logActivity: false
                )
            } catch {
                rp2350MonitorGPIOAnalyzerLive = false
                let detail = error.localizedDescription
                rp2350Monitor.lastResponse = detail
                rp2350Monitor.lastUpdated = Date()
            }
        }
    }

    func rp2350MonitorLogicConfigure() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let pinBase = try parseMonitorInt(rp2350LogicPinBase, label: "采样起始 GPIO")
                let pinCount = try parseMonitorInt(rp2350LogicPinCount, label: "采样通道数")
                let sampleRate = try parseMonitorInt(rp2350LogicSampleRate, label: "采样率")
                let samples = try parseMonitorInt(rp2350LogicSamples, label: "样本数")
                var command: [String: Any] = [
                    "cmd": "logic_config",
                    "pin_base": pinBase,
                    "pin_count": pinCount,
                    "sample_rate": sampleRate,
                    "samples": samples,
                ]
                if rp2350LogicTriggerEnabled {
                    command["trigger_pin"] = try parseMonitorInt(rp2350LogicTriggerPin, label: "触发 GPIO")
                    command["trigger_level"] = rp2350LogicTriggerLevel
                }
                await rp2350MonitorRunCommandSequence(
                    title: "配置逻辑分析仪",
                    commands: [command, ["cmd": "logic_status"]],
                    device: device,
                    refreshAfter: false
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "逻辑分析仪参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorLogicStart() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            rp2350Monitor.logicCaptureChunks = []
            rp2350Monitor.logicCaptureWords = []
            rp2350Monitor.logicLastReadAt = nil
            await rp2350MonitorRunCommandSequence(
                title: "开始逻辑采集",
                commands: [["cmd": "logic_start"], ["cmd": "logic_status"]],
                device: device,
                refreshAfter: false
            )
        }
    }

    func rp2350MonitorLogicRefreshStatus(logActivity: Bool = true) {
        Task { @MainActor in
            await rp2350MonitorLogicRefreshStatusAsync(logActivity: logActivity)
        }
    }

    private func rp2350MonitorLogicRefreshStatusAsync(logActivity: Bool) async {
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
            return
        }
        await rp2350MonitorRunCommandSequence(
            title: "刷新逻辑采集状态",
            commands: [["cmd": "logic_status"]],
            device: device,
            refreshAfter: false,
            logActivity: logActivity
        )
    }

    func rp2350MonitorLogicPollIfRunning() {
        Task { @MainActor in
            guard rp2350Monitor.logicRunning, !rp2350MonitorBusy else {
                return
            }
            await rp2350MonitorLogicRefreshStatusAsync(logActivity: false)
        }
    }

    func rp2350MonitorLogicReadCapture() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "读取逻辑波形",
                commands: [
                    ["cmd": "logic_status"],
                    ["cmd": "logic_read", "offset_words": 0, "count_words": 0],
                    ["cmd": "logic_status"],
                ],
                device: device,
                refreshAfter: false
            )
        }
    }

    func rp2350MonitorLogicStop() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "停止逻辑采集",
                commands: [["cmd": "logic_stop"], ["cmd": "logic_status"]],
                device: device,
                refreshAfter: false
            )
        }
    }

    func rp2350MonitorLogicRelease() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            await rp2350MonitorRunCommandSequence(
                title: "释放逻辑分析仪",
                commands: [["cmd": "logic_release"], ["cmd": "logic_status"]],
                device: device,
                refreshAfter: true
            )
        }
    }

    func rp2350MonitorConfigureUART() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channelID = try parseMonitorInt(rp2350MonitorUARTChannelID, label: "UART 通道 ID")
                var config: [String: Any] = [
                    "cmd": "channel_config",
                    "id": channelID,
                    "type": "uart",
                    "instance": try parseMonitorInt(rp2350MonitorUARTInstance, label: "UART 实例"),
                    "tx": try parseMonitorInt(rp2350MonitorUARTTX, label: "UART TX"),
                    "rx": try parseMonitorInt(rp2350MonitorUARTRX, label: "UART RX"),
                    "baud": try parseMonitorInt(rp2350MonitorUARTBaud, label: "UART 波特率"),
                ]
                if rp2350MonitorUARTLoopback {
                    config["loopback"] = true
                }
                await rp2350MonitorRunCommandSequence(
                    title: "配置 UART",
                    commands: [config, ["cmd": "channel_start", "id": channelID]],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "UART 参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorUARTWrite() {
        Task { @MainActor in
            await rp2350MonitorChannelHexCommand(
                title: "UART 写入",
                command: "channel_write",
                channelIDText: rp2350MonitorUARTChannelID,
                hexText: rp2350MonitorUARTHex
            )
        }
    }

    func rp2350MonitorConfigureSPI() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channelID = try parseMonitorInt(rp2350MonitorSPIChannelID, label: "SPI 通道 ID")
                var config: [String: Any] = [
                    "cmd": "channel_config",
                    "id": channelID,
                    "type": "spi",
                    "instance": try parseMonitorInt(rp2350MonitorSPIInstance, label: "SPI 实例"),
                    "sck": try parseMonitorInt(rp2350MonitorSPISCK, label: "SPI SCK"),
                    "mosi": try parseMonitorInt(rp2350MonitorSPIMOSI, label: "SPI MOSI"),
                    "miso": try parseMonitorInt(rp2350MonitorSPIMISO, label: "SPI MISO"),
                    "baud": try parseMonitorInt(rp2350MonitorSPIBaud, label: "SPI 频率"),
                ]
                let csText = rp2350MonitorSPICS.trimmingCharacters(in: .whitespacesAndNewlines)
                if !csText.isEmpty {
                    config["cs"] = try parseMonitorInt(csText, label: "SPI CS")
                }
                await rp2350MonitorRunCommandSequence(
                    title: "配置 SPI",
                    commands: [config, ["cmd": "channel_start", "id": channelID]],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "SPI 参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorSPITransfer() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channelID = try parseMonitorInt(rp2350MonitorSPIChannelID, label: "SPI 通道 ID")
                var command: [String: Any] = [
                    "cmd": "spi_xfer",
                    "id": channelID,
                    "hex": rp2350MonitorSPIHex.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
                let readLenText = rp2350MonitorSPIReadLength.trimmingCharacters(in: .whitespacesAndNewlines)
                if !readLenText.isEmpty {
                    command["read_len"] = try parseMonitorInt(readLenText, label: "SPI 读取长度")
                }
                await rp2350MonitorRunCommandSequence(
                    title: "SPI 传输",
                    commands: [command],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "SPI 传输参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorConfigureI2C() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channelID = try parseMonitorInt(rp2350MonitorI2CChannelID, label: "I2C 通道 ID")
                let config: [String: Any] = [
                    "cmd": "channel_config",
                    "id": channelID,
                    "type": "i2c",
                    "instance": try parseMonitorInt(rp2350MonitorI2CInstance, label: "I2C 实例"),
                    "sda": try parseMonitorInt(rp2350MonitorI2CSDA, label: "I2C SDA"),
                    "scl": try parseMonitorInt(rp2350MonitorI2CSCL, label: "I2C SCL"),
                    "baud": try parseMonitorInt(rp2350MonitorI2CBaud, label: "I2C 频率"),
                ]
                await rp2350MonitorRunCommandSequence(
                    title: "配置 I2C",
                    commands: [config, ["cmd": "channel_start", "id": channelID]],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "I2C 参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorI2CTransfer() {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let command: [String: Any] = [
                    "cmd": "i2c_xfer",
                    "id": try parseMonitorInt(rp2350MonitorI2CChannelID, label: "I2C 通道 ID"),
                    "addr": try parseMonitorInt(rp2350MonitorI2CAddress, label: "I2C 地址"),
                    "write": rp2350MonitorI2CWriteHex.trimmingCharacters(in: .whitespacesAndNewlines),
                    "read_len": try parseMonitorInt(rp2350MonitorI2CReadLength, label: "I2C 读取长度"),
                ]
                await rp2350MonitorRunCommandSequence(
                    title: "I2C 传输",
                    commands: [command],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "I2C 传输参数无效", detail: detail)
            }
        }
    }

    func rp2350MonitorStopOrReleaseChannel(channelIDText: String, release: Bool) {
        Task { @MainActor in
            guard let device = rp2350MonitorSerialDevice() else {
                rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
                return
            }
            do {
                let channelID = try parseMonitorInt(channelIDText, label: "通道 ID")
                await rp2350MonitorRunCommandSequence(
                    title: release ? "释放通道" : "停止通道",
                    commands: [["cmd": release ? "channel_release" : "channel_stop", "id": channelID]],
                    device: device,
                    refreshAfter: true
                )
            } catch {
                let detail = error.localizedDescription
                presentInlineError(detail)
                appendActivity(level: .warning, title: "RP2350-Monitor", message: "通道操作失败", detail: detail)
            }
        }
    }

    private func rp2350MonitorChannelHexCommand(
        title: String,
        command: String,
        channelIDText: String,
        hexText: String
    ) async {
        guard let device = rp2350MonitorSerialDevice() else {
            rp2350Monitor.availability = .unsupported(rp2350MonitorTransportUnavailableMessage())
            return
        }
        do {
            let channelID = try parseMonitorInt(channelIDText, label: "通道 ID")
            await rp2350MonitorRunCommandSequence(
                title: title,
                commands: [["cmd": command, "id": channelID, "hex": hexText.trimmingCharacters(in: .whitespacesAndNewlines)]],
                device: device,
                refreshAfter: true
            )
        } catch {
            let detail = error.localizedDescription
            presentInlineError(detail)
            appendActivity(level: .warning, title: "RP2350-Monitor", message: "\(title)失败", detail: detail)
        }
    }

    private func rp2350MonitorRunCommandSequence(
        title: String,
        commands: [[String: Any]],
        device: String,
        refreshAfter: Bool,
        logActivity: Bool = true
    ) async {
        guard !rp2350MonitorBusy else {
            return
        }
        rp2350MonitorBusy = true
        defer { rp2350MonitorBusy = false }
        var commandLines: [String] = []
        do {
            var statusResult: RP2350MonitorTransactionResult?
            var pinsResult: RP2350MonitorTransactionResult?
            var channelsResult: RP2350MonitorTransactionResult?
            var logicResult: RP2350MonitorTransactionResult?
            for command in commands {
                let commandName = command["cmd"] as? String
                let timeout: TimeInterval
                switch commandName {
                case "wifi_connect":
                    timeout = 18.0
                case "logic_read":
                    timeout = 25.0
                default:
                    timeout = 3.0
                }
                let result = try await RP2350MonitorClient.transactSerial(device: device, payload: command, timeout: timeout)
                commandLines.append(contentsOf: result.lines)
                guard result.response?["ok"] as? Bool != false else {
                    throw ToolkitGUIError.commandFailed(result.response?["msg"] as? String ?? "\(command["cmd"] ?? "command") 执行失败")
                }
                switch result.response?["cmd"] as? String {
                case "status", "buffer_status":
                    statusResult = result
                case "logic_status", "logic_config":
                    logicResult = result
                case "pins":
                    pinsResult = result
                case "channels":
                    channelsResult = result
                default:
                    break
                }
            }
            if refreshAfter {
                statusResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "status"], timeout: 2.5)
                pinsResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "pins"], timeout: 2.5)
                channelsResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "channels"], timeout: 2.5)
                if rp2350Monitor.logicSupported {
                    logicResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "logic_status"], timeout: 2.5)
                }
            }
            applyRP2350MonitorResults(
                hello: nil,
                status: statusResult,
                pins: pinsResult,
                channels: channelsResult,
                logic: logicResult,
                extraLines: commandLines,
                responseTitle: title
            )
            if logActivity {
                appendActivity(level: .success, title: "RP2350-Monitor", message: "\(title)完成")
            }
        } catch {
            let detail = error.localizedDescription
            if refreshAfter,
                let statusResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "status"], timeout: 2.5) {
                let pinsResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "pins"], timeout: 2.5)
                let channelsResult = try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "channels"], timeout: 2.5)
                let logicResult = rp2350Monitor.logicSupported
                    ? try? await RP2350MonitorClient.transactSerial(device: device, payload: ["cmd": "logic_status"], timeout: 2.5)
                    : nil
                applyRP2350MonitorResults(
                    hello: nil,
                    status: statusResult,
                    pins: pinsResult,
                    channels: channelsResult,
                    logic: logicResult,
                    extraLines: commandLines,
                    responseTitle: "\(title)失败"
                )
            }
            rp2350Monitor.lastResponse = detail
            rp2350Monitor.lastUpdated = Date()
            if logActivity {
                let message = title.contains("Wi-Fi") ? "Wi-Fi 操作失败：\(detail)" : detail
                presentInlineError(message)
                appendActivity(level: .error, title: "RP2350-Monitor", message: "\(title)失败", detail: detail)
            }
        }
    }

    private func parseRP2350MonitorRawCommand() throws -> [String: Any] {
        let trimmed = rp2350MonitorRawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            throw ToolkitGUIError.invalidJSON(trimmed)
        }
        guard let command = dictionary["cmd"] as? String, !command.isEmpty else {
            throw ToolkitGUIError.commandFailed("JSON 命令必须包含 cmd 字段。")
        }
        return dictionary
    }

    private func parseMonitorInt(_ text: String, label: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ToolkitGUIError.commandFailed("\(label)不能为空。")
        }
        if trimmed.lowercased().hasPrefix("0x"),
           let value = Int(trimmed.dropFirst(2), radix: 16) {
            return value
        }
        if let value = Int(trimmed) {
            return value
        }
        throw ToolkitGUIError.commandFailed("\(label)必须是十进制或 0x 十六进制整数。")
    }

    private func parseMonitorIntList(_ text: String, label: String) throws -> [Int] {
        let separators = CharacterSet(charactersIn: ",，;； \n\t")
        let parts = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            throw ToolkitGUIError.commandFailed("\(label)不能为空。")
        }
        var values: [Int] = []
        var seen: Set<Int> = []
        for part in parts {
            let value = try parseMonitorInt(part, label: label)
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            values.append(value)
        }
        return values
    }

    private func rp2350MonitorGPIOAnalyzerChannelIDs() throws -> [Int] {
        let active = rp2350MonitorGPIOAnalyzerActivePins.keys.sorted()
        if !active.isEmpty {
            return active
        }
        let baseChannelID = try parseMonitorInt(rp2350MonitorGPIOAnalyzerChannelID, label: "GPIO 输入起始通道 ID")
        let pins = try parseMonitorIntList(
            rp2350MonitorGPIOAnalyzerPins.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? rp2350MonitorGPIOAnalyzerPin
                : rp2350MonitorGPIOAnalyzerPins,
            label: "GPIO 输入引脚列表"
        )
        return pins.indices.map { baseChannelID + $0 }
    }

    func rp2350MonitorGPIOAnalyzerDisplayChannels() -> [RP2350LogicChannel] {
        if !rp2350MonitorGPIOAnalyzerActivePins.isEmpty {
            return rp2350MonitorGPIOAnalyzerActivePins
                .sorted { $0.key < $1.key }
                .map { RP2350LogicChannel(channel: $0.key, gpio: $0.value) }
        }
        let baseChannel = Int(rp2350MonitorGPIOAnalyzerChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        let rawPins = rp2350MonitorGPIOAnalyzerPins.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? rp2350MonitorGPIOAnalyzerPin
            : rp2350MonitorGPIOAnalyzerPins
        let pins = (try? parseMonitorIntList(rawPins, label: "GPIO 输入引脚列表")) ?? []
        if pins.isEmpty {
            return [RP2350LogicChannel(channel: baseChannel, gpio: nil)]
        }
        return pins.indices.map { index in
            RP2350LogicChannel(channel: baseChannel + index, gpio: pins[index])
        }
    }

    private func applyRP2350MonitorResults(
        hello: RP2350MonitorTransactionResult?,
        status: RP2350MonitorTransactionResult?,
        pins: RP2350MonitorTransactionResult?,
        channels: RP2350MonitorTransactionResult?,
        logic: RP2350MonitorTransactionResult? = nil,
        logicCapabilityChecked: Bool = false,
        extraLines: [String] = [],
        responseTitle: String
    ) {
        var next = rp2350Monitor
        next.availability = .supported
        next.serialDevice = rp2350MonitorSerialDevice() ?? next.serialDevice
        next.lastUpdated = Date()

        if let helloResponse = hello?.response {
            next.firmwareVersion = stringValue(helloResponse["version"]) ?? next.firmwareVersion
            next.firmwareBoard = stringValue(helloResponse["board"]) ?? next.firmwareBoard
            next.links = stringArray(helloResponse["links"])
        }

        if let statusResponse = status?.response {
            if let wifi = dictionary(statusResponse["wifi"]) {
                applyRP2350MonitorWiFi(wifi, to: &next)
            }
            if let logic = dictionary(statusResponse["logic"]) {
                applyRP2350MonitorLogic(logic, to: &next)
            }
            if let buffers = dictionary(statusResponse["buffers"]) {
                applyRP2350MonitorBuffers(buffers, to: &next)
            }
            let parsedChannels = parseRP2350MonitorChannels(from: statusResponse)
            if !parsedChannels.isEmpty || statusResponse["channels"] != nil {
                next.channels = parsedChannels
            }
        }

        if logicCapabilityChecked {
            next.logicSupported = false
        }
        if let logicResponse = logic?.response,
           logicResponse["ok"] as? Bool == true,
           let logic = dictionary(logicResponse["logic"]) {
            next.logicSupported = true
            applyRP2350MonitorLogic(logic, to: &next)
        }

        if let pinsResponse = pins?.response {
            next.pins = parseRP2350MonitorPins(from: pinsResponse)
        }
        if let channelsResponse = channels?.response {
            next.channels = parseRP2350MonitorChannels(from: channelsResponse)
        }

        var allLines: [String] = []
        allLines.append(contentsOf: hello?.lines ?? [])
        allLines.append(contentsOf: status?.lines ?? [])
        allLines.append(contentsOf: pins?.lines ?? [])
        allLines.append(contentsOf: channels?.lines ?? [])
        allLines.append(contentsOf: logic?.lines ?? [])
        allLines.append(contentsOf: extraLines)
        let logicChunks = parseRP2350LogicCaptureChunks(from: allLines)
        if !logicChunks.isEmpty {
            next.logicCaptureChunks = logicChunks.sorted { $0.offsetWords < $1.offsetWords }
            next.logicCaptureWords = decodeRP2350LogicWords(from: next.logicCaptureChunks)
            next.logicLastReadAt = Date()
        }
        let newEntries = allLines.map { line -> RP2350MonitorEventLine in
            let kind = dictionaryFromJSONLine(line).flatMap { stringValue($0["type"]) } ?? "raw"
            return RP2350MonitorEventLine(kind: kind, text: line)
        }
        next.recentLines = Array((newEntries + next.recentLines).prefix(80))
        next.lastResponse = responseTitle
        syncRP2350MonitorWiFiDefaults(from: next)
        rp2350Monitor = next
    }

    private func applyRP2350MonitorLogic(_ logic: [String: Any], to state: inout RP2350MonitorState) {
        state.logicConfigured = boolValue(logic["configured"]) ?? state.logicConfigured
        state.logicRunning = boolValue(logic["running"]) ?? state.logicRunning
        state.logicComplete = boolValue(logic["complete"]) ?? state.logicComplete
        state.logicCaptureID = intValue(logic["capture_id"]) ?? state.logicCaptureID
        state.logicPinBase = intValue(logic["pin_base"]) ?? state.logicPinBase
        state.logicPinCount = intValue(logic["pin_count"]) ?? state.logicPinCount
        state.logicSampleRate = intValue(logic["sample_rate"]) ?? state.logicSampleRate
        state.logicSamples = intValue(logic["samples"]) ?? state.logicSamples
        state.logicWords = intValue(logic["words"]) ?? state.logicWords
        state.logicRecordBits = intValue(logic["record_bits"]) ?? state.logicRecordBits
        state.logicTriggerPin = intValue(logic["trigger_pin"]) ?? state.logicTriggerPin
        state.logicTriggerLevel = boolValue(logic["trigger_level"]) ?? state.logicTriggerLevel
        state.logicBufferWordsMax = intValue(logic["buffer_words_max"]) ?? state.logicBufferWordsMax
        state.logicBufferBytes = intValue(logic["buffer_bytes"]) ?? state.logicBufferBytes
        state.logicChunkBytes = intValue(logic["chunk_bytes"]) ?? state.logicChunkBytes
    }

    private func parseRP2350LogicCaptureChunks(from lines: [String]) -> [RP2350LogicCaptureChunk] {
        lines.compactMap { line in
            guard let document = dictionaryFromJSONLine(line),
                  stringValue(document["type"]) == "logic",
                  let captureID = intValue(document["capture_id"]),
                  let offsetWords = intValue(document["offset_words"]),
                  let words = intValue(document["words"]),
                  let pinBase = intValue(document["pin_base"]),
                  let pinCount = intValue(document["pin_count"]),
                  let sampleRate = intValue(document["sample_rate"]),
                  let samples = intValue(document["samples"]),
                  let recordBits = intValue(document["record_bits"]),
                  let hex = stringValue(document["hex"]) else {
                return nil
            }
            return RP2350LogicCaptureChunk(
                captureID: captureID,
                offsetWords: offsetWords,
                words: words,
                pinBase: pinBase,
                pinCount: pinCount,
                sampleRate: sampleRate,
                samples: samples,
                recordBits: recordBits,
                hex: hex
            )
        }
    }

    private func decodeRP2350LogicWords(from chunks: [RP2350LogicCaptureChunk]) -> [UInt32] {
        let sortedChunks = chunks.sorted { $0.offsetWords < $1.offsetWords }
        let totalWords = sortedChunks.map { $0.offsetWords + $0.words }.max() ?? 0
        guard totalWords > 0 else {
            return []
        }
        var words = [UInt32](repeating: 0, count: totalWords)
        for chunk in sortedChunks {
            let bytes = decodeHexBytes(chunk.hex)
            let chunkWords = min(chunk.words, bytes.count / 4)
            for index in 0..<chunkWords {
                let offset = index * 4
                let value = UInt32(bytes[offset]) |
                    (UInt32(bytes[offset + 1]) << 8) |
                    (UInt32(bytes[offset + 2]) << 16) |
                    (UInt32(bytes[offset + 3]) << 24)
                let target = chunk.offsetWords + index
                if target < words.count {
                    words[target] = value
                }
            }
        }
        return words
    }

    private func decodeHexBytes(_ hex: String) -> [UInt8] {
        let scalars = Array(hex.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(scalars.count / 2)
        var index = 0
        while index + 1 < scalars.count {
            if let high = hexNibble(scalars[index]),
               let low = hexNibble(scalars[index + 1]) {
                bytes.append((high << 4) | low)
            }
            index += 2
        }
        return bytes
    }

    private func hexNibble(_ char: UInt8) -> UInt8? {
        switch char {
        case 48...57:
            return char - 48
        case 65...70:
            return char - 55
        case 97...102:
            return char - 87
        default:
            return nil
        }
    }

    private func applyRP2350MonitorWiFi(_ wifi: [String: Any], to state: inout RP2350MonitorState) {
        let stationStatus = stringValue(wifi["station_status"]) ?? "unknown"
        let stationIP = stringValue(wifi["station_ip"]) ?? "0.0.0.0"
        let configured = boolValue(wifi["ssid_configured"]) ?? false
        let ssid = stringValue(wifi["ssid"]) ?? ""
        let apActive = boolValue(wifi["ap_active"]) ?? false
        let apSSID = stringValue(wifi["ap_ssid"]) ?? ""
        let apIP = stringValue(wifi["ap_ip"]) ?? "192.168.4.1"
        let activeProfile = intValue(wifi["active_profile"]) ?? 0

        let profiles = arrayOfDictionaries(wifi["profiles"]).compactMap { item -> RP2350MonitorWiFiProfile? in
            guard let slot = intValue(item["slot"]) else { return nil }
            return RP2350MonitorWiFiProfile(
                slot: slot,
                valid: boolValue(item["valid"]) ?? false,
                active: boolValue(item["active"]) ?? false,
                ssid: stringValue(item["ssid"]) ?? "",
                lastError: stringValue(item["last_error"]) ?? ""
            )
        }
        let scan = dictionary(wifi["scan"])
        let scanResults = arrayOfDictionaries(scan?["results"]).compactMap { item -> RP2350MonitorWiFiScanResult? in
            guard let ssid = stringValue(item["ssid"]), !ssid.isEmpty else { return nil }
            return RP2350MonitorWiFiScanResult(
                ssid: ssid,
                rssi: intValue(item["rssi"]) ?? 0,
                channel: intValue(item["channel"]) ?? 0,
                auth: intValue(item["auth"]) ?? 0
            )
        }

        let lastError = profiles.first(where: { $0.active })?.lastError
            ?? profiles.first(where: { !$0.lastError.isEmpty })?.lastError
            ?? ""

        state.wifiConfigured = configured
        state.wifiSSID = ssid
        state.wifiStationStatus = stationStatus
        state.wifiStationIP = stationIP
        state.wifiAPActive = apActive
        state.wifiAPSSID = apSSID
        state.wifiAPIP = apIP
        state.wifiTCPPort = "4242"
        state.wifiActiveProfile = activeProfile
        state.wifiLastError = lastError
        state.wifiProfiles = profiles
        state.wifiScanActive = boolValue(scan?["active"]) ?? false
        state.wifiScanResults = scanResults

        if state.wifiStationOnline {
            let label = ssid.isEmpty ? stationIP : "\(ssid) / \(stationIP)"
            state.wifiSummary = "\(label):\(state.wifiTCPPort)"
        } else if !configured {
            state.wifiSummary = "Wi-Fi 未配置"
        } else if apActive {
            let label = ssid.isEmpty ? "已配置" : ssid
            let ap = apSSID.isEmpty ? apIP : "\(apSSID) / \(apIP)"
            state.wifiSummary = "\(label) 未连接，AP \(ap)"
        } else {
            let label = ssid.isEmpty ? "Wi-Fi" : ssid
            state.wifiSummary = "\(label) \(stationStatus)"
        }
    }

    private func syncRP2350MonitorWiFiDefaults(from state: RP2350MonitorState) {
        if rp2350MonitorWiFiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !state.wifiSSID.isEmpty {
            rp2350MonitorWiFiSSID = state.wifiSSID
        }
        if rp2350MonitorWiFiSlot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rp2350MonitorWiFiSlot = "\(state.wifiActiveProfile)"
        }
        if state.wifiStationOnline {
            let currentHost = rp2350MonitorTCPHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldFillHost = rp2350MonitorTransportMode == "usb" ||
                currentHost.isEmpty ||
                currentHost == "192.168.4.1" ||
                currentHost == state.wifiAPIP ||
                currentHost == rp2350Monitor.wifiStationIP
            if shouldFillHost {
                rp2350MonitorTCPHost = state.wifiStationIP
            }
            if rp2350MonitorTCPPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                rp2350MonitorTCPPort == "4242" {
                rp2350MonitorTCPPort = state.wifiTCPPort
            }
        } else if !state.wifiConfigured, state.wifiAPActive {
            let currentHost = rp2350MonitorTCPHost.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentHost.isEmpty {
                rp2350MonitorTCPHost = state.wifiAPIP
            }
            if rp2350MonitorTCPPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rp2350MonitorTCPPort = state.wifiTCPPort
            }
        }
    }

    private func applyRP2350MonitorBuffers(_ buffers: [String: Any], to state: inout RP2350MonitorState) {
        let depth = intValue(buffers["event_depth"]) ?? state.eventDepth
        let capacity = intValue(buffers["event_capacity"]) ?? 128
        let dropped = intValue(buffers["dropped_events"]) ?? state.droppedEvents
        state.eventDepth = depth
        state.droppedEvents = dropped
        state.newestSeq = intValue(buffers["newest_seq"]) ?? state.newestSeq
        state.bufferSummary = "\(depth)/\(capacity)，丢弃 \(dropped)"
    }

    private func parseRP2350MonitorPins(from response: [String: Any]) -> [RP2350MonitorPin] {
        arrayOfDictionaries(response["pins"]).compactMap { item in
            guard let gpio = intValue(item["gpio"]) else { return nil }
            return RP2350MonitorPin(gpio: gpio, owner: intValue(item["owner"]) ?? 0)
        }
    }

    private func parseRP2350MonitorChannels(from response: [String: Any]) -> [RP2350MonitorChannel] {
        arrayOfDictionaries(response["channels"]).compactMap { item in
            guard let id = intValue(item["id"]) else { return nil }
            let type = stringValue(item["type"]) ?? "unknown"
            let active = boolValue(item["active"]) ?? false
            let detail = item
                .filter { !["id", "type", "active"].contains($0.key) }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\(stringValue($0.value) ?? String(describing: $0.value))" }
                .joined(separator: " / ")
            return RP2350MonitorChannel(id: id, type: type, active: active, detail: detail.isEmpty ? "-" : detail)
        }
    }

    private func dictionaryFromJSONLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private func arrayOfDictionaries(_ value: Any?) -> [[String: Any]] {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return []
    }

    private func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let array = value as? [Any] {
            return array.compactMap { stringValue($0) }
        }
        return []
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "1", "on", "high":
                return true
            case "false", "0", "off", "low":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    func rp2350SaveFlash() {
        let baseName = currentOperationRoute().boardID
            .flatMap { supportedBoard(for: $0)?.displayName }
            ?? detectedBoard?.displayName
            ?? "RP2350"
        let fileSafeBaseName = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let defaultName = "\(fileSafeBaseName)-flash-\(Self.fileSafeTimestamp()).uf2"
        browseSaveFile(defaultName: defaultName) { selectedPath in
            self.rp2350ReadbackPath = selectedPath
            Task {
                self.busy = true
                defer { self.busy = false }
                do {
                    try await self.queueRP2350Job(title: "Flash 回读", action: "save_flash", outputPath: selectedPath, successMessage: "Flash 回读任务已提交")
                } catch {
                    let detail = error.localizedDescription
                    self.presentInlineError(detail)
                    self.appendActivity(level: .error, title: "Flash 回读", message: "执行失败", detail: detail)
                }
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
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
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
                    throw ToolkitGUIError.commandFailed(localAgentUnavailableUserMessage())
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
        refreshStatus(silent: true, force: true)
    }

    func browseFile(allowedFileTypes: [String]? = nil, assign: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let allowedFileTypes, !allowedFileTypes.isEmpty {
            let allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
            if !allowedContentTypes.isEmpty {
                panel.allowedContentTypes = allowedContentTypes
            }
        }
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

    func browseSaveFile(defaultName: String, assign: @escaping (String) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
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
        struct ArtifactProfileManifest: Decodable {
            let official_image: String?
            let host_images: String?
            let official_workspace: String?
            let qt_host_tools: String?
            let llvm_release_bundle: String?
        }

        struct ArtifactManifest: Decodable {
            let official_image: String?
            let host_images: String?
            let official_workspace: String?
            let qt_host_tools: String?
            let llvm_release_bundle: String?
            let official_image_size_bytes: Int64?
            let host_images_size_bytes: Int64?
            let official_workspace_size_bytes: Int64?
            let qt_host_tools_size_bytes: Int64?
            let llvm_release_bundle_size_bytes: Int64?
            let docker: ArtifactProfileManifest?
            let local_llvm: ArtifactProfileManifest?
        }

        let directoryURL = URL(fileURLWithPath: path)
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        let fileManager = FileManager.default
        let directoryEntries = (try? fileManager.contentsOfDirectory(atPath: path).sorted()) ?? []
        var items: [LocalArtifactValidationItem] = []
        var manifest: ArtifactManifest?
        let selectedMode = taishanPiDevelopmentMode

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
            let profile = selectedMode == .macLLVM ? manifest?.local_llvm : manifest?.docker
            let imageCandidates = (profile?.official_image ?? manifest?.official_image).map { [$0] } ?? []
            let hostImageCandidates = (profile?.host_images ?? manifest?.host_images).map { [$0] } ?? []
            let workspaceCandidates = (profile?.official_workspace ?? profile?.llvm_release_bundle ?? manifest?.official_workspace ?? manifest?.llvm_release_bundle).map { [$0] } ?? []
            let qtCandidates = (profile?.qt_host_tools ?? manifest?.qt_host_tools).map { [$0] } ?? []
            if selectedMode == .macLLVM {
                list.append(("LLVM 镜像包", false, hostImageCandidates.isEmpty ? ["tspi-rk3566-llvm-images-*.tar.gz", "tspi-img-llvm-*.tar.gz", "tspi-img-*.tar.gz"] : hostImageCandidates, manifest?.host_images_size_bytes))
                list.append(("LLVM 发布/工作区包", true, workspaceCandidates.isEmpty ? ["tspi-rk3566-llvm-release-minimal-*.tar.gz", "tspi-rk3566-llvm-release-*.tar.gz", "llvm-workspace-*.tar.gz", "official-workspace-llvm-*.tar.gz"] : workspaceCandidates, manifest?.llvm_release_bundle_size_bytes ?? manifest?.official_workspace_size_bytes))
                list.append(("LLVM Qt 编译环境包", false, qtCandidates.isEmpty ? ["qt6-rk3566-llvm-*.tar.gz", "qt6Host-llvm-*.tar.gz", "qt6Host-*.tar.gz", "qt6host-*.tar.gz"] : qtCandidates, manifest?.qt_host_tools_size_bytes))
            } else {
                list.append(("共享镜像包", true, imageCandidates.isEmpty ? ["tspi-rk356x-env-*.tar.gz"] : imageCandidates, manifest?.official_image_size_bytes))
                list.append(("初始镜像包", true, hostImageCandidates.isEmpty ? ["tspi-img-*.tar.gz"] : hostImageCandidates, manifest?.host_images_size_bytes))
                list.append(("发布工作区包", true, workspaceCandidates.isEmpty ? ["official-workspace-*.tar.gz"] : workspaceCandidates, manifest?.official_workspace_size_bytes))
                list.append(("Qt 编译环境包", false, qtCandidates.isEmpty ? ["qt6Host-*.tar.gz", "qt6host-*.tar.gz"] : qtCandidates, manifest?.qt_host_tools_size_bytes))
            }
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
            summary: ready ? "\(selectedMode.title) 本地资源校验通过" : "\(selectedMode.title) 本地资源校验未通过",
            items: items,
            failureDetail: failureLines
        )
    }

    var fullDevelopmentEnvironmentReady: Bool {
        switch taishanPiDevelopmentMode {
        case .dockerLinux:
            developmentInstallStatus.dockerEnvironmentReady
        case .macLLVM:
            developmentInstallStatus.llvmEnvironmentReady
        }
    }

    var developmentInstallHeadline: String {
        switch taishanPiDevelopmentMode {
        case .dockerLinux:
            if developmentInstallStatus.dockerEnvironmentReady {
                return "Linux GCC 环境已完整就绪"
            }
            if developmentInstallStatus.dockerEnvironmentPartial {
                return "Linux GCC 环境部分已就绪"
            }
            return "Linux GCC 环境未就绪"
        case .macLLVM:
            if developmentInstallStatus.llvmEnvironmentReady {
                return "Mac LLVM 环境已完整就绪"
            }
            if developmentInstallStatus.llvmEnvironmentPartial {
                return "Mac LLVM 环境部分已就绪"
            }
            return "Mac LLVM 环境未就绪"
        }
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
        AppStrings.productName
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else {
            return
        }
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.defaultsKey)
        appendActivity(
            level: .info,
            title: AppStrings.localized("设置", language: language),
            message: AppStrings.localized("语言已切换为 \(language.displayTitle)", language: language)
        )
    }

    var supportedBoards: [SupportedBoard] {
        boardCatalog
    }

    func supportedBoard(for boardID: String?) -> SupportedBoard? {
        guard let boardID = localBoardID(forPluginBoardID: boardID) else {
            return nil
        }
        return supportedBoards.first(where: { $0.id == boardID })
    }

    func stableBoardDisplayName(for boardID: String?, variantID: String? = nil) -> String? {
        guard let board = supportedBoard(for: boardID) else {
            return boardID
        }
        if let variantID,
           !variantID.isEmpty,
           variantID != board.id,
           variantID != board.displayName,
           variantID != board.modelDirectoryName
        {
            return board.conciseModelLabel
        }
        return board.conciseModelLabel
    }

    private var stableConnectedDeviceCandidates: [DetectedBoardCandidate] {
        var deduped: [String: DetectedBoardCandidate] = [:]

        let statusDevices: [ToolkitStatus.Device]
        if let devices = status?.devices, !devices.isEmpty {
            statusDevices = devices
        } else if let device = status?.device {
            statusDevices = [device]
        } else {
            statusDevices = []
        }

        for device in statusDevices where device.connected == true {
            guard let deviceID = device.device_id, !deviceID.isEmpty,
                  let boardID = device.board_id, !boardID.isEmpty else {
                continue
            }
            let variantID = device.variant_id
            let displayName =
                device.display_label ??
                device.display_name ??
                supportedBoard(for: boardID)?.displayName ??
                boardID
            let manufacturer =
                device.manufacturer ??
                supportedBoard(for: boardID)?.manufacturer ??
                "未知厂家"
            let interfaceName =
                device.interface_name ??
                device.transport_locator ??
                "设备接口"
            let transportName =
                device.transport_name ??
                device.transport_locator ??
                "设备连接"
            let candidate = DetectedBoardCandidate(
                id: deviceID,
                deviceID: deviceID,
                boardID: boardID,
                variantID: variantID,
                displayName: displayName,
                manufacturer: manufacturer,
                interfaceName: interfaceName,
                transportName: transportName,
                transportLocator: device.transport_locator,
                sourceName: device.source_name ?? "状态服务",
                priority: 200
            )
            deduped[deviceID] = candidate
        }

        return deduped.values.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.selectionLabel.localizedCaseInsensitiveCompare(rhs.selectionLabel) == .orderedAscending
            }
            return lhs.priority > rhs.priority
        }
    }

    var currentLiveCandidate: DetectedBoardCandidate? {
        let candidates = stableConnectedDeviceCandidates
        if let preferredControlDeviceID,
           let candidate = candidates.first(where: { $0.deviceID == preferredControlDeviceID })
        {
            return candidate
        }
        if let selectedDetectedCandidateID,
           let candidate = candidates.first(where: { $0.id == selectedDetectedCandidateID })
        {
            return candidate
        }
        return candidates.first
    }

    var liveDetectedBoard: SupportedBoard? {
        supportedBoard(for: currentLiveCandidate?.boardID)
    }

    var detectedBoard: SupportedBoard? {
        supportedBoard(for: connectedBoardID)
    }

    var controlPageIsTaishanPi: Bool {
        let boardID = preferredControlBoardID ??
            connectedBoardID ??
            currentControlCandidate?.boardID ??
            liveDetectedBoard?.id ??
            status?.device?.board_id
        return boardMatches(boardID, targetBoardID: "TaishanPi")
    }

    var preferredControlBoard: SupportedBoard? {
        supportedBoard(for: preferredControlBoardID)
    }

    var heroTargetBoard: SupportedBoard? {
        preferredControlBoard
    }

    var currentControllableLiveCandidate: DetectedBoardCandidate? {
        guard let candidate = currentLiveCandidate,
              isBoardPluginInstalled(candidate.boardID) || isBoardIntegrationBundled(candidate.boardID) else {
            return nil
        }
        return candidate
    }

    var catalogHeroControlBoard: SupportedBoard? {
        if let preferredControlBoard {
            return preferredControlBoard
        }
        guard let candidate = currentControllableLiveCandidate else {
            return nil
        }
        return supportedBoard(for: candidate.boardID)
    }

    var currentControlCandidate: DetectedBoardCandidate? {
        let candidates = stableConnectedDeviceCandidates
        if let preferredControlDeviceID,
           let candidate = candidates.first(where: { $0.deviceID == preferredControlDeviceID }) {
            return candidate
        }
        if let preferredControlBoardID,
           let candidate = candidates.first(where: { boardMatches($0.boardID, targetBoardID: preferredControlBoardID) }) {
            return candidate
        }
        if preferredControlBoardID != nil || connectedBoardID != nil {
            return nil
        }
        return currentLiveCandidate
    }

    var activeControlDeviceSelectionID: String {
        currentControlCandidate?.deviceID ?? preferredControlDeviceID ?? ""
    }

    var activeControlDeviceCandidates: [DetectedBoardCandidate] {
        stableConnectedDeviceCandidates
    }

    var onlineConnectedDeviceCount: Int {
        if let devices = status?.devices, !devices.isEmpty {
            var ids = Set<String>()
            for device in devices where device.connected == true {
                if let deviceID = device.device_id, !deviceID.isEmpty {
                    ids.insert(deviceID)
                } else {
                    let boardID = device.board_id ?? "unknown"
                    let locator = device.transport_locator ?? device.interface_name ?? boardID
                    ids.insert("\(boardID)::\(locator)")
                }
            }
            if !ids.isEmpty {
                return ids.count
            }
        }
        return 0
    }

    var activeControlDeviceMenuLabel: String {
        guard let candidate = currentControlCandidate else {
            return "选择设备"
        }
        return activeControlDisplayLabel(for: candidate)
    }

    func activeControlDisplayLabel(for candidate: DetectedBoardCandidate) -> String {
        let duplicates = activeControlDeviceCandidates.filter { $0.conciseLabel == candidate.conciseLabel }
        guard duplicates.count > 1 else {
            return candidate.conciseLabel
        }
        if let shortTransportLabel = candidate.shortTransportLabel, !shortTransportLabel.isEmpty {
            return "\(candidate.conciseLabel) / \(shortTransportLabel)"
        }
        if let deviceID = candidate.deviceID, !deviceID.isEmpty {
            return "\(candidate.conciseLabel) / \(String(deviceID.suffix(8)))"
        }
        return candidate.conciseLabel
    }

    private func boardMatches(_ candidateBoardID: String?, targetBoardID: String) -> Bool {
        let localCandidateID = localBoardID(forPluginBoardID: candidateBoardID) ?? candidateBoardID
        let localTargetID = localBoardID(forPluginBoardID: targetBoardID) ?? targetBoardID
        return localCandidateID == localTargetID
    }

    func rp2350StatusContext(for board: SupportedBoard) -> RP2350BoardStatusContext {
        let targetBoardID = board.id
        let devices = (status?.devices ?? []).filter {
            ($0.connected == true) && boardMatches($0.board_id, targetBoardID: targetBoardID)
        }
        let selectedDevice: ToolkitStatus.Device? = {
            if let preferredControlDeviceID,
               let exact = devices.first(where: { $0.device_id == preferredControlDeviceID }) {
                return exact
            }
            return devices.first
        }()

        let rpBoardID = localBoardID(forPluginBoardID: status?.rp2350?.board_id) ?? status?.rp2350?.board_id
        let exactRPContext = rpBoardID == targetBoardID
        let inferredState: String
        if exactRPContext {
            let rawState = (status?.rp2350?.state ?? "").lowercased()
            switch rawState {
            case "runtime-resettable", "rp2350-runtime":
                inferredState = "运行态"
            case "bootsel", "rp2350-bootsel":
                inferredState = "BOOTSEL"
            case "not-found", "absent", "":
                inferredState = "未连接"
            default:
                inferredState = rawState
            }
        } else {
            let transportPieces = [
                selectedDevice?.transport_name,
                selectedDevice?.interface_name,
                selectedDevice?.display_label,
            ].compactMap { $0?.lowercased() }
            let transportText = transportPieces.joined(separator: " ")
            if transportText.contains("bootsel") {
                inferredState = "BOOTSEL"
            } else if !transportText.isEmpty {
                inferredState = "运行态"
            } else {
                inferredState = "未连接"
            }
        }

        let runtimePort: String = {
            if exactRPContext {
                return status?.rp2350?.runtime_port?.device
                    ?? selectedDevice?.interface_name
                    ?? "-"
            }
            return selectedDevice?.transport_locator
                ?? selectedDevice?.interface_name
                ?? "-"
        }()

        let connectionLabel: String = {
            selectedDevice?.transport_name
                ?? selectedDevice?.interface_name
                ?? "等待连接"
        }()

        let summary: String = {
            if exactRPContext {
                return status?.rp2350?.summary_for_user
                    ?? status?.summary
                    ?? "等待检测 \(board.displayName) 状态"
            }
            if let selectedDevice {
                let interfaceText = selectedDevice.interface_name
                    ?? selectedDevice.transport_name
                    ?? "RP2350 单 USB"
                return "\(board.displayName) 已连接，接口：\(interfaceText)"
            }
            return "等待检测 \(board.displayName) 状态"
        }()

        return RP2350BoardStatusContext(
            connected: selectedDevice != nil || (exactRPContext && status?.rp2350?.connected == true),
            connectionLabel: connectionLabel,
            stateLabel: inferredState,
            runtimePort: runtimePort,
            summary: summary
        )
    }

    func activeControlTooltip(for candidate: DetectedBoardCandidate) -> String {
        var lines: [String] = []
        lines.append(candidate.conciseLabel)
        lines.append("厂家：\(candidate.manufacturer)")
        lines.append("连接：\(candidate.transportName)")
        if let transportLocator = candidate.transportLocator, !transportLocator.isEmpty {
            lines.append("位置：\(transportLocator)")
        }
        if let deviceID = candidate.deviceID, !deviceID.isEmpty {
            lines.append("设备 ID：\(deviceID)")
        }
        return lines.joined(separator: "\n")
    }

    var heroTargetDisplayName: String? {
        if let connectedBoardDisplayName, !connectedBoardDisplayName.isEmpty, detectedBoard != nil {
            return connectedBoardDisplayName
        }
        guard let board = heroTargetBoard ?? liveDetectedBoard else {
            return nil
        }
        return board.conciseModelLabel
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
        if let candidate = currentControlCandidate {
            return stableBoardDisplayName(for: candidate.boardID, variantID: candidate.variantID) ?? candidate.conciseLabel
        }
        if let connectedBoardDisplayName, !connectedBoardDisplayName.isEmpty {
            return connectedBoardDisplayName
        }
        guard let board = detectedBoard ?? liveDetectedBoard else {
            return nil
        }
        return board.conciseModelLabel
    }

    var controlPageBoardTitle: String {
        if let stable = stableBoardDisplayName(for: connectedBoardID, variantID: connectedBoardVariantID) {
            return stable
        }
        if let stable = stableBoardDisplayName(for: preferredControlBoardID) {
            return stable
        }
        if let board = detectedBoard ?? supportedBoard(for: preferredControlBoardID) ?? supportedBoard(for: connectedBoardID) ?? liveDetectedBoard {
            return board.conciseModelLabel
        }
        return detectedHardwareDisplayName ?? "开发板"
    }

    var controlPageManufacturerText: String? {
        if let manufacturer = currentControlCandidate?.manufacturer,
           !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return manufacturer
        }
        let board = detectedBoard ??
            supportedBoard(for: preferredControlBoardID) ??
            supportedBoard(for: connectedBoardID) ??
            liveDetectedBoard
        return board?.manufacturer
    }

    var isWaitingForHardware: Bool {
        detectedBoardCandidates.isEmpty
    }

    var isShowingBoardCatalog: Bool {
        showingSupportedBoardCatalog || (preferredControlBoardID == nil && connectedBoardID == nil)
    }

    var heroState: ToolkitHeroState {
        if !isShowingBoardCatalog {
            if currentControlCandidate != nil || controlPageHasMatchingLiveSignal() {
                return .deviceReady
            }
            if preferredControlBoardID != nil || connectedBoardID != nil || detectedBoard != nil {
                return .deviceClose
            }
            return .pluginHub
        }
        guard heroTargetBoard != nil else {
            return currentControllableLiveCandidate != nil ? .deviceReady : .pluginHub
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
        if isShowingBoardCatalog {
            return catalogHeroControlBoard != nil
        }
        return true
    }

    var heroActionHint: String {
        if isShowingBoardCatalog {
            if preferredControlBoard != nil {
                return "点击进入当前控制页面"
            }
            if currentControllableLiveCandidate != nil {
                return "点击进入当前在线设备控制页面"
            }
            return ""
        }
        if !isShowingBoardCatalog {
            return "点击返回初始化列表"
        }
        return ""
    }

    var headerSubtitle: String {
        if !isShowingBoardCatalog {
            if let manufacturer = controlPageManufacturerText,
               !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(controlPageBoardTitle) · \(manufacturer)"
            }
            return controlPageBoardTitle
        }
        if activeControlDeviceCandidates.count > 1 {
            let current = currentControlCandidate?.conciseLabel ?? detectedHardwareDisplayName ?? "当前设备"
            return "当前 \(onlineConnectedDeviceCount) 台 · 当前激活设备：\(current)"
        }
        if onlineConnectedDeviceCount > 0, let liveCandidate = currentLiveCandidate {
            let prefix = "当前 \(onlineConnectedDeviceCount) 台 · "
            let liveLabel = stableBoardDisplayName(for: liveCandidate.boardID, variantID: liveCandidate.variantID) ?? liveCandidate.conciseLabel
            return "\(prefix)当前在线：\(liveLabel) · \(liveCandidate.manufacturer)"
        }
        if let board = heroTargetBoard, preferredControlBoardID != nil || connectedBoardID != nil {
            let prefix = onlineConnectedDeviceCount > 0 ? "当前 \(onlineConnectedDeviceCount) 台 · " : ""
            return "\(prefix)\(heroTargetDisplayName ?? board.displayName) · \(heroTargetMatchesLiveBoard ? "在线" : "设备未连接")"
        }
        if let board = liveDetectedBoard {
            let prefix = onlineConnectedDeviceCount > 0 ? "当前 \(onlineConnectedDeviceCount) 台 · " : ""
            return "\(prefix)当前已识别：\(detectedHardwareDisplayName ?? board.displayName) · \(board.manufacturer)"
        }
        return "请连接硬件设备，目前支持的硬件设备如下列表："
    }

    private func isRP2350SingleUSBMode(_ mode: String) -> Bool {
        let lower = mode.lowercased()
        return lower.contains("rp2350") ||
            lower.contains("single-usb") ||
            lower.contains("singleusb") ||
            lower.contains("uf2-serial") ||
            (lower.contains("uf2") && lower.contains("serial"))
    }

    var deviceConnectionText: String {
        if taishanLoaderTransitionActive,
           controlPageBoardFamily() == .taishanPi || boardLogicFamily(status: status) == .taishanPi {
            return "正在进入 Loader"
        }
        if let targetBoardID = controlPageTargetBoardID {
            if isRP2350BoardID(targetBoardID) {
                guard controlPageHasMatchingLiveSignal() else {
                    return "等待连接"
                }
                let mode = (status?.rp2350?.state ?? status?.usb?.mode ?? "absent").lowercased()
                if mode == "bootsel" || mode == "rp2350-bootsel" {
                    return "BOOTSEL USB"
                }
                if mode == "runtime-resettable" || mode == "rp2350-runtime" || isRP2350SingleUSBMode(mode) {
                    return "RP2350 单 USB"
                }
                return "等待连接"
            }
            if boardMatches(targetBoardID, targetBoardID: "TaishanPi") {
                guard controlPageHasMatchingLiveSignal() else {
                    return "等待连接"
                }
                let mode = (status?.usb?.mode ?? "absent").lowercased()
                switch mode {
                case "loader":
                    return "Loader 模式"
                case "maskrom":
                    return "Maskrom 模式"
                case "usb-ecm":
                    return status?.usbnet?.configured == true ? "USB 网口已连接" : "USB 网口待配置"
                case "rockchip-other":
                    return "USB 已连接"
                case "absent", "":
                    return "等待连接"
                default:
                    return status?.usb?.mode ?? "待识别"
                }
            }
        }

        if isRP2350BoardID(currentControlCandidate?.boardID) || isRP2350BoardID(preferredControlBoardID) || isRP2350BoardID(connectedBoardID) {
            let mode = (status?.rp2350?.state ?? status?.usb?.mode ?? "absent").lowercased()
            if mode == "bootsel" || mode == "rp2350-bootsel" {
                return "BOOTSEL USB"
            }
            if mode == "runtime-resettable" || mode == "rp2350-runtime" || isRP2350SingleUSBMode(mode) {
                return "RP2350 单 USB"
            }
            if mode == "not-found" || mode == "absent" || mode.isEmpty {
                return "等待连接"
            }
            return "等待连接"
        }
        if let transport = status?.device?.transport_name, !transport.isEmpty {
            return transport
        }
        let mode = (status?.usb?.mode ?? "absent").lowercased()
        if isRP2350SingleUSBMode(mode) {
            return "RP2350 单 USB"
        }
        switch mode {
        case "loader":
            return "Loader 模式"
        case "maskrom":
            return "Maskrom 模式"
        case "usb-ecm":
            return status?.usbnet?.configured == true ? "USB 网口已连接" : "USB 网口待配置"
        case "rockchip-other":
            return "USB 已连接"
        case let value where value.contains("uf2"):
            return "UF2 刷写"
        case "absent":
            return "等待连接"
        default:
            return status?.usb?.mode ?? "待识别"
        }
    }

    var deviceReachabilityText: String {
        if taishanLoaderTransitionActive,
           controlPageBoardFamily() == .taishanPi || boardLogicFamily(status: status) == .taishanPi {
            return taishanLoaderTransitionHint
        }
        if let targetBoardID = controlPageTargetBoardID {
            if isRP2350BoardID(targetBoardID) {
                guard controlPageHasMatchingLiveSignal() else {
                    return "等待连接"
                }
                let rpState = (status?.rp2350?.state ?? status?.usb?.mode ?? "not-found").lowercased()
                if rpState == "bootsel" || rpState == "rp2350-bootsel" {
                    return "BOOTSEL 已就绪"
                }
                if rpState == "runtime-resettable" || rpState == "rp2350-runtime" || isRP2350SingleUSBMode(rpState) {
                    return "UF2 / 串口已就绪"
                }
                return "等待连接"
            }
            if boardMatches(targetBoardID, targetBoardID: "TaishanPi") {
                guard controlPageHasMatchingLiveSignal() else {
                    return "等待连接"
                }
                if taishanUSBECMTransportOnly() {
                    return "USB ECM 已枚举，板端未响应"
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
                if (status?.usb?.mode ?? "").lowercased() == "loader" {
                    return "Loader 已就绪，可直接刷写"
                }
                if (status?.usb?.mode ?? "").lowercased() == "maskrom" {
                    return "Maskrom 已就绪，将先拉起 Loader"
                }
                if (status?.usb?.mode ?? "").lowercased() == "usb-ecm" {
                    return status?.usbnet?.configured == true ? "USB 网口已连接" : "USB 网口待配置"
                }
                return "已检测到设备"
            }
        }

        if isRP2350BoardID(currentControlCandidate?.boardID) || isRP2350BoardID(preferredControlBoardID) || isRP2350BoardID(connectedBoardID) {
            let rpState = (status?.rp2350?.state ?? status?.usb?.mode ?? "not-found").lowercased()
            if rpState == "bootsel" || rpState == "rp2350-bootsel" {
                return "BOOTSEL 已就绪"
            }
            if rpState == "runtime-resettable" || rpState == "rp2350-runtime" || isRP2350SingleUSBMode(rpState) {
                return "UF2 / 串口已就绪"
            }
            return "等待连接"
        }
        guard liveDetectedBoard != nil else {
            return "未连接任何硬件设备"
        }
        if status?.device?.transport_name == "RP2350 单 USB" {
            if (status?.rp2350?.state ?? "").lowercased() == "bootsel" {
                return "BOOTSEL 已就绪"
            }
            return "UF2 / 串口已就绪"
        }
        if taishanUSBECMTransportOnly() {
            return "USB ECM 已枚举，板端未响应"
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
        if isRP2350SingleUSBMode(status?.usb?.mode ?? "") || (status?.usb?.mode ?? "").lowercased().contains("uf2") {
            return "UF2 / 串口已就绪"
        }
        if status?.usb?.mode == "loader" {
            return "Loader 已就绪，可直接刷写"
        }
        if status?.usb?.mode == "maskrom" {
            return "Maskrom 已就绪，将先拉起 Loader"
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

    var statusHeadline: String {
        if activeControlDeviceCandidates.count > 1 {
            return "检测到多个设备，可切换当前控制设备"
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
        if isRP2350BoardID(status?.device?.board_id) {
            let rpState = (status?.rp2350?.state ?? "").lowercased()
            if rpState == "runtime-resettable" {
                return .green
            }
            if rpState == "bootsel" {
                return .blue
            }
        }
        switch status?.usb?.mode ?? "absent" {
        case "loader", "maskrom":
            return .blue
        case "usb-ecm":
            if taishanUSBECMTransportOnly() {
                return .orange
            }
            if boardLogicFamily(status: status) == .taishanPi {
                return (status?.board?.ssh_port_open == true || status?.board?.control_service == true) ? .green : .orange
            }
            return status?.board?.ping == true ? .green : .orange
        case "absent":
            return .secondary
        default:
            return .orange
        }
    }
}

struct StatusCard: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let value: String
    let ok: Bool
    let symbol: String
    let helpText: String?
    let actionLabel: String?
    let onTap: (() -> Void)?
    let tapFeedback: String?
    @State private var hovering = false
    @State private var showTapFeedback = false

    init(
        title: String,
        value: String,
        ok: Bool,
        symbol: String = "circle.grid.2x2.fill",
        helpText: String? = nil,
        actionLabel: String? = nil,
        onTap: (() -> Void)? = nil,
        tapFeedback: String? = nil
    ) {
        self.title = title
        self.value = value
        self.ok = ok
        self.symbol = symbol
        self.helpText = helpText
        self.actionLabel = actionLabel
        self.onTap = onTap
        self.tapFeedback = tapFeedback
    }

    private var statusTint: Color {
        ok ? .green : .orange
    }

    private var isInteractive: Bool {
        onTap != nil
    }

    private var baseBorderColor: Color {
        ok ? Color.green.opacity(0.38) : Color.orange.opacity(0.40)
    }

    private var baseBackgroundColor: Color {
        ok ? Color.green.opacity(0.10) : Color.orange.opacity(0.12)
    }

    private var cardBorderColor: Color {
        if isInteractive {
            return hovering ? Color.accentColor.opacity(0.58) : baseBorderColor.opacity(0.95)
        }
        return baseBorderColor
    }

    private var cardBackground: Color {
        if isInteractive {
            return hovering ? Color.accentColor.opacity(0.12) : baseBackgroundColor
        }
        return baseBackgroundColor
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if showTapFeedback, let tapFeedback {
            statusBadge(
                text: tapFeedback,
                foreground: Color.accentColor,
                background: Color.accentColor.opacity(0.14),
                border: Color.accentColor.opacity(0.30),
                systemImage: "checkmark"
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else if isInteractive, let actionLabel {
            statusBadge(
                text: actionLabel,
                foreground: hovering ? Color.accentColor : Color.secondary,
                background: hovering ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05),
                border: hovering ? Color.accentColor.opacity(0.26) : Color.primary.opacity(0.10),
                systemImage: hovering ? "arrow.up.right" : "hand.tap"
            )
            .transition(.opacity)
        }
    }

    private func statusBadge(
        text: String,
        foreground: Color,
        background: Color,
        border: Color,
        systemImage: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(AppStrings.localized(text, language: appLanguage))
                .lineLimit(1)
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(background)
        .overlay(
            Capsule()
                .stroke(border, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var cardLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(AppStrings.localized(title, language: appLanguage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                trailingIndicator
            }
            Text(AppStrings.localized(value, language: appLanguage))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    var body: some View {
        Button {
            guard let onTap else { return }
            onTap()
            if tapFeedback != nil {
                withAnimation(.easeOut(duration: 0.16)) {
                    showTapFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showTapFeedback = false
                    }
                }
            }
        } label: {
            cardLabel
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cardBorderColor, lineWidth: onTap != nil ? 1.2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(hovering && isInteractive ? 1.016 : 1.0)
            .shadow(color: Color.black.opacity(hovering && isInteractive ? 0.10 : 0.03), radius: hovering && isInteractive ? 6 : 4, x: 0, y: 2)
            .animation(.easeOut(duration: 0.16), value: hovering)
        }
        .buttonStyle(.plain)
        .help(AppStrings.localized(helpText ?? value, language: appLanguage))
        .onHover { inside in
            hovering = inside
        }
    }
}

struct ActionTile: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let subtitle: String
    let enabled: Bool
    let disabledReason: String?
    let helpText: String?
    let action: () -> Void
    let symbol: String
    var compact: Bool = false
    @State private var hovering = false

    init(
        title: String,
        subtitle: String,
        enabled: Bool,
        disabledReason: String? = nil,
        helpText: String? = nil,
        symbol: String = "bolt.circle.fill",
        action: @escaping () -> Void,
        compact: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.enabled = enabled
        self.disabledReason = disabledReason
        self.helpText = helpText
        self.symbol = symbol
        self.action = action
        self.compact = compact
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 12 : 14, weight: .semibold))
                        .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                    Text(AppStrings.localized(title, language: appLanguage))
                        .font((compact ? Font.system(size: 12, weight: .semibold) : .subheadline.weight(.semibold)))
                        .lineLimit(1)
                        .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    Spacer(minLength: 0)
                    if hovering && enabled {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .transition(.opacity)
                    }
                }
                if !compact {
                    Text(AppStrings.localized(subtitle, language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    if let disabledReason, !enabled {
                        Text(AppStrings.localized(disabledReason, language: appLanguage))
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
                    .stroke(borderColor, lineWidth: 1.2)
            )
            .opacity(enabled ? 1 : 0.72)
            .scaleEffect(hovering && enabled ? 1.015 : 1.0)
            .animation(.easeOut(duration: 0.16), value: hovering)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(AppStrings.localized(disabledReason ?? helpText ?? subtitle, language: appLanguage))
        .onHover { hovering in
            self.hovering = hovering
        }
    }

    private var backgroundColor: Color {
        if !enabled {
            return Color.secondary.opacity(0.12)
        }
        if hovering {
            return Color.accentColor.opacity(0.12)
        }
        return Color.toolkitPanelBackground
    }

    private var borderColor: Color {
        if !enabled {
            return Color.orange.opacity(0.22)
        }
        return hovering ? Color.accentColor.opacity(0.30) : Color.primary.opacity(0.12)
    }
}

struct ActivityRow: View {
    @Environment(\.appLanguage) private var appLanguage
    let entry: ActivityEntry
    let onDetail: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.level.symbol)
                .foregroundStyle(entry.level.color)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(AppStrings.localized(entry.title, language: appLanguage))
                        .font(.headline)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(AppStrings.localized(entry.message, language: appLanguage))
                    .font(.subheadline)
                if entry.detail != nil {
                    Button(AppStrings.localized("查看详情", language: appLanguage), action: onDetail)
                        .buttonStyle(.link)
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(Color.toolkitPanelBackground)
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

    private var taishanConnected: Bool {
        vm.activeControlDeviceCandidates.contains {
            (vm.supportedBoard(for: $0.boardID)?.id ?? $0.boardID) == "TaishanPi"
        }
    }

    private var taishanUSBModeText: String {
        taishanConnected ? (vm.status?.usb?.mode ?? "-") : "等待连接"
    }

    private var taishanUSBProductText: String {
        taishanConnected ? (vm.status?.usb?.product ?? "-") : "-"
    }

    private var taishanUSBNetReady: Bool {
        taishanConnected && vm.status?.usbnet?.configured == true
    }

    private var taishanTransportOnlyWarning: Bool {
        taishanConnected && vm.taishanUSBECMTransportOnly()
    }

    private var taishanBoardResponsive: Bool {
        taishanConnected &&
            !taishanTransportOnlyWarning &&
            (vm.status?.board?.control_service == true ||
             vm.status?.board?.ssh_port_open == true ||
             vm.status?.board?.ping == true)
    }

    private var taishanBoardResponseText: String {
        guard taishanConnected else {
            return "等待连接"
        }
        if taishanTransportOnlyWarning {
            return "未应答"
        }
        return taishanBoardResponsive ? "已就绪" : "离线"
    }

    private var taishanBoardResponseHelpText: String {
        if taishanTransportOnlyWarning {
            return "当前仅检测到 USB ECM 枚举，板端没有响应 Ping / SSH / 控制服务。"
        }
        return taishanBoardResponsive ? "板端运行态链路可用" : "当前未检测到板端有效响应"
    }

    private var taishanSSHReady: Bool {
        taishanConnected && vm.status?.board?.ssh_port_open == true
    }

    private var taishanControlReady: Bool {
        taishanConnected && vm.status?.board?.control_service == true
    }

    private var taishanControlChannelReady: Bool {
        taishanControlReady || taishanSSHReady
    }

    private var taishanControlChannelText: String {
        taishanControlChannelReady ? "正常" : "异常"
    }

    private var taishanControlChannelHelpText: String {
        if taishanControlReady {
            return "USB 控制服务正常，可直接请求重启、进入 Loader 或执行刷写前置切换。"
        }
        if taishanSSHReady {
            return "USB 控制服务未响应，但 SSH 正常；重启、切换 Loader 和刷写前置切换会使用 SSH fallback。"
        }
        return "控制服务和 SSH 均不可用，运行态控制操作会被阻止。"
    }

    private var taishanCompileEnvironmentReady: Bool {
        switch vm.taishanPiDevelopmentMode {
        case .dockerLinux:
            return vm.developmentInstallStatus.dockerEnvironmentReady
        case .macLLVM:
            return vm.developmentInstallStatus.llvmEnvironmentReady
        }
    }

    private var taishanCompileEnvironmentText: String {
        switch vm.taishanPiDevelopmentMode {
        case .dockerLinux:
            return vm.developmentInstallStatus.dockerEnvironmentReady ? "Linux GCC 正常" : "Linux GCC 异常"
        case .macLLVM:
            return vm.developmentInstallStatus.llvmEnvironmentReady ? "Mac LLVM 正常" : "Mac LLVM 异常"
        }
    }

    private var taishanCompileEnvironmentHelpText: String {
        switch vm.taishanPiDevelopmentMode {
        case .dockerLinux:
            return vm.developmentInstallStatus.dockerEnvironmentReady
                ? "当前选择 Linux GCC，已检测到 Docker、共享镜像、发布工作区、镜像缓存和刷写工具。"
                : "当前选择 Linux GCC，需要 Docker、共享镜像、发布工作区、镜像缓存和刷写工具全部就绪。"
        case .macLLVM:
            return vm.developmentInstallStatus.llvmEnvironmentReady
                ? "当前选择 Mac LLVM，已检测到本地 LLVM/Qt 工具链和 Mac LLVM 初始镜像；用户镜像会在构建同步后进入独立目录。"
                : "当前选择 Mac LLVM，需要本地 LLVM/Qt 工具链和 Mac LLVM 初始镜像就绪；此模式不要求 Docker。"
        }
    }

    private var checkHostSubtitle: String {
        switch vm.taishanPiDevelopmentMode {
        case .dockerLinux:
            return "检查 Linux GCC、Docker、镜像和刷机工具状态"
        case .macLLVM:
            return "检查 Mac LLVM、本地镜像和刷机工具状态"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        Text(vm.usbNetHelperWarningText)
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

            if taishanTransportOnlyWarning {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开发板运行态未响应")
                            .font(.subheadline.weight(.semibold))
                        Text(vm.taishanUSBECMTransportOnlyWarningText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            LazyVGrid(columns: statusColumns, spacing: 6) {
                StatusCard(title: "USB 模式", value: taishanUSBModeText, ok: taishanConnected, symbol: "cable.connector")
                StatusCard(title: "USB 设备", value: taishanUSBProductText, ok: taishanConnected, symbol: "externaldrive")
                StatusCard(title: "主机网口", value: taishanConnected ? (vm.status?.usbnet?.iface ?? "-") : "-", ok: taishanUSBNetReady, symbol: "network")
                StatusCard(
                    title: "设备 IP",
                    value: taishanConnected ? (vm.status?.usbnet?.board_ip ?? "-") : "-",
                    ok: taishanUSBNetReady,
                    symbol: "point.3.connected.trianglepath.dotted",
                    helpText: "点击复制开发板 IP 地址",
                    actionLabel: "复制",
                    onTap: taishanUSBNetReady ? { vm.copyDeviceIPAddress() } : nil,
                    tapFeedback: "已复制"
                )
                StatusCard(
                    title: "板端响应",
                    value: taishanBoardResponseText,
                    ok: taishanBoardResponsive,
                    symbol: "dot.radiowaves.left.and.right",
                    helpText: taishanBoardResponseHelpText
                )
                StatusCard(
                    title: "SSH",
                    value: taishanSSHReady ? "可连接" : "未连接",
                    ok: taishanSSHReady,
                    symbol: "terminal",
                    helpText: taishanSSHReady ? "点击打开终端连接" : "当前 SSH 尚未恢复",
                    actionLabel: "打开",
                    onTap: taishanSSHReady ? { vm.promptOpenSSHTerminal() } : nil
                )
                StatusCard(
                    title: "控制链路",
                    value: taishanControlChannelText,
                    ok: taishanControlChannelReady,
                    symbol: "switch.2",
                    helpText: taishanControlChannelHelpText
                )
                StatusCard(
                    title: "编译环境",
                    value: taishanCompileEnvironmentText,
                    ok: taishanCompileEnvironmentReady,
                    symbol: vm.taishanPiDevelopmentMode == .macLLVM ? "apple.terminal" : "shippingbox",
                    helpText: taishanCompileEnvironmentHelpText
                )
            }

            GroupBox("连接与准备") {
                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionTile(title: "主机预检", subtitle: checkHostSubtitle, enabled: checkHostState.enabled, disabledReason: checkHostState.reason, symbol: "stethoscope") { vm.checkHost() }
                    ActionTile(title: "恢复 USB 网络", subtitle: "修复 USB ECM 重枚举后的主机静态 IP", enabled: ensureUSBNetState.enabled, disabledReason: ensureUSBNetState.reason, symbol: "point.3.filled.connected.trianglepath.dotted") { vm.ensureUSBNet() }
                    ActionTile(title: "授权 SSH", subtitle: "把当前电脑公钥写入开发板", enabled: authorizeKeyState.enabled, disabledReason: authorizeKeyState.reason, symbol: "key.horizontal") { vm.authorizeKey() }
                    ActionTile(title: "切换 Loader", subtitle: "通过控制服务或 SSH 让开发板进入 Loader", enabled: rebootLoaderState.enabled, disabledReason: rebootLoaderState.reason, symbol: "arrow.trianglehead.2.clockwise.rotate.90") { vm.rebootLoader() }
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
    @Environment(\.appLanguage) private var appLanguage

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            flashSection(
                title: "用户镜像刷写",
                source: .custom,
                emptyState: "未发现用户镜像，请先生成或导入。"
            )

            flashSection(
                title: vm.taishanPiDevelopmentMode == .macLLVM ? "Mac LLVM 初始镜像恢复" : "Linux GCC 初始镜像恢复",
                source: .factory,
                emptyState: vm.taishanPiDevelopmentMode == .macLLVM
                    ? "未发现 Mac LLVM 初始镜像，请先挂载或安装 Mac LLVM 离线环境包。"
                    : "缺少 Linux GCC 初始镜像时会先自动同步。"
            )

            rawImageFlashSection()
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
        let transportSummary = vm.flashTransportSummaryText()
        let stateText = summaryState?.reason ?? (hasImages ? transportSummary : emptyState)
        let dotColor = summaryState != nil ? Color.orange : vm.flashTransportIndicatorColor()
        let helpText = summaryState?.reason ?? stateText
        let actionHelpText = summaryState?.reason.map { localized($0) } ?? imageDir.path

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(localized(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .help(localized(helpText))
                    Spacer(minLength: 6)
                    Text(relativePathLabel(imageDir))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(imageDir.path)
                }

                Text(localized(stateText))
                    .font(.caption)
                    .foregroundStyle(summaryState != nil ? Color.orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ActionTile(
                        title: source == .custom ? "全部" : "恢复全部",
                        subtitle: "按 parameter 刷写全部分区",
                        enabled: flashAllState.enabled,
                        disabledReason: flashAllState.reason,
                        symbol: "externaldrive.badge.timemachine",
                        action: { vm.flash("all", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Boot",
                        subtitle: "仅刷 boot",
                        enabled: flashBootState.enabled,
                        disabledReason: flashBootState.reason,
                        symbol: "power.circle",
                        action: { vm.flash("boot", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Rootfs",
                        subtitle: "仅刷 rootfs",
                        enabled: flashRootfsState.enabled,
                        disabledReason: flashRootfsState.reason,
                        symbol: "internaldrive",
                        action: { vm.flash("rootfs", source: source) },
                        compact: true
                    )
                    ActionTile(
                        title: "Userdata",
                        subtitle: "仅刷 userdata",
                        enabled: flashUserdataState.enabled,
                        disabledReason: flashUserdataState.reason,
                        symbol: "externaldrive.fill.badge.person.crop",
                        action: { vm.flash("userdata", source: source) },
                        compact: true
                    )
                }
                .help(actionHelpText)
            }
            .padding(.top, 2)
        }
        .groupBoxStyle(.automatic)
    }

    @ViewBuilder
    private func rawImageFlashSection() -> some View {
        let flashState = vm.rawImageFlashAvailabilityState()
        let imagePath = vm.taishanPiRawImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImagePath = !imagePath.isEmpty
        let stateText = flashState.reason ?? (hasImagePath ? "已选择 IMG 镜像：" : "选择一个完整的 TaishanPi .img 镜像文件")
        let dotColor = flashState.enabled ? vm.flashTransportIndicatorColor() : Color.orange

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(localized("用户 IMG 镜像烧录"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .help(localized(flashState.reason ?? vm.flashTransportSummaryText()))
                    Spacer(minLength: 6)
                    Text(hasImagePath ? URL(fileURLWithPath: imagePath).lastPathComponent : localized("未选择 .img 镜像文件。"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(imagePath)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(stateText))
                        .font(.caption)
                        .foregroundStyle(flashState.reason == nil ? .secondary : Color.orange)
                    if hasImagePath {
                        Text(imagePath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(imagePath)
                    }
                    Text(localized("选择 .img 后由底层自动识别 RKFW/RKAF 或 raw 格式并执行全量刷写。"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(localized("会覆盖 eMMC 全部内容；请保持 USB 和供电连接，刷写期间窗口会持续显示进度。"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 6) {
                    ActionTile(
                        title: "选择 .img 文件",
                        subtitle: "选择一个完整的 TaishanPi .img 镜像文件",
                        enabled: true,
                        disabledReason: nil,
                        symbol: "doc.badge.plus",
                        action: { vm.browseFile(allowedFileTypes: ["img"]) { vm.taishanPiRawImagePath = $0 } },
                        compact: true
                    )
                    ActionTile(
                        title: "全量刷写 IMG",
                        subtitle: "按 .img 镜像执行整机刷写",
                        enabled: flashState.enabled,
                        disabledReason: flashState.reason,
                        symbol: "externaldrive.badge.timemachine",
                        action: { vm.flashSelectedRawImage() },
                        compact: true
                    )
                }
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

struct ColorEasyPICO2OverviewTab: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard
    @Environment(\.appLanguage) private var appLanguage
    private let statusColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]
    private let actionColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private var context: RP2350BoardStatusContext { vm.rp2350StatusContext(for: board) }

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    private var bootselReady: Bool {
        context.stateLabel == "BOOTSEL"
    }

    private var runtimeReady: Bool {
        context.stateLabel == "运行态"
    }

    private var picoConnected: Bool {
        context.connected
    }

    private var bootselDisabledReason: String? {
        if !vm.localAgentRunning {
            return "本地 DBT Agent 离线"
        }
        if vm.rp2350ModeTransitionActive {
            return vm.rp2350ModeTransitionHint
        }
        if bootselReady {
            return "当前已经处于 BOOTSEL 状态"
        }
        return nil
    }

    private var returnToRuntimeDisabledReason: String? {
        if !vm.localAgentRunning {
            return "本地 DBT Agent 离线"
        }
        if vm.rp2350ModeTransitionActive {
            return vm.rp2350ModeTransitionHint
        }
        if bootselReady {
            return nil
        }
        if runtimeReady {
            return "当前已经处于运行态"
        }
        return "仅在 BOOTSEL 状态下可尝试恢复运行态"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: statusColumns, spacing: 6) {
                StatusCard(title: "连接方式", value: context.connectionLabel, ok: picoConnected, symbol: "cable.connector")
                StatusCard(title: "当前状态", value: context.stateLabel, ok: picoConnected, symbol: "dot.radiowaves.left.and.right")
                StatusCard(title: "串口设备", value: context.runtimePort, ok: runtimeReady, symbol: "terminal")
                StatusCard(title: "DBT Agent", value: vm.localAgentRunning ? "在线" : "离线", ok: vm.localAgentRunning, symbol: "switch.2")
            }

            GroupBox(localized("单 USB 状态")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized(context.summary))
                        .font(.system(.subheadline, design: .rounded))
                    if let serial = vm.status?.rp2350?.runtime_port?.serial_number, !serial.isEmpty {
                        Text("\(localized("串口序列号")): \(serial)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("RP2350 动作") {
                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionTile(title: "重新检测", subtitle: "识别当前是运行态、BOOTSEL 还是未连接", enabled: true, disabledReason: nil, symbol: "stethoscope") { vm.rp2350Detect() }
                    ActionTile(title: "进入 BOOTSEL", subtitle: "通过单 USB 进入 UF2 烧写状态，适合刷写初始程序", enabled: bootselDisabledReason == nil, disabledReason: bootselDisabledReason, symbol: "arrow.trianglehead.2.clockwise.rotate.90") { vm.rp2350EnterBootsel() }
                    ActionTile(title: "恢复运行态", subtitle: "从 BOOTSEL 回到应用态，恢复自动控制和调试", enabled: returnToRuntimeDisabledReason == nil, disabledReason: returnToRuntimeDisabledReason, symbol: "play.circle") { vm.rp2350ReturnToRuntime() }
                    ActionTile(title: "读取日志", subtitle: "仅运行态可用，用于查看最近串口输出", enabled: runtimeReady, disabledReason: runtimeReady ? nil : "当前不在运行态，无法读取串口日志", symbol: "text.append") { vm.rp2350TailLogs() }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ColorEasyPICO2FirmwareTab: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard
    @Environment(\.appLanguage) private var appLanguage

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    private var initialProgramMissingReason: String? {
        if !vm.localAgentRunning {
            return "本地 DBT Agent 离线"
        }
        let trimmed = vm.rp2350UF2Path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "当前没有找到初始程序 UF2" }
        if !FileManager.default.fileExists(atPath: trimmed) { return "初始程序 UF2 文件不存在" }
        return nil
    }

    private var initialProgramHelpText: String {
        let trimmed = vm.rp2350UF2Path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "当前未找到初始程序 UF2"
        }
        let url = URL(fileURLWithPath: trimmed)
        let parts = url.pathComponents.filter { $0 != "/" }
        let suffix = parts.suffix(4).joined(separator: "/")
        let compactPath = parts.count > 4 ? "…/\(suffix)" : trimmed
        return "初始程序路径：\(compactPath)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(localized("初始程序")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("后续通过问答生成的功能，会以这套初始程序能力为基础进行自动编译、部署和调试。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    ActionTile(
                        title: "刷写初始程序",
                        subtitle: localized("刷入默认 UF2，恢复当前自动控制和调试基础能力"),
                        enabled: initialProgramMissingReason == nil,
                        disabledReason: initialProgramMissingReason,
                        helpText: initialProgramHelpText,
                        symbol: "arrow.down.doc"
                    ) { vm.rp2350FlashUF2() }
                }
                .padding(.top, 8)
            }

            GroupBox(localized("保存 Flash")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(vm.rp2350ReadbackPath.isEmpty ? localized("点击按钮后选择导出位置") : vm.rp2350ReadbackPath)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(vm.rp2350ReadbackPath.isEmpty ? .secondary : .primary)
                    Text(localized("将当前板载 Flash 导出为 UF2，便于备份、比对和问题回溯。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    ActionTile(title: "保存 Flash", subtitle: "先选择导出位置，再回读板载 Flash 为 UF2", enabled: vm.localAgentRunning, disabledReason: vm.localAgentRunning ? nil : "本地 DBT Agent 离线", symbol: "externaldrive.badge.checkmark") { vm.rp2350SaveFlash() }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct RP2350MonitorTab: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard

    private let statusColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private let actionColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private var lastUpdatedText: String {
        guard let date = vm.rp2350Monitor.lastUpdated else {
            return "-"
        }
        return date.formatted(date: .omitted, time: .standard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: statusColumns, spacing: 6) {
                StatusCard(title: "固件版本", value: vm.rp2350Monitor.firmwareVersion, ok: vm.rp2350Monitor.supported, symbol: "cpu")
                StatusCard(title: "控制链路", value: vm.rp2350Monitor.serialDevice.isEmpty ? "USB CDC" : vm.rp2350Monitor.serialDevice, ok: vm.rp2350Monitor.supported, symbol: "cable.connector")
                StatusCard(title: "Wi-Fi", value: vm.rp2350Monitor.wifiSummary, ok: vm.rp2350Monitor.wifiStationOnline, symbol: "wifi")
                StatusCard(title: "缓冲队列", value: vm.rp2350Monitor.bufferSummary, ok: vm.rp2350Monitor.droppedEvents == 0, symbol: "tray.full")
            }

            GroupBox("控制通道") {
                RP2350MonitorTransportSelector(vm: vm, compact: true)
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 12) {
                GroupBox("监控状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vm.rp2350Monitor.availabilityDetail)
                            .font(.system(.subheadline, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("最近响应：\(vm.rp2350Monitor.lastResponse)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("更新时间：\(lastUpdatedText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("快捷操作") {
                    LazyVGrid(columns: actionColumns, spacing: 8) {
                        ActionTile(title: "刷新状态", subtitle: "读取 status / pins / channels", enabled: !vm.rp2350MonitorBusy, disabledReason: vm.rp2350MonitorBusy ? "命令执行中" : nil, symbol: "arrow.clockwise", action: { vm.rp2350MonitorRefresh() }, compact: true)
                        ActionTile(title: "重新探测", subtitle: "重新确认监控固件协议", enabled: !vm.rp2350MonitorBusy, disabledReason: vm.rp2350MonitorBusy ? "命令执行中" : nil, symbol: "stethoscope", action: { vm.rp2350MonitorProbe() }, compact: true)
                        ActionTile(title: "详细监控", subtitle: "打开 UART/SPI/I2C/GPIO 采集窗口", enabled: vm.rp2350Monitor.tabAvailable, disabledReason: vm.rp2350Monitor.tabAvailable ? nil : "当前固件未检测到监控协议", symbol: "rectangle.expand.vertical", action: { RP2350MonitorWindowPresenter.shared.show(vm: vm, board: board) }, compact: true)
                        ActionTile(title: "读取事件", subtitle: "回放固件环形缓冲", enabled: !vm.rp2350MonitorBusy, disabledReason: vm.rp2350MonitorBusy ? "命令执行中" : nil, symbol: "waveform.path", action: { vm.rp2350MonitorReadEvents() }, compact: true)
                    }
                    .padding(.top, 8)
                }
            }

            GroupBox("当前通道") {
                RP2350MonitorChannelList(channels: vm.rp2350Monitor.channels)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !vm.rp2350Monitor.tabAvailable {
                vm.rp2350MonitorProbe()
            }
        }
    }
}

struct RP2350MonitorChannelList: View {
    let channels: [RP2350MonitorChannel]

    var body: some View {
        if channels.isEmpty {
            Text("当前没有已配置通道。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                ForEach(channels) { channel in
                    HStack(spacing: 8) {
                        Text("#\(channel.id)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .frame(width: 34, alignment: .leading)
                        Text(channel.type.uppercased())
                            .font(.caption.weight(.semibold))
                            .frame(width: 44, alignment: .leading)
                        Circle()
                            .fill(channel.active ? Color.green : Color.secondary.opacity(0.6))
                            .frame(width: 7, height: 7)
                        Text(channel.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.toolkitPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct RP2350MonitorPinGrid: View {
    let pins: [RP2350MonitorPin]
    private let columns = Array(repeating: GridItem(.fixed(42), spacing: 5), count: 6)

    var body: some View {
        if pins.isEmpty {
            Text("等待 pins 命令返回。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                ForEach(pins) { pin in
                    RP2350MonitorPinCell(pin: pin)
                }
            }
        }
    }
}

struct RP2350MonitorPinCell: View {
    let pin: RP2350MonitorPin

    private var isFree: Bool {
        pin.owner == 0
    }

    private var backgroundColor: Color {
        isFree ? Color.primary.opacity(0.04) : Color.orange.opacity(0.12)
    }

    private var borderColor: Color {
        isFree ? Color.primary.opacity(0.08) : Color.orange.opacity(0.24)
    }

    var body: some View {
        VStack(spacing: 1) {
            Text("GP\(pin.gpio)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
            Text(isFree ? "空闲" : "#\(pin.owner)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(isFree ? Color.secondary : Color.orange)
        }
        .frame(width: 42, height: 34)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

@MainActor
final class RP2350MonitorWindowPresenter {
    static let shared = RP2350MonitorWindowPresenter()
    private var controller: NSWindowController?

    func show(vm: ToolkitViewModel, board: SupportedBoard) {
        let rootView = RP2350MonitorDetailWindowView(vm: vm, board: board)
        if let controller, let window = controller.window {
            window.contentViewController = NSHostingController(rootView: rootView)
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(board.displayName) 硬件监控"
        window.center()
        window.setContentSize(NSSize(width: 1120, height: 760))
        window.minSize = NSSize(width: 1060, height: 740)
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.contentViewController = NSHostingController(rootView: rootView)

        let controller = NSWindowController(window: window)
        self.controller = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window === self.controller?.window else {
                    return
                }
                self.controller = nil
            }
        }
    }
}

private enum RP2350MonitorDetailTab: String, CaseIterable, Identifiable {
    case status = "状态"
    case gpio = "GPIO 逻辑"
    case logic = "逻辑分析仪"
    case uart = "UART"
    case spi = "SPI"
    case i2c = "I2C"
    case raw = "JSONL"

    var id: String { rawValue }
}

struct RP2350MonitorDetailWindowView: View {
    @ObservedObject var vm: ToolkitViewModel
    let board: SupportedBoard
    @State private var selectedTab: RP2350MonitorDetailTab = .status

    private var availableTabs: [RP2350MonitorDetailTab] {
        RP2350MonitorDetailTab.allCases.filter { tab in
            tab != .logic || vm.rp2350Monitor.logicSupported
        }
    }

    var body: some View {
        let visibleTabs = availableTabs
        let effectiveTab = visibleTabs.contains(selectedTab) ? selectedTab : .status

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(board.displayName) 硬件监控")
                        .font(.title3.weight(.semibold))
                    Text(vm.rp2350Monitor.availabilityDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(vm.rp2350MonitorBusy ? "命令执行中" : "就绪")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(vm.rp2350MonitorBusy ? .orange : .green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background((vm.rp2350MonitorBusy ? Color.orange : Color.green).opacity(0.12))
                    .clipShape(Capsule())
            }

            Picker("", selection: $selectedTab) {
                ForEach(visibleTabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch effectiveTab {
                case .status:
                    RP2350MonitorStatusPanel(vm: vm)
                case .gpio:
                    RP2350MonitorGPIOPanel(vm: vm)
                case .logic:
                    RP2350MonitorLogicAnalyzerPanel(vm: vm)
                case .uart:
                    RP2350MonitorUARTPanel(vm: vm)
                case .spi:
                    RP2350MonitorSPIPanel(vm: vm)
                case .i2c:
                    RP2350MonitorI2CPanel(vm: vm)
                case .raw:
                    RP2350MonitorRawPanel(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(minWidth: 1060, minHeight: 740)
        .background(Color.toolkitWindowBackground)
        .onAppear {
            if !visibleTabs.contains(selectedTab) {
                selectedTab = .status
            }
            if !vm.rp2350Monitor.tabAvailable {
                vm.rp2350MonitorProbe()
            } else {
                vm.rp2350MonitorRefresh()
            }
        }
    }
}

struct RP2350MonitorStatusPanel: View {
    @ObservedObject var vm: ToolkitViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                StatusCard(title: "固件", value: vm.rp2350Monitor.firmwareVersion, ok: vm.rp2350Monitor.supported, symbol: "cpu")
                StatusCard(title: "串口", value: vm.rp2350Monitor.serialDevice.isEmpty ? "USB CDC" : vm.rp2350Monitor.serialDevice, ok: vm.rp2350Monitor.supported, symbol: "terminal")
                StatusCard(title: "Wi-Fi", value: vm.rp2350Monitor.wifiSummary, ok: vm.rp2350Monitor.wifiStationOnline, symbol: "wifi")
                StatusCard(title: "缓冲", value: vm.rp2350Monitor.bufferSummary, ok: vm.rp2350Monitor.droppedEvents == 0, symbol: "tray.full")
            }

            GroupBox("控制通道") {
                RP2350MonitorTransportSelector(vm: vm, compact: false)
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 12) {
                GroupBox("通道") {
                    RP2350MonitorChannelList(channels: vm.rp2350Monitor.channels)
                        .padding(.top, 8)
                }
                GroupBox("引脚") {
                    RP2350MonitorPinGrid(pins: vm.rp2350Monitor.pins)
                        .padding(.top, 8)
                }
            }
            .frame(height: 106)

            GroupBox("最近 JSONL") {
                SelectableDetailTextView(text: RP2350MonitorLogFormatter.text(from: vm.rp2350Monitor.recentLines, empty: "等待 JSONL 数据。"))
                    .frame(height: 132)
                    .padding(.top, 8)
            }
        }
    }
}

struct RP2350MonitorGPIOPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("GPIO 输出控制") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            MonitorField("通道", text: $vm.rp2350MonitorGPIOChannelID, width: 70)
                            MonitorField("GPIO", text: $vm.rp2350MonitorGPIOPin, width: 70)
                            Picker("方向", selection: $vm.rp2350MonitorGPIODirection) {
                                Text("输出").tag("output")
                                Text("输入").tag("input")
                            }
                            .frame(width: 100)
                            Picker("Pull", selection: $vm.rp2350MonitorGPIOPull) {
                                Text("None").tag("none")
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            .frame(width: 110)
                        }
                        Toggle("初始高电平", isOn: $vm.rp2350MonitorGPIOInitialLevel)
                            .font(.caption)
                        HStack(spacing: 8) {
                            CompactMonitorButton("配置启动", systemImage: "slider.horizontal.3", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorConfigureGPIO() }
                            CompactMonitorButton("读电平", systemImage: "eye", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorGPIORead() }
                            CompactMonitorButton("输出高", systemImage: "arrow.up.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorGPIOWrite(level: true) }
                            CompactMonitorButton("输出低", systemImage: "arrow.down.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorGPIOWrite(level: false) }
                            CompactMonitorButton("释放", systemImage: "xmark.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorReleaseChannel() }
                        }
                    }
                    .padding(.top, 8)
                }

                GroupBox("GPIO 输入逻辑分析") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            MonitorField("起始通道", text: $vm.rp2350MonitorGPIOAnalyzerChannelID, width: 78)
                            MonitorField("GPIO 列表", text: $vm.rp2350MonitorGPIOAnalyzerPins, width: 130)
                            Picker("Pull", selection: $vm.rp2350MonitorGPIOAnalyzerPull) {
                                Text("None").tag("none")
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            .frame(width: 110)
                            MonitorField("事件数", text: $vm.rp2350MonitorEventCount, width: 80)
                        }
                        HStack(spacing: 8) {
                            CompactMonitorButton("启动采集", systemImage: "record.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorConfigureGPIOAnalyzer() }
                            CompactMonitorButton("读取事件", systemImage: "waveform.path", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorReadGPIOAnalyzerEvents() }
                            CompactMonitorButton("释放输入", systemImage: "stop.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorReleaseGPIOAnalyzerChannel() }
                        }
                        Text("GPIO 列表可填写多个输入管脚，例如 17,18,19；系统会从起始通道开始连续分配采集通道。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(width: 470, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                GroupBox("波形") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.rp2350MonitorGPIOAnalyzerDisplayChannels()) { channel in
                            let samples = RP2350MonitorLogFormatter.gpioSamples(
                                from: vm.rp2350Monitor.recentLines,
                                channel: channel.channel
                            )
                            RP2350LogicChannelWaveform(channel: channel, samples: samples)
                        }
                    }
                    .padding(.top, 8)
                }
                GroupBox("GPIO 事件") {
                    SelectableDetailTextView(text: RP2350MonitorLogFormatter.filteredText(
                        from: vm.rp2350Monitor.recentLines,
                        token: "\"proto\":\"gpio\"",
                        empty: "等待 GPIO 事件。"
                    ))
                    .frame(minHeight: 260, maxHeight: .infinity)
                    .padding(.top, 8)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
            vm.rp2350MonitorPollGPIOAnalyzer()
        }
    }
}

struct RP2350MonitorLogicAnalyzerPanel: View {
    @ObservedObject var vm: ToolkitViewModel
    private let statusColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("PIO 采样设置") {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            MonitorField("起始 GPIO", text: $vm.rp2350LogicPinBase, width: 82)
                            MonitorField("通道数", text: $vm.rp2350LogicPinCount, width: 72)
                            MonitorField("采样率 Hz", text: $vm.rp2350LogicSampleRate, width: 116)
                            MonitorField("样本数", text: $vm.rp2350LogicSamples, width: 92)
                        }
                        HStack(spacing: 8) {
                            Toggle("触发", isOn: $vm.rp2350LogicTriggerEnabled)
                                .font(.caption)
                            MonitorField("触发 GPIO", text: $vm.rp2350LogicTriggerPin, width: 82)
                                .disabled(!vm.rp2350LogicTriggerEnabled)
                            Picker("触发电平", selection: $vm.rp2350LogicTriggerLevel) {
                                Text("高").tag(true)
                                Text("低").tag(false)
                            }
                            .frame(width: 96)
                            .disabled(!vm.rp2350LogicTriggerEnabled)
                        }
                        HStack(spacing: 8) {
                            CompactMonitorButton("配置", systemImage: "slider.horizontal.3", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorLogicConfigure() }
                            CompactMonitorButton("开始采集", systemImage: "record.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorLogicStart() }
                            CompactMonitorButton("刷新", systemImage: "arrow.clockwise", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorLogicRefreshStatus() }
                            CompactMonitorButton("读取波形", systemImage: "waveform.path", enabled: !vm.rp2350MonitorBusy && vm.rp2350Monitor.logicComplete) { vm.rp2350MonitorLogicReadCapture() }
                        }
                        HStack(spacing: 8) {
                            CompactMonitorButton("停止", systemImage: "pause.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorLogicStop() }
                            CompactMonitorButton("释放", systemImage: "xmark.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorLogicRelease() }
                        }
                        Text("PIO2 + DMA 会先把连续 GPIO 范围采样到板端 SRAM，再上传捕获缓冲；适合短窗口高速数字信号，不是轮询 GPIO。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                }

                GroupBox("采样状态") {
                    LazyVGrid(columns: statusColumns, spacing: 8) {
                        StatusCard(title: "状态", value: vm.rp2350Monitor.logicStatusLabel, ok: vm.rp2350Monitor.logicComplete, symbol: "scope")
                        StatusCard(title: "采样率", value: vm.rp2350Monitor.logicSampleRate > 0 ? "\(vm.rp2350Monitor.logicSampleRate) Hz" : "-", ok: vm.rp2350Monitor.logicConfigured, symbol: "speedometer")
                        StatusCard(title: "时窗", value: vm.rp2350Monitor.logicDurationText, ok: vm.rp2350Monitor.logicConfigured, symbol: "timer")
                        StatusCard(title: "缓冲", value: vm.rp2350Monitor.logicMemorySummary, ok: vm.rp2350Monitor.logicWords <= max(vm.rp2350Monitor.logicBufferWordsMax, 1), symbol: "memorychip")
                    }
                    .padding(.top, 8)
                }

                GroupBox("读取状态") {
                    Text(vm.rp2350Monitor.logicCaptureSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 462, alignment: .topLeading)

            GroupBox("逻辑波形") {
                RP2350LogicAnalyzerWaveform(state: vm.rp2350Monitor)
                    .padding(.top, 8)
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            vm.rp2350MonitorLogicPollIfRunning()
        }
    }
}

struct RP2350LogicAnalyzerWaveform: View {
    let state: RP2350MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.logicCaptureWords.isEmpty || state.logicPinCount <= 0 {
                Text("完成采集后点击“读取波形”，这里会显示按采样率展开的多通道数字波形。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 12) {
                    Text("GPIO \(state.logicPinBase)..\(state.logicPinBase + max(state.logicPinCount - 1, 0))")
                    Text("\(state.logicSamples) samples")
                    Text(state.logicDurationText)
                    Text("capture #\(state.logicCaptureID)")
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<max(state.logicPinCount, 0), id: \.self) { relativePin in
                            let gpio = state.logicPinBase + relativePin
                            let points = RP2350LogicCaptureDecoder.tracePoints(
                                words: state.logicCaptureWords,
                                pinCount: state.logicPinCount,
                                samples: state.logicSamples,
                                recordBits: state.logicRecordBits,
                                relativePin: relativePin,
                                maxPoints: 900
                            )
                            RP2350LogicTraceRow(gpio: gpio, points: points)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 520, maxHeight: .infinity)
    }
}

struct RP2350LogicTraceRow: View {
    let gpio: Int
    let points: [RP2350LogicTracePoint]

    var body: some View {
        HStack(spacing: 8) {
            Text("GPIO \(gpio)")
                .font(.caption.weight(.semibold))
                .frame(width: 70, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.toolkitInputBackground)
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(Color.primary.opacity(index % 2 == 0 ? 0.05 : 0.025))
                            .frame(width: 1)
                            .offset(x: proxy.size.width * CGFloat(index) / 7.0)
                    }
                    if points.isEmpty {
                        Text("无数据")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        waveformPath(size: proxy.size)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                    }
                }
            }
            .frame(height: 42)
            Text(points.last?.level == true ? "H" : "L")
                .font(.caption.weight(.bold))
                .foregroundStyle(points.last?.level == true ? Color.green : Color.secondary)
                .frame(width: 20)
        }
    }

    private func waveformPath(size: CGSize) -> Path {
        let highY: CGFloat = 10
        let lowY = max(highY + 12, size.height - 10)
        let width = max(size.width, 1)
        let count = max(points.count, 2)
        let step = width / CGFloat(count - 1)
        var path = Path()
        for index in points.indices {
            let x = CGFloat(index) * step
            let y = points[index].level ? highY : lowY
            if index == points.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let previousY = points[index - 1].level ? highY : lowY
                path.addLine(to: CGPoint(x: x, y: previousY))
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

enum RP2350LogicCaptureDecoder {
    static func tracePoints(
        words: [UInt32],
        pinCount: Int,
        samples: Int,
        recordBits: Int,
        relativePin: Int,
        maxPoints: Int
    ) -> [RP2350LogicTracePoint] {
        guard pinCount > 0, samples > 0, recordBits > 0, relativePin >= 0, relativePin < pinCount, !words.isEmpty else {
            return []
        }
        let availableSamples = min(samples, (words.count * recordBits) / pinCount)
        guard availableSamples > 0 else {
            return []
        }
        let step = max(1, availableSamples / max(maxPoints, 1))
        var points: [RP2350LogicTracePoint] = []
        points.reserveCapacity(min(maxPoints, availableSamples))
        var sample = 0
        while sample < availableSamples {
            points.append(RP2350LogicTracePoint(
                id: sample,
                sampleIndex: sample,
                level: levelAt(words: words, pinCount: pinCount, recordBits: recordBits, relativePin: relativePin, sample: sample)
            ))
            sample += step
        }
        if points.last?.sampleIndex != availableSamples - 1 {
            let lastSample = availableSamples - 1
            points.append(RP2350LogicTracePoint(
                id: lastSample,
                sampleIndex: lastSample,
                level: levelAt(words: words, pinCount: pinCount, recordBits: recordBits, relativePin: relativePin, sample: lastSample)
            ))
        }
        return points
    }

    private static func levelAt(words: [UInt32], pinCount: Int, recordBits: Int, relativePin: Int, sample: Int) -> Bool {
        let bitIndex = relativePin + sample * pinCount
        let wordIndex = bitIndex / recordBits
        guard wordIndex >= 0, wordIndex < words.count else {
            return false
        }
        let bitPosition = (bitIndex % recordBits) + 32 - recordBits
        return (words[wordIndex] & (UInt32(1) << UInt32(bitPosition))) != 0
    }
}

struct RP2350MonitorUARTPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupBox("UART 设置") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MonitorField("通道", text: $vm.rp2350MonitorUARTChannelID, width: 70)
                        MonitorField("实例", text: $vm.rp2350MonitorUARTInstance, width: 70)
                        MonitorField("TX", text: $vm.rp2350MonitorUARTTX, width: 70)
                        MonitorField("RX", text: $vm.rp2350MonitorUARTRX, width: 70)
                    }
                    HStack(spacing: 8) {
                        MonitorField("波特率", text: $vm.rp2350MonitorUARTBaud, width: 120)
                        Toggle("Loopback", isOn: $vm.rp2350MonitorUARTLoopback)
                            .font(.caption)
                    }
                    MonitorField("写入 HEX", text: $vm.rp2350MonitorUARTHex, width: 300)
                    HStack(spacing: 8) {
                        CompactMonitorButton("配置启动", systemImage: "slider.horizontal.3", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorConfigureUART() }
                        CompactMonitorButton("写入", systemImage: "paperplane", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorUARTWrite() }
                        CompactMonitorButton("停止", systemImage: "pause.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorUARTChannelID, release: false) }
                        CompactMonitorButton("释放", systemImage: "xmark.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorUARTChannelID, release: true) }
                    }
                }
                .padding(.top, 8)
            }
            .frame(width: 430)

            RP2350ProtocolEventPanel(title: "UART 事件", token: "\"proto\":\"uart\"", vm: vm)
        }
    }
}

struct RP2350MonitorSPIPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupBox("SPI 设置") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MonitorField("通道", text: $vm.rp2350MonitorSPIChannelID, width: 70)
                        MonitorField("实例", text: $vm.rp2350MonitorSPIInstance, width: 70)
                        MonitorField("SCK", text: $vm.rp2350MonitorSPISCK, width: 70)
                        MonitorField("MOSI", text: $vm.rp2350MonitorSPIMOSI, width: 70)
                    }
                    HStack(spacing: 8) {
                        MonitorField("MISO", text: $vm.rp2350MonitorSPIMISO, width: 70)
                        MonitorField("CS", text: $vm.rp2350MonitorSPICS, width: 70)
                        MonitorField("频率", text: $vm.rp2350MonitorSPIBaud, width: 120)
                    }
                    HStack(spacing: 8) {
                        MonitorField("传输 HEX", text: $vm.rp2350MonitorSPIHex, width: 210)
                        MonitorField("读长度", text: $vm.rp2350MonitorSPIReadLength, width: 80)
                    }
                    HStack(spacing: 8) {
                        CompactMonitorButton("配置启动", systemImage: "slider.horizontal.3", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorConfigureSPI() }
                        CompactMonitorButton("传输", systemImage: "arrow.left.arrow.right", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorSPITransfer() }
                        CompactMonitorButton("停止", systemImage: "pause.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorSPIChannelID, release: false) }
                        CompactMonitorButton("释放", systemImage: "xmark.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorSPIChannelID, release: true) }
                    }
                }
                .padding(.top, 8)
            }
            .frame(width: 430)

            RP2350ProtocolEventPanel(title: "SPI 事件", token: "\"proto\":\"spi\"", vm: vm)
        }
    }
}

struct RP2350MonitorI2CPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupBox("I2C 设置") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MonitorField("通道", text: $vm.rp2350MonitorI2CChannelID, width: 70)
                        MonitorField("实例", text: $vm.rp2350MonitorI2CInstance, width: 70)
                        MonitorField("SDA", text: $vm.rp2350MonitorI2CSDA, width: 70)
                        MonitorField("SCL", text: $vm.rp2350MonitorI2CSCL, width: 70)
                    }
                    HStack(spacing: 8) {
                        MonitorField("频率", text: $vm.rp2350MonitorI2CBaud, width: 120)
                        MonitorField("地址", text: $vm.rp2350MonitorI2CAddress, width: 90)
                        MonitorField("读长度", text: $vm.rp2350MonitorI2CReadLength, width: 80)
                    }
                    MonitorField("写入 HEX", text: $vm.rp2350MonitorI2CWriteHex, width: 300)
                    HStack(spacing: 8) {
                        CompactMonitorButton("配置启动", systemImage: "slider.horizontal.3", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorConfigureI2C() }
                        CompactMonitorButton("传输", systemImage: "arrow.left.arrow.right", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorI2CTransfer() }
                        CompactMonitorButton("停止", systemImage: "pause.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorI2CChannelID, release: false) }
                        CompactMonitorButton("释放", systemImage: "xmark.circle", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorStopOrReleaseChannel(channelIDText: vm.rp2350MonitorI2CChannelID, release: true) }
                    }
                }
                .padding(.top, 8)
            }
            .frame(width: 430)

            RP2350ProtocolEventPanel(title: "I2C 事件", token: "\"proto\":\"i2c\"", vm: vm)
        }
    }
}

struct RP2350MonitorRawPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupBox("原始 JSONL 命令") {
                VStack(alignment: .leading, spacing: 10) {
                    TextEditor(text: $vm.rp2350MonitorRawCommand)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 170, maxHeight: 170)
                        .scrollContentBackground(.hidden)
                        .background(Color.toolkitInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 8) {
                        MonitorField("事件数", text: $vm.rp2350MonitorEventCount, width: 80)
                        CompactMonitorButton("发送", systemImage: "paperplane", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorSendRawCommand() }
                        CompactMonitorButton("读取事件", systemImage: "waveform.path", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorReadEvents() }
                        CompactMonitorButton("刷新状态", systemImage: "arrow.clockwise", enabled: !vm.rp2350MonitorBusy) { vm.rp2350MonitorRefresh() }
                    }
                }
                .padding(.top, 8)
            }
            .frame(width: 430)

            GroupBox("全部 JSONL 数据") {
                SelectableDetailTextView(text: RP2350MonitorLogFormatter.text(from: vm.rp2350Monitor.recentLines, empty: "等待 JSONL 数据。"))
                    .frame(minHeight: 500, maxHeight: .infinity)
                    .padding(.top, 8)
            }
        }
    }
}

struct RP2350ProtocolEventPanel: View {
    let title: String
    let token: String
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        GroupBox(title) {
            SelectableDetailTextView(text: RP2350MonitorLogFormatter.filteredText(
                from: vm.rp2350Monitor.recentLines,
                token: token,
                empty: "等待\(title)。"
            ))
            .frame(minHeight: 500, maxHeight: .infinity)
            .padding(.top, 8)
        }
    }
}

struct RP2350MonitorTransportSelector: View {
    @ObservedObject var vm: ToolkitViewModel
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Picker("通道", selection: $vm.rp2350MonitorTransportMode) {
                    Text("USB").tag("usb")
                    Text("Wi-Fi").tag("wifi")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                if vm.rp2350MonitorTransportMode == "wifi" {
                    MonitorField("服务 IP", text: $vm.rp2350MonitorTCPHost, width: compact ? 140 : 170)
                    MonitorField("端口", text: $vm.rp2350MonitorTCPPort, width: 72)
                    Text("Wi-Fi 与 USB 可共存；已连接时会自动填入开发板 Station 地址。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 1 : 2)
                } else {
                    Text(vm.rp2350Monitor.serialDevice.isEmpty ? "当前使用 USB CDC 串口控制。" : vm.rp2350Monitor.serialDevice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                CompactMonitorButton("应用检测", systemImage: "checkmark.circle", enabled: !vm.rp2350MonitorBusy) {
                    vm.rp2350MonitorProbe()
                }
            }

            Text(vm.rp2350Monitor.wifiDetail)
                .font(.caption)
                .foregroundStyle(vm.rp2350Monitor.wifiStationOnline ? Color.green : Color.secondary)
                .lineLimit(compact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)

            if !compact {
                RP2350MonitorWiFiUSBConfigPanel(vm: vm)
            }
        }
    }
}

struct RP2350MonitorWiFiUSBConfigPanel: View {
    @ObservedObject var vm: ToolkitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Label("USB Wi-Fi 配置", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                Text("通过当前 USB CDC 控制通道写入 2.4GHz Wi-Fi 参数。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            HStack(alignment: .bottom, spacing: 8) {
                MonitorField("SSID", text: $vm.rp2350MonitorWiFiSSID, width: 190)
                MonitorSecureField("密码", text: $vm.rp2350MonitorWiFiPassword, width: 150)
                MonitorField("槽位", text: $vm.rp2350MonitorWiFiSlot, width: 48)
                CompactMonitorButton("扫描", systemImage: "dot.radiowaves.left.and.right", enabled: !vm.rp2350MonitorBusy) {
                    vm.rp2350MonitorWiFiScanViaUSB()
                }
                CompactMonitorButton("保存并连接", systemImage: "checkmark.circle", enabled: !vm.rp2350MonitorBusy) {
                    vm.rp2350MonitorWiFiSaveAndConnectViaUSB()
                }
                CompactMonitorButton("开启 AP", systemImage: "wifi.router", enabled: !vm.rp2350MonitorBusy) {
                    vm.rp2350MonitorWiFiStartAPViaUSB()
                }
                CompactMonitorButton("清除", systemImage: "trash", enabled: !vm.rp2350MonitorBusy) {
                    vm.rp2350MonitorWiFiClearViaUSB()
                }
            }
            HStack(spacing: 16) {
                Text(vm.rp2350Monitor.wifiProfilesSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(vm.rp2350Monitor.wifiScanSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

struct MonitorField: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    @Binding var text: String
    let width: CGFloat

    init(_ title: String, text: Binding<String>, width: CGFloat) {
        self.title = title
        self._text = text
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppStrings.localized(title, language: appLanguage))
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(AppStrings.localized(title, language: appLanguage), text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .frame(width: width)
        }
    }
}

struct MonitorSecureField: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    @Binding var text: String
    let width: CGFloat

    init(_ title: String, text: Binding<String>, width: CGFloat) {
        self.title = title
        self._text = text
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppStrings.localized(title, language: appLanguage))
                .font(.caption2)
                .foregroundStyle(.secondary)
            SecureField(AppStrings.localized(title, language: appLanguage), text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .rounded))
                .frame(width: width)
        }
    }
}

struct CompactMonitorButton: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let systemImage: String
    let enabled: Bool
    let action: () -> Void

    init(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(AppStrings.localized(title, language: appLanguage), systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }
}

struct RP2350LogicSample: Identifiable, Equatable {
    let id = UUID()
    let seq: Int
    let channel: Int
    let level: Bool
    let direction: String
}

struct RP2350LogicChannel: Identifiable, Equatable {
    var id: Int { channel }
    let channel: Int
    let gpio: Int?

    var title: String {
        if let gpio {
            return "CH \(channel) / GPIO \(gpio)"
        }
        return "CH \(channel)"
    }
}

struct RP2350LogicChannelWaveform: View {
    let channel: RP2350LogicChannel
    let samples: [RP2350LogicSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(channel.title)
                    .font(.caption.weight(.semibold))
                Text(RP2350MonitorLogFormatter.latestGPIOLevelText(samples: samples))
                    .font(.caption2)
                    .foregroundStyle(samples.last?.level == true ? Color.green : Color.secondary)
                Spacer(minLength: 0)
            }
            RP2350LogicWaveform(samples: samples)
                .frame(height: 72)
        }
    }
}

struct RP2350LogicWaveform: View {
    let samples: [RP2350LogicSample]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.toolkitInputBackground)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Divider()
                            .opacity(0.35)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 16)
                if samples.isEmpty {
                    Text("启动 GPIO 输入采集后，点击读取事件显示高低电平变化。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    waveformPath(size: proxy.size)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    HStack {
                        Text("LOW")
                        Spacer()
                        Text("HIGH")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(10)
                }
            }
        }
    }

    private func waveformPath(size: CGSize) -> Path {
        let inset: CGFloat = 18
        let width = max(1, size.width - inset * 2)
        let highY = inset + 18
        let lowY = max(highY + 24, size.height - inset - 18)
        let count = max(samples.count, 2)
        let step = width / CGFloat(count - 1)
        var path = Path()
        for index in samples.indices {
            let x = inset + CGFloat(index) * step
            let y = samples[index].level ? highY : lowY
            if index == samples.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let previousY = samples[index - 1].level ? highY : lowY
                let previousX = inset + CGFloat(index - 1) * step
                path.addLine(to: CGPoint(x: x, y: previousY))
                path.addLine(to: CGPoint(x: x, y: y))
                if index == samples.count - 1 {
                    path.addLine(to: CGPoint(x: min(size.width - inset, previousX + step), y: y))
                }
            }
        }
        return path
    }
}

enum RP2350MonitorLogFormatter {
    static func text(from lines: [RP2350MonitorEventLine], empty: String) -> String {
        guard !lines.isEmpty else {
            return empty
        }
        return lines.map { "[\($0.kind)] \($0.text)" }.joined(separator: "\n")
    }

    static func filteredText(from lines: [RP2350MonitorEventLine], token: String, empty: String) -> String {
        let filtered = lines.filter { $0.text.contains(token) }
        return text(from: filtered, empty: empty)
    }

    static func gpioSamples(from lines: [RP2350MonitorEventLine], channel: Int?) -> [RP2350LogicSample] {
        return lines.reversed().compactMap { entry in
            guard entry.text.contains("\"proto\":\"gpio\""),
                  let data = entry.text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: []),
                  let doc = object as? [String: Any] else {
                return nil
            }
            let sampleChannel = (doc["channel"] as? NSNumber)?.intValue ?? 0
            if let channel, sampleChannel != channel {
                return nil
            }
            let hex = (doc["hex"] as? String ?? "").lowercased()
            guard hex == "00" || hex == "01" else {
                return nil
            }
            let seq = (doc["seq"] as? NSNumber)?.intValue ?? 0
            let direction = doc["dir"] as? String ?? "change"
            return RP2350LogicSample(seq: seq, channel: sampleChannel, level: hex == "01", direction: direction)
        }
    }

    static func latestGPIOLevelText(samples: [RP2350LogicSample]) -> String {
        guard let sample = samples.last else {
            return "当前电平：未采样"
        }
        return "当前电平：\(sample.level ? "高电平" : "低电平")  seq=\(sample.seq)  dir=\(sample.direction)"
    }
}

struct InstallStatusRow: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let detail: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(ok ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.localized(title, language: appLanguage))
                    .font(.subheadline.weight(.semibold))
                Text(AppStrings.localized(detail, language: appLanguage))
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
    @Environment(\.appLanguage) private var appLanguage
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
                Text(AppStrings.localized(title, language: appLanguage))
                    .font(.title3.weight(.semibold))
                Text(AppStrings.localized(subtitle, language: appLanguage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(AppStrings.localized(badgeText, language: appLanguage))
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
    @Environment(\.appLanguage) private var appLanguage
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

    var actionForeground: Color {
        if actionEmphasized {
            return actionSoft ? .accentColor : .white
        }
        return .accentColor
    }

    var actionFillColor: Color {
        if !actionEnabled {
            return Color.secondary.opacity(0.12)
        }
        return actionSoft ? Color.accentColor.opacity(0.12) : Color.accentColor
    }

    var actionStrokeColor: Color {
        if !actionEnabled {
            return Color.secondary.opacity(0.12)
        }
        return actionSoft ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(0.2)
    }

    var actionShadowColor: Color {
        actionEnabled && !actionSoft ? Color.black.opacity(0.18) : .clear
    }

    @ViewBuilder
    private var actionBackground: some View {
        if actionEmphasized {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(actionFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(actionStrokeColor, lineWidth: 1)
                )
                .shadow(color: actionShadowColor, radius: 6, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(AppStrings.localized(actionTitle, language: appLanguage), action: action)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, actionEmphasized ? 12 : 0)
                .padding(.vertical, actionEmphasized ? 7 : 0)
                .background(actionBackground)
                .foregroundStyle(actionForeground)
                .opacity(actionEnabled ? 1 : 0.6)
                .disabled(!actionEnabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                        .foregroundStyle(tint)
                    Text(AppStrings.localized(title, language: appLanguage))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                actionButton
            }
            Text(AppStrings.localized(detail, language: appLanguage))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .help(AppStrings.localized(helpText ?? detail, language: appLanguage))
    }
}

struct DevelopmentModeSwitchCard: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let subtitle: String
    let statusText: String
    let ok: Bool
    let selected: Bool
    let action: () -> Void

    private var tint: Color {
        ok ? .green : .orange
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.localized(title, language: appLanguage))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(AppStrings.localized(subtitle, language: appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 10)
                    if selected {
                        Text(AppStrings.localized("当前", language: appLanguage))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                        .foregroundStyle(tint)
                    Text(AppStrings.localized(statusText, language: appLanguage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(Color.primary.opacity(selected ? 0.075 : 0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.52) : tint.opacity(0.18), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ArtifactValidationRow: View {
    @Environment(\.appLanguage) private var appLanguage
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
                    Text(AppStrings.localized(item.title, language: appLanguage))
                        .font(.subheadline.weight(.semibold))
                    if item.optional {
                        Text(AppStrings.localized("可选", language: appLanguage))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(AppStrings.localized(item.detail, language: appLanguage))
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
        .help(AppStrings.localized(item.detail, language: appLanguage))
    }
}

struct InstallerPrimaryActionCard: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStrings.localized(title, language: appLanguage))
                .font(.headline)
            Text(AppStrings.localized(subtitle, language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(AppStrings.localized(primaryTitle, language: appLanguage), action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button(AppStrings.localized(secondaryTitle, language: appLanguage), action: secondaryAction)
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
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let subtitle: String
    let requirementText: String
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
            Text(AppStrings.localized(title, language: appLanguage))
                .font(.headline)
            Text(AppStrings.localized(subtitle, language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text(path.isEmpty ? AppStrings.localized("未选择本地安装包目录", language: appLanguage) : path)
                    .font(.caption)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.toolkitInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button(AppStrings.localized("选择目录", language: appLanguage), action: chooseAction)
                    .controlSize(.large)
            }

            HStack(spacing: 10) {
                Button(AppStrings.localized("从本地文件安装", language: appLanguage), action: installAction)
                    .controlSize(.large)
                    .disabled(!validation.ready)
                Text(AppStrings.localized(requirementText, language: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Image(systemName: validation.ready ? "checkmark.seal.fill" : (validation.checked ? "exclamationmark.triangle.fill" : "folder.badge.questionmark"))
                    .foregroundStyle(summaryColor)
                Text(AppStrings.localized(validation.summary, language: appLanguage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summaryColor)
                    .lineLimit(2)
                Spacer()
                if validation.checked && !validation.ready && !validation.failureDetail.isEmpty {
                    Button(AppStrings.localized("查看详情", language: appLanguage), action: detailAction)
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
    @Environment(\.appLanguage) private var appLanguage
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
                    Text(AppStrings.localized(title, language: appLanguage))
                        .font(.headline)
                    Text(AppStrings.localized(statusText.isEmpty ? "等待操作" : statusText, language: appLanguage))
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
            .background(Color.toolkitInputBackground)
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
    case contact

    var windowTitle: String {
        switch self {
        case .version:
            return AppStrings.localized("版本信息")
        case .contact:
            return AppStrings.localized("联系方式")
        }
    }

    var preferredSize: NSSize {
        switch self {
        case .version:
            return NSSize(width: 560, height: 220)
        case .contact:
            return NSSize(width: 560, height: 560)
        }
    }

    var accentColor: Color {
        switch self {
        case .version:
            return Color(red: 0.05, green: 0.45, blue: 0.78)
        case .contact:
            return Color(red: 0.80, green: 0.42, blue: 0.10)
        }
    }

    var heroTitle: String {
        switch self {
        case .version:
            return AppStrings.productName
        case .contact:
            return AppStrings.localized("联系方式")
        }
    }

    var heroSubtitle: String {
        switch self {
        case .version:
            return AppStrings.localized("用于连接、刷写、发布与维护开发板的 macOS 常驻工具。")
        case .contact:
            return AppStrings.localized("用于问题反馈、功能建议和维护支持的统一入口。欢迎通过邮箱联系，也可以通过下方二维码支持后续迭代。")
        }
    }

    var badgeText: String {
        switch self {
        case let .version(appVersion, buildVersion):
            return "v\(appVersion) · build \(buildVersion)"
        case .contact:
            return AppStrings.localized("反馈与支持")
        }
    }

    var footerText: String {
        switch self {
        case .version:
            return ""
        case .contact:
            return AppStrings.localized("感谢支持 Embed Labs。你的反馈和捐献都会直接用于后续维护、适配和体验优化。")
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
        case .version:
            return []
        case .contact:
            return [
                ToolkitInfoSectionData(
                    eyebrow: AppStrings.localized("联系作者"),
                    title: AppStrings.localized("问题反馈与功能建议"),
                    summary: AppStrings.localized("如果你在安装、刷写、联机调试或版本升级过程中遇到问题，或者希望补充新功能，可以直接通过邮箱联系。"),
                    rows: [
                        ToolkitInfoRowData(
                            symbol: "envelope.badge.fill",
                            title: AppStrings.localized("联系邮箱"),
                            detail: "kong_w@foxmail.com",
                            tint: accentColor
                        ),
                        ToolkitInfoRowData(
                            symbol: "bubble.left.and.bubble.right.fill",
                            title: AppStrings.localized("反馈内容建议"),
                            detail: AppStrings.localized("建议附上当前版本、操作步骤、异常截图和日志信息，这样可以更快定位问题。"),
                            tint: Color.blue
                        ),
                        ToolkitInfoRowData(
                            symbol: "hammer.circle.fill",
                            title: AppStrings.localized("维护支持"),
                            detail: AppStrings.localized("如果这套工具对你的开发或交付流程有帮助，可以通过下方二维码支持后续维护与优化。"),
                            tint: Color.green
                        ),
                    ]
                ),
            ]
        }
    }
}

struct ToolkitInfoLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    let size: CGFloat
    let cornerRadius: CGFloat

    init(size: CGFloat = 116, cornerRadius: CGFloat = 24) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    private var logoImage: NSImage? {
        let preferredResource = colorScheme == .dark ? "AppInfoLogoDark" : "AppInfoLogoLight"
        for resource in [preferredResource, "AppInfoLogo", "AppInfoLogoLight"] {
            if let url = Bundle.main.url(forResource: resource, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
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
            ToolkitInfoLogoView(size: 92, cornerRadius: 20)
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
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    page.accentColor.opacity(0.14),
                    Color.primary.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct ToolkitInfoVersionWindowView: View {
    let page: ToolkitInfoPage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    page.accentColor.opacity(0.16),
                    page.accentColor.opacity(0.08),
                    Color.toolkitWindowBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 18) {
                ToolkitInfoLogoView(size: 96, cornerRadius: 22)
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
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(minWidth: page.preferredSize.width, minHeight: page.preferredSize.height)
    }
}

struct SSHConnectionPromptAccessoryView: View {
    let boardIP: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text("打开终端连接")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Text("将通过 Terminal 连接当前开发板。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("ssh root@\(boardIP)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 2)
                Text("连接前会自动清理该开发板 IP 的旧 host key，并写入 GUI 专用 known_hosts。")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 320, alignment: .leading)
        .padding(.top, 2)
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
        .background(Color.toolkitPanelBackground)
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
        .background(Color.toolkitPanelBackground)
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
        .background(Color.toolkitWindowBackground)
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
        .background(Color.toolkitPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToolkitInfoWindowView: View {
    let page: ToolkitInfoPage

    var body: some View {
        Group {
            if case .contact = page {
                ToolkitContactWindowView(page: page)
            } else if case .version = page {
                ToolkitInfoVersionWindowView(page: page)
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
        .background(Color.toolkitWindowBackground)
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

    private var resolvedBoard: SupportedBoard? {
        board ??
        vm.supportedBoard(for: vm.preferredControlBoardID) ??
        vm.supportedBoard(for: vm.connectedBoardID) ??
        vm.supportedBoard(for: "TaishanPi")
    }

    private var resolvedVariantID: String? {
        guard let resolvedBoard else {
            return nil
        }
        if let active = vm.activeVariantID(for: resolvedBoard.id) {
            return active
        }
        if resolvedBoard.id == "TaishanPi" {
            return "1M-RK3566"
        }
        return nil
    }

    private var boardSupportsDevelopmentInstall: Bool {
        guard let resolvedBoard else {
            return false
        }
        return vm.boardSupportsDevelopmentEnvironment(resolvedBoard.id, variantID: resolvedVariantID)
    }

    private var isTaishanPiBoard: Bool {
        resolvedBoard?.id == "TaishanPi"
    }

    private var headerTitle: String {
        embedded ? "开发环境" : "开发环境管理"
    }

    private var headerSubtitle: String {
        if boardSupportsDevelopmentInstall {
            if isTaishanPiBoard {
                switch vm.taishanPiDevelopmentMode {
                case .dockerLinux:
                    return "自动识别 Linux GCC / Docker 发布工作区、共享镜像和初始镜像缓存，并允许切换到其它开发环境视图。"
                case .macLLVM:
                    return "自动识别 Apple Silicon 原生 LLVM SDK、宿主工具和 LLVM 镜像 staging，并允许切换回 Linux GCC 视图。"
                }
            }
            if let resolvedBoard {
                return "为 \(resolvedBoard.displayName) 准备共享镜像、发布工作区和初始镜像资源。"
            }
            return "自动准备共享镜像、发布工作区和初始镜像资源。"
        }
        if let resolvedBoard,
           let metadata = vm.installedBoardToolingMetadata(resolvedBoard.id),
           metadata.require_explicit_variant_confirmation,
           resolvedVariantID == nil
        {
            return "当前开发板插件要求先明确具体板型，确认后才能匹配对应的开发环境与部署参数。"
        }
        return "当前开发板插件已安装，但这一板型的开发环境安装链路尚未接入。"
    }

    private func modeReady(_ mode: TaishanPiDevelopmentMode) -> Bool {
        switch mode {
        case .dockerLinux:
            return vm.developmentInstallStatus.dockerEnvironmentReady
        case .macLLVM:
            return vm.developmentInstallStatus.llvmEnvironmentReady
        }
    }

    private func modeStatusText(_ mode: TaishanPiDevelopmentMode) -> String {
        switch mode {
        case .dockerLinux:
            if vm.developmentInstallStatus.dockerEnvironmentReady {
                return "Docker 镜像、发布工作区和刷写缓存已就绪"
            }
            if vm.developmentInstallStatus.dockerEnvironmentPartial {
                return "Linux GCC 依赖只完成了一部分"
            }
            return "尚未检测到 Linux GCC 开发环境"
        case .macLLVM:
            if vm.developmentInstallStatus.llvmEnvironmentReady {
                return "LLVM SDK、宿主工具和镜像 staging 已就绪"
            }
            if vm.developmentInstallStatus.llvmEnvironmentPartial {
                return "Mac LLVM 依赖只完成了一部分"
            }
            return "尚未检测到 Mac LLVM 开发环境"
        }
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
                                    Text("刷新开发环境安装状态，并同步 Linux GCC、Mac LLVM、镜像与插件检查结果。")
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
                if isTaishanPiBoard {
                    HStack(spacing: 12) {
                        ForEach(vm.availableTaishanPiDevelopmentModes) { mode in
                            DevelopmentModeSwitchCard(
                                title: mode.title,
                                subtitle: mode.subtitle,
                                statusText: modeStatusText(mode),
                                ok: modeReady(mode),
                                selected: vm.taishanPiDevelopmentMode == mode,
                                action: { vm.setTaishanPiDevelopmentMode(mode) }
                            )
                        }
                    }
                    .padding(.top, 8)

                    if vm.canChooseTaishanPiDevelopmentMode {
                        Picker("开发环境模式", selection: Binding(
                            get: { vm.taishanPiDevelopmentMode },
                            set: { vm.setTaishanPiDevelopmentMode($0) }
                        )) {
                            ForEach(vm.availableTaishanPiDevelopmentModes) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 2)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(vm.taishanPiDevelopmentModeFixedSummary)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }

                    if vm.taishanPiDevelopmentMode == .dockerLinux {
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
                    } else {
                        HStack(spacing: 12) {
                            ReleaseStateCard(
                                title: "LLVM SDK",
                                detail: vm.developmentInstallStatus.llvmSDKReady ? "SDK 工作树、入口脚本和 wrapper 已就绪" : "需要准备大小写敏感 SDK 卷和入口脚本",
                                ok: vm.developmentInstallStatus.llvmSDKReady,
                                helpText: """
                                SDK 根目录: \(vm.developmentInstallStatus.llvmSDKRoot)
                                卷已挂载: \(vm.developmentInstallStatus.llvmSDKMounted ? "已检测到" : "未检测到")
                                大小写敏感: \(vm.developmentInstallStatus.llvmSDKCaseSensitive ? "是" : "否")
                                build-llvm.sh / llvm-env.sh: \(vm.developmentInstallStatus.llvmEntryScriptsReady ? "已就绪" : "未就绪")
                                .llvm-cross: \(vm.developmentInstallStatus.llvmCrossWrappersReady ? "已就绪" : "未就绪")
                                .llvm-host-tools: \(vm.developmentInstallStatus.llvmHostWrappersReady ? "已就绪" : "未就绪")
                                """
                            )
                            ReleaseStateCard(
                                title: "宿主工具",
                                detail: vm.developmentInstallStatus.llvmHostToolsReady ? "clang / lld / dtc / e2fsprogs / fakeroot 已就绪" : "宿主 LLVM 工具链仍有缺失",
                                ok: vm.developmentInstallStatus.llvmHostToolsReady,
                                helpText: """
                                clang: \(vm.developmentInstallStatus.llvmClangReady ? "已就绪" : "未就绪")
                                ld.lld: \(vm.developmentInstallStatus.llvmLLDReady ? "已就绪" : "未就绪")
                                llvm-objcopy: \(vm.developmentInstallStatus.llvmObjcopyReady ? "已就绪" : "未就绪")
                                llvm-readelf: \(vm.developmentInstallStatus.llvmReadelfReady ? "已就绪" : "未就绪")
                                python3: \(vm.developmentInstallStatus.llvmPython3Ready ? "已就绪" : "未就绪")
                                dtc: \(vm.developmentInstallStatus.llvmDtcReady ? "已就绪" : "未就绪")
                                fakeroot: \(vm.developmentInstallStatus.llvmFakerootReady ? "已就绪" : "未就绪")
                                mke2fs: \(vm.developmentInstallStatus.llvmMke2fsReady ? "已就绪" : "未就绪")
                                tune2fs: \(vm.developmentInstallStatus.llvmTune2fsReady ? "已就绪" : "未就绪")
                                """
                            )
                            ReleaseStateCard(
                                title: "LLVM 镜像",
                                detail: vm.developmentInstallStatus.llvmFactoryImagesReady ? "初始镜像已安装，用户镜像独立生成" : "需要安装 Mac LLVM 初始镜像",
                                ok: vm.developmentInstallStatus.llvmFactoryImagesReady,
                                helpText: """
                                初始镜像: \(vm.macLLVMFactoryImageDirURL().path)
                                初始镜像状态: \(vm.developmentInstallStatus.llvmFactoryImagesReady ? "已就绪" : "未就绪")
                                用户镜像: \(vm.macLLVMCustomImageDirURL().path)
                                用户镜像状态: \(vm.developmentInstallStatus.llvmCustomImagesReady ? "已就绪" : "等待构建同步生成")
                                bootprobe staging: \(vm.taishanPiLLVMBootProbeImageDirURL().path)
                                bootprobe staging: \(vm.developmentInstallStatus.llvmBootProbeImagesReady ? "已就绪" : "可选")
                                """
                            )
                        }
                        .padding(.top, 8)
                    }
                } else {
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
                }

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

                let offlineTitle = isTaishanPiBoard ? "\(vm.taishanPiDevelopmentMode.title) 离线安装" : "离线安装"
                let offlineSubtitle = isTaishanPiBoard && vm.taishanPiDevelopmentMode == .macLLVM
                    ? "选择 Mac LLVM 发布包或本地 LLVM 工作区归档导入。"
                    : "如已提前下载发布资源，可直接选择本地目录导入。"
                let offlineRequirement = isTaishanPiBoard && vm.taishanPiDevelopmentMode == .macLLVM
                    ? "目录内应包含 LLVM 发布/工作区归档，LLVM 镜像包与 Qt 编译环境包可选。"
                    : "目录内应包含共享镜像、初始镜像和发布工作区归档，Qt 编译环境包可选。"
                InstallerOfflineCard(
                    title: offlineTitle,
                    subtitle: offlineSubtitle,
                    requirementText: offlineRequirement,
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
                    Text("目前这套开发环境管理流程仍然优先适配泰山派（1M-RK3566），并已区分 Linux GCC 与 Mac LLVM 两种环境视图。后续会按开发板插件能力继续拆分与接入。")
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
                            helpText: "当前仅泰山派（1M-RK3566）已接入双环境开发面板。"
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
            .frame(minWidth: 820, minHeight: 660)
            .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
            .environment(\.appLanguage, vm.appLanguage)
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
            return statusText.isEmpty ? AppStrings.localized("正在联网检查更新...", language: vm.appLanguage) : statusText
        }
        if !vm.updateConfigured {
            return AppStrings.localized("未配置远程更新地址", language: vm.appLanguage)
        }
        if vm.toolkitUpdateStatus.updateAvailable {
            return "\(AppStrings.localized("发现新版本", language: vm.appLanguage)) \(vm.toolkitUpdateStatus.remoteVersion)"
        }
        if !vm.toolkitUpdateStatus.remoteVersion.isEmpty {
            return "\(AppStrings.localized("当前版本", language: vm.appLanguage)) \(vm.toolkitUpdateStatus.currentVersion), \(AppStrings.localized("已是最新版本", language: vm.appLanguage))"
        }
        return AppStrings.localized("等待检查更新", language: vm.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppStrings.productName + " " + AppStrings.localized("软件更新", language: vm.appLanguage))
                    .font(.headline)
                HStack(spacing: 16) {
                    Label("\(AppStrings.localized("当前版本", language: vm.appLanguage)) \(vm.toolkitUpdateStatus.currentVersion)", systemImage: "app.badge")
                        .foregroundStyle(.secondary)
                    if !vm.toolkitUpdateStatus.remoteVersion.isEmpty {
                        Label("\(AppStrings.localized("远端版本", language: vm.appLanguage)) \(vm.toolkitUpdateStatus.remoteVersion)", systemImage: "icloud.and.arrow.down")
                            .foregroundStyle(vm.toolkitUpdateStatus.updateAvailable ? Color.accentColor : .secondary)
                    }
                }
                Text(displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress = vm.taskProgressValue(for: vm.currentTask), updateFlowRunning {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else if updateFlowRunning {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            HStack(spacing: 10) {
                Button(AppStrings.localized("检查更新", language: vm.appLanguage)) {
                    vm.checkToolkitUpdate()
                }
                .buttonStyle(.bordered)
                .disabled(updateFlowRunning)

                Button(AppStrings.localized("安装更新", language: vm.appLanguage)) {
                    vm.performToolkitUpdate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateFlowRunning || !vm.toolkitUpdateStatus.updateAvailable)

                Spacer()
            }

            if !logLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(minWidth: 460, minHeight: 210)
        .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
        .environment(\.appLanguage, vm.appLanguage)
        .task {
            vm.checkToolkitUpdate()
        }
    }
}

struct SettingsWindowView: View {
    @ObservedObject var vm: ToolkitViewModel

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: vm.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ToolkitInfoLogoView(size: 52, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.productName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(localized("设置"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localized("语言"))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Picker(localized("语言"), selection: Binding(
                    get: { vm.appLanguage },
                    set: { vm.setAppLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.menuTitle).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                Text(localized("切换后界面文本会立即更新，后台任务日志和来自设备的原始输出保持原文。"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(minWidth: 440, minHeight: 220, alignment: .topLeading)
        .background(Color.toolkitWindowBackground)
        .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
        .environment(\.appLanguage, vm.appLanguage)
    }
}

struct CustomizeTab: View {
    @ObservedObject var vm: ToolkitViewModel
    @Environment(\.appLanguage) private var appLanguage
    private let rotateOptions = ["-90", "0", "90", "180"]

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(localized("启动 Logo")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(vm.logoPath.isEmpty ? localized("未选择 logo 文件") : vm.logoPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(vm.logoPath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button(localized("选择文件")) { vm.browseFile { vm.logoPath = $0 } }
                    }
                    HStack {
                        Text(localized("旋转角度"))
                        Picker(localized("旋转角度"), selection: $vm.logoRotate) {
                            ForEach(rotateOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 92)
                        Text(localized("比例"))
                        TextField("100", text: $vm.logoScale)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text("%")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Toggle(localized("更新后直接刷 Boot"), isOn: $vm.logoFlashAfter)
                    HStack {
                        Spacer()
                        Button(localized("执行 Logo 更新")) { vm.updateLogo() }
                    }
                }
                .padding(.top, 8)
            }

            GroupBox(localized("设备树")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(vm.dtsFilePath.isEmpty ? localized("未选择设备树文件") : vm.dtsFilePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(vm.dtsFilePath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button(localized("选择文件")) { vm.browseFile { vm.dtsFilePath = $0 } }
                    }
                    HStack {
                        Toggle(localized("更新后直接刷 Boot"), isOn: $vm.dtsFlashAfter)
                        Spacer()
                        Button(localized("执行设备树更新")) { vm.updateDTB() }
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
    @Environment(\.appLanguage) private var appLanguage

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = vm.selectedActivityEntry {
                HStack {
                    Button {
                        vm.selectedActivityEntry = nil
                    } label: {
                        Label(localized("返回列表"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        let text = entry.detail ?? entry.message
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label(localized("复制全部"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized(entry.title), systemImage: entry.level.symbol)
                        .font(.headline)
                        .foregroundStyle(entry.level.color)
                    Text(localized(entry.message))
                        .font(.subheadline)
                    SelectableDetailTextView(text: entry.detail ?? entry.message)
                        .frame(minHeight: 220)
                    .padding(10)
                    .background(Color.toolkitInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                if vm.activities.isEmpty {
                    Text(localized("暂无活动记录"))
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

struct SelectableDetailTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
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
    let supportBaseRoot = ToolkitViewModel.resolveToolkitSupportRoot()
    let supportRoot = supportBaseRoot.appendingPathComponent("plugins", isDirectory: true)
    let sharedRuntimeRoot = supportBaseRoot.appendingPathComponent("runtime", isDirectory: true)
    let bundledBoardAssetsRoot = Bundle.main.resourceURL?
        .appendingPathComponent("BoardAssets", isDirectory: true)
        .appendingPathComponent("boards", isDirectory: true)
        .appendingPathComponent(board.id, isDirectory: true)
        .appendingPathComponent("assets", isDirectory: true)
    let familyBoardAssetsRoot: URL? = {
        if isRP2350BoardID(board.id) {
            return supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rp2350", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(board.id, isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        }
        if board.id == "TaishanPi" {
            return supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rk356x", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(board.id, isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        }
        return nil
    }()
    let familyBoardPluginRoot: URL? = {
        if isRP2350BoardID(board.id) {
            return supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rp2350", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(board.id, isDirectory: true)
                .appendingPathComponent("plugin", isDirectory: true)
        }
        if board.id == "TaishanPi" {
            return supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rk356x", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(board.id, isDirectory: true)
                .appendingPathComponent("variants", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent("plugin", isDirectory: true)
        }
        return nil
    }()
    let runtimeSeedPluginRoot: URL? = {
        if board.id == "TaishanPi" {
            return sharedRuntimeRoot
                .appendingPathComponent("builtin-plugin-seed", isDirectory: true)
                .appendingPathComponent(board.id, isDirectory: true)
                .appendingPathComponent("variants", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent("plugin", isDirectory: true)
        }
        return sharedRuntimeRoot
            .appendingPathComponent("builtin-plugin-seed", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
    }()

    let candidates: [URL] = [
        bundledBoardAssetsRoot?
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        familyBoardPluginRoot?
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        familyBoardAssetsRoot?
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        supportRoot
            .appendingPathComponent("user", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        supportRoot
            .appendingPathComponent("builtin", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        runtimeSeedPluginRoot?
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        sharedRuntimeRoot
            .appendingPathComponent("builtin-plugin-seed", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
        sharedRuntimeRoot
            .appendingPathComponent("board_plugins", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true),
    ].compactMap { $0 }

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

private func firstBoardPreviewImageURL(in assetRoot: URL, board: SupportedBoard) -> URL? {
    let fm = FileManager.default
    let pluginID = pluginBoardID(forLocalBoardID: board.id) ?? board.id
    let directories = [
        assetRoot.appendingPathComponent("images", isDirectory: true),
        assetRoot,
    ]
    let baseNames = [
        "preview",
        "board",
        "\(board.id)Preview",
        "\(pluginID)Preview",
    ].map { $0.lowercased() }
    let extensions = ["png", "jpg", "jpeg"]

    for directory in directories where fm.fileExists(atPath: directory.path) {
        for baseName in baseNames {
            for ext in extensions {
                let candidate = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        let contents = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        if let preview = contents.first(where: { url in
            extensions.contains(url.pathExtension.lowercased()) &&
                url.deletingPathExtension().lastPathComponent.lowercased().contains("preview")
        }) {
            return preview
        }
        if let image = contents.first(where: { extensions.contains($0.pathExtension.lowercased()) }) {
            return image
        }
    }
    return nil
}

private func boardPreviewImageURL(for board: SupportedBoard) -> URL? {
    if board.id == "Pico2W",
       let bundledPreview = Bundle.main.url(forResource: "Pico2WPreview", withExtension: "png") {
        return bundledPreview
    }

    let supportBaseRoot = ToolkitViewModel.resolveToolkitSupportRoot()
    let sharedRuntimeRoot = supportBaseRoot.appendingPathComponent("runtime", isDirectory: true)
    let pluginID = pluginBoardID(forLocalBoardID: board.id) ?? board.id
    var assetRoots: [URL?] = [
        Bundle.main.resourceURL?
            .appendingPathComponent("BoardAssets", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent(board.id, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
        Bundle.main.resourceURL?
            .appendingPathComponent("BoardAssets", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
        supportBaseRoot
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("user", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
        supportBaseRoot
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("builtin", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
        sharedRuntimeRoot
            .appendingPathComponent("builtin-plugin-seed", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
        sharedRuntimeRoot
            .appendingPathComponent("board_plugins", isDirectory: true)
            .appendingPathComponent("boards", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true),
    ]
    if isRP2350BoardID(pluginID) {
        assetRoots.append(
            supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rp2350", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(pluginID, isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        )
        assetRoots.append(
            supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rp2350", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent(pluginID, isDirectory: true)
                .appendingPathComponent("plugin", isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        )
    } else if pluginID == "TaishanPi", let directoryName = board.modelDirectoryName {
        assetRoots.append(
            supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rk356x", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent("TaishanPi", isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        )
        assetRoots.append(
            supportBaseRoot
                .appendingPathComponent("families", isDirectory: true)
                .appendingPathComponent("rk356x", isDirectory: true)
                .appendingPathComponent("boards", isDirectory: true)
                .appendingPathComponent("TaishanPi", isDirectory: true)
                .appendingPathComponent("variants", isDirectory: true)
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent("plugin", isDirectory: true)
                .appendingPathComponent("assets", isDirectory: true)
        )
    }

    for root in assetRoots.compactMap({ $0 }) {
        if let imageURL = firstBoardPreviewImageURL(in: root, board: board) {
            return imageURL
        }
    }
    return nil
}

private enum BoardVisualAsset {
    case model(URL)
    case image(NSImage)

    var isModel: Bool {
        if case .model = self {
            return true
        }
        return false
    }
}

private func boardVisualAsset(for board: SupportedBoard) -> BoardVisualAsset? {
    if let modelURL = boardModelOBJURL(for: board) {
        return .model(modelURL)
    }
    if let imageURL = boardPreviewImageURL(for: board),
       let image = NSImage(contentsOf: imageURL) {
        return .image(image)
    }
    return nil
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

    private var visualAsset: BoardVisualAsset? {
        boardVisualAsset(for: board)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    switch visualAsset {
                    case .image(let previewImage):
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .padding(16)
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
                    case .model:
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
                    case nil:
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                            Text("暂无可展示资源")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
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
                    }
                }

                Text(hasModel ? "拖动旋转，双击可弹出独立窗口查看。" : (visualAsset == nil ? "当前没有找到模型或图片资源；安装或更新对应板卡资源后会自动恢复展示。" : "当前展示产品图片；该板卡补齐 3D 模型后会自动优先展示模型。"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("开发板 3D 视图", systemImage: "rotate.3d.fill")
                    .font(.system(.headline, design: .rounded).weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    if !hasModel, visualAsset != nil {
                        Label("当前展示产品图片，后续补齐 3D 模型后会自动切回模型预览。", systemImage: "photo")
                        Label("当前图片用于确认外观与版型，不提供旋转和缩放交互。", systemImage: "rectangle.inset.filled")
                    } else {
                        if hasModel {
                            Label("模型已加载，可围绕板子中心旋转查看。", systemImage: "cube.transparent.fill")
                            Label("嵌入视图固定比例显示，双击后可在大图窗口中缩放。", systemImage: "plus.magnifyingglass")
                            Label("背景和灯光已压低曝光，板卡轮廓会更稳定。", systemImage: "circle.lefthalf.filled")
                        } else {
                            Label("当前没有找到模型或图片资源。", systemImage: "shippingbox.fill")
                            Label("安装或更新对应板卡资源后，这里会自动恢复展示。", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
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
        .background(Color.toolkitPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct BoardModelStandaloneWindowView: View {
    let board: SupportedBoard
    let closeAction: () -> Void

    private var visualAsset: BoardVisualAsset? {
        boardVisualAsset(for: board)
    }

    private var hasModel: Bool {
        visualAsset?.isModel == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(board.displayName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text(hasModel ? "独立 3D 视图" : "开发板外观")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭", action: closeAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            Group {
                switch visualAsset {
                case .model:
                    BoardModelSceneContainer(board: board, allowsZoom: true, doubleClickAction: nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .image(let previewImage):
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding(28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case nil:
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Text("暂无可展示资源")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
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

            Text(hasModel ? "拖动旋转，滚轮缩放。视角围绕模型中心。" : "当前展示产品图片；该板卡提供 3D 模型资源后会自动切换到模型视图。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 660)
        .background(Color.toolkitWindowBackground)
    }
}

struct ToolkitHomeHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let subtitle: String
    let heroState: ToolkitHeroState
    let badgeTitle: String
    let busy: Bool
    let actionHint: String
    let action: (() -> Void)?
    @State private var hovering = false

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

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

                Text(localized(subtitle))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(
                        localized(heroState == .deviceReady ? "设备已识别" : (heroState == .deviceClose ? "设备已断开" : "等待识别")),
                        systemImage: heroState == .deviceReady ? "checkmark.circle.fill" : (heroState == .deviceClose ? "xmark.circle.fill" : "wave.3.right.circle.fill")
                    )
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(accentTextColor)

                    if busy {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(accentTextColor)
                            Text(localized("后台处理中"))
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(accentTextColor)
                        }
                    } else if !actionHint.isEmpty {
                        Text(localized(actionHint))
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
    let bundledIntegrationAvailable: Bool
    let removable: Bool
    let operation: BoardPluginOperationState
    let action: () -> Void
    let detailAction: () -> Void
    @Environment(\.appLanguage) private var appLanguage

    private var localVersionText: String {
        if let installedVersion {
            return appLanguage == .en ? "Local \(installedVersion)" : "本地 \(installedVersion)"
        }
        return AppStrings.localized(bundledIntegrationAvailable ? "应用内置" : "未安装", language: appLanguage)
    }

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
                if installedVersion == nil, !bundledIntegrationAvailable {
                    Button("安装插件", action: action)
                        .buttonStyle(.borderedProminent)
                } else if removable {
                    Button("删除插件", action: action)
                        .buttonStyle(.bordered)
                } else {
                    Button(bundledIntegrationAvailable ? "应用内置" : "内置插件") {}
                        .buttonStyle(.bordered)
                        .disabled(true)
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
                Text(localVersionText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle((installedVersion == nil && !bundledIntegrationAvailable) ? Color.secondary : Color.green)
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
                .fill(selected ? Color.accentColor.opacity(0.10) : Color.toolkitPanelBackground)
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
    let bundledIntegrationAvailable: Bool
    let currentControlBoardSelection: Binding<Bool>
    let hideOuterHero: Binding<Bool>
    let backAction: () -> Void
    let showDetachedModel: (SupportedBoard) -> Void
    @Environment(\.appLanguage) private var appLanguage
    @State private var selectedSection: SupportedBoardDetailSection = .overview
    @State private var expandedSection: SupportedBoardDetailSection = .overview
    @State private var navShowsFullLabel = false
    @State private var revealAllNavButtons = false
    @State private var hoveredSection: SupportedBoardDetailSection?
    @State private var overviewModelReady = false
    @State private var capabilityTagsVisible = false
    @State private var lastSectionSwitchTime: CFAbsoluteTime = 0
    @State private var sectionTransitionDirection = 1
    private let capabilityColumns = [GridItem(.adaptive(minimum: 116), spacing: 8)]

    private var integrationLabel: String {
        switch board.id {
        case let value where isRP2350BoardID(value):
            return "单 USB 已接入"
        default:
            return board.integrationReady ? "已接入控制链路" : "规划接入中"
        }
    }

    private var integrationDetailText: String {
        switch board.id {
        case let value where isRP2350BoardID(value):
            return "UF2 刷入与串口调试已按单 USB 流程接入"
        default:
            return board.integrationReady ? "控制能力已可用" : "等待后续接入"
        }
    }

    private var localPluginDetailText: String {
        if let installedVersion {
            return appLanguage == .en ? "Local \(installedVersion)" : "本地 \(installedVersion)"
        }
        return AppStrings.localized(
            bundledIntegrationAvailable ? "应用内置，无需单独安装" : "本地未安装",
            language: appLanguage
        )
    }

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    private var availableSections: [SupportedBoardDetailSection] {
        var sections: [SupportedBoardDetailSection] = [.overview, .summary, .capabilities, .variants]
        if (installedVersion != nil || bundledIntegrationAvailable), !isRP2350BoardID(board.id) {
            sections.append(.developmentEnvironment)
        }
        return sections
    }

    private var overviewSummaryTitle: String {
        switch board.id {
        case "TaishanPi":
            return "泰山派（1M-RK3566）核心参数"
        case "ColorEasyPICO2":
            return "ColorEasyPICO2（RP2350A 单 USB）核心参数"
        case "Pico2W":
            return "Pico 2 W（RP2350 / Wi‑Fi）核心参数"
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
        case "ColorEasyPICO2":
            return [
                "主控芯片：RP2350A",
                "连接方式：单 USB",
                "刷写路径：UF2 存储盘",
                "调试方式：USB 串口",
                "设备展示：UF2 刷入和串口共用同一条 USB 连接",
            ]
        case "Pico2W":
            return [
                "主控芯片：RP2350",
                "无线模块：Wi‑Fi",
                "连接方式：单 USB",
                "刷写路径：UF2 存储盘",
                "调试方式：USB 串口",
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

    private func refreshCapabilityTagAnimation(animated: Bool = true) {
        capabilityTagsVisible = false
        let applyVisible = {
            if animated {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    capabilityTagsVisible = true
                }
            } else {
                capabilityTagsVisible = true
            }
        }
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                applyVisible()
            }
        } else {
            applyVisible()
        }
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
                        Text(board.conciseModelLabel)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text(board.englishName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if installedVersion != nil || bundledIntegrationAvailable {
                        VStack(alignment: .leading, spacing: 0) {
                            Toggle("当前控制页", isOn: currentControlBoardSelection)
                            .toggleStyle(.checkbox)
                            .help("勾选表示当前设备控制页面关联的是这块开发板。")
                        }
                        .frame(width: 102, alignment: .leading)
                    }

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
                            .fill(Color.toolkitPanelBackground)
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
        .background(Color.toolkitWindowBackground)
        .background(
            LocalScrollMonitorView(onScroll: handleScrollDelta)
                .allowsHitTesting(false)
        )
        .onAppear {
            if !availableSections.contains(selectedSection) {
                selectedSection = .overview
            }
            refreshOverviewModelReady()
            if selectedSection == .capabilities {
                refreshCapabilityTagAnimation(animated: false)
            } else {
                capabilityTagsVisible = false
            }
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
            } else if newValue == .capabilities {
                refreshCapabilityTagAnimation()
            } else {
                capabilityTagsVisible = false
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
                let visualAsset = boardVisualAsset(for: board)
                let hasModelAsset = visualAsset?.isModel == true
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        LinearGradient(
                            colors: boardModelPresentationProfile(for: board).previewBackground,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        switch visualAsset {
                        case .image(let previewImage):
                            Image(nsImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: boardModelPresentationProfile(for: board).previewSize,
                                    height: boardModelPresentationProfile(for: board).previewSize
                                )
                                .padding(18)
                        case .model:
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
                        case nil:
                            VStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                Text("暂无可展示资源")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            }
                            .padding(18)
                        }

                        if hasModelAsset && !overviewModelReady {
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

                    Text(hasModelAsset ? "拖动旋转，双击可打开独立 3D 查看窗口。" : (visualAsset == nil ? "当前没有找到模型或图片资源；安装或更新对应板卡资源后会自动恢复展示。" : "当前展示产品图片；如果该板卡提供 3D 模型，会自动优先展示模型。"))
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
                        detail: board.conciseModelLabel
                    )
                    detailMetricCard(
                        title: "插件版本",
                        value: remoteVersion,
                        detail: localPluginDetailText
                    )
                    detailMetricCard(
                        title: "集成状态",
                        value: integrationLabel,
                        detail: integrationDetailText
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
                Text(isRP2350BoardID(board.id)
                     ? "当前开发板已验证的能力模块如下。单 USB 连接同时承载 UF2 刷入和串口调试。"
                     : "当前开发板计划复用或已接入的能力模块如下。后续增加新板卡时，优先按这些模块进行组合。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: capabilityColumns, alignment: .leading, spacing: 10) {
                    ForEach(Array(board.capabilities.enumerated()), id: \.element.rawValue) { index, capability in
                        CapabilityChip(title: capability.displayName, tint: board.accentStart)
                            .opacity(capabilityTagsVisible ? 1 : 0.001)
                            .offset(y: capabilityTagsVisible ? 0 : 16)
                            .animation(
                                .spring(response: 0.32, dampingFraction: 0.82)
                                    .delay(Double(index) * 0.035),
                                value: capabilityTagsVisible
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .variants:
            VStack(alignment: .leading, spacing: 12) {
                Text(isRP2350BoardID(board.id)
                     ? "该开发板当前以 RP2350 单 USB 流程展示，后续识别和动作分发会继续按具体板型细分。"
                     : "该开发板系列当前覆盖的板型如下，后续识别和动作分发会按具体板型继续细分。")
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
                        .background(Color.toolkitPanelBackground)
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
            Text(localized(title))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(localized(value))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(localized(detail))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.toolkitPanelBackground)
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
                            Text(candidate.selectionLabel)
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
                    .background(Color.toolkitPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(Color.toolkitOverlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }
}

struct RP2350FlashTargetOverlay: View {
    @ObservedObject var vm: ToolkitViewModel
    let prompt: RP2350FlashTargetPrompt
    @Environment(\.appLanguage) private var appLanguage

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择要刷写的设备")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("当前将刷写 \(prompt.boardDisplayName) 的初始程序。请选择本次要写入的物理设备。")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") {
                    vm.dismissRP2350FlashTargetPrompt()
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 10) {
                ForEach(prompt.candidates) { candidate in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localized(vm.activeControlDisplayLabel(for: candidate)))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                            Text("\(localized(candidate.interfaceName)) · \(localized(candidate.transportName))")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(localized(candidate.sourceName))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("刷写到此设备") {
                            vm.confirmRP2350FlashTarget(candidate, prompt: prompt)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(Color.toolkitPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(Color.toolkitOverlayBackground)
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
    @Environment(\.appLanguage) private var appLanguage
    @ObservedObject var vm: ToolkitViewModel
    @Binding var detailBoard: SupportedBoard?
    @Binding var hideOuterHero: Bool
    let showDetachedModel: (SupportedBoard) -> Void
    @State private var searchText = ""
    @State private var selectedBoardID: String?
    @State private var detailPresentationArmed = false

    private var searchFieldBackground: Color {
        Color.toolkitInputBackground
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

    private var supportedBoardCountText: String {
        if appLanguage == .en {
            return "\(vm.supportedBoards.count) boards total"
        }
        return "共 \(vm.supportedBoards.count) 种开发板"
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
                    Text(supportedBoardCountText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

            }

            Group {
                if detailPresentationArmed, let detailBoard {
                    SupportedBoardDetailView(
                        vm: vm,
                        board: detailBoard,
                        remoteVersion: vm.boardPluginDisplayVersion(detailBoard.id),
                        installedVersion: vm.boardPluginInstalledVersion(detailBoard.id),
                        bundledIntegrationAvailable: vm.isBoardIntegrationBundled(detailBoard.id),
                        currentControlBoardSelection: Binding(
                            get: { vm.preferredControlBoardID == detailBoard.id },
                            set: { isOn in
                                vm.setPreferredControlBoard(isOn ? detailBoard.id : nil)
                            }
                        ),
                        hideOuterHero: $hideOuterHero,
                        backAction: {
                            detailPresentationArmed = false
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
                                            bundledIntegrationAvailable: vm.isBoardIntegrationBundled(board.id),
                                            removable: vm.canRemoveBoardPlugin(board.id),
                                            operation: vm.boardPluginOperation(for: board.id),
                                            action: { vm.installOrRemoveBoardPlugin(board) },
                                            detailAction: {
                                                detailPresentationArmed = true
                                                self.detailBoard = board
                                            }
                                        )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedBoardID = board.id
                                            }
                                            .simultaneousGesture(
                                                TapGesture(count: 2).onEnded {
                                                    selectedBoardID = board.id
                                                    detailPresentationArmed = true
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
        .onAppear {
            detailPresentationArmed = false
            detailBoard = nil
            hideOuterHero = false
            selectedBoardID = nil
        }
        .onChange(of: detailBoard?.id) { _, newValue in
            if newValue == nil {
                detailPresentationArmed = false
                selectedBoardID = nil
            }
        }
        .onChange(of: vm.boardCatalogResetRequestID) { _, _ in
            detailPresentationArmed = false
            detailBoard = nil
            hideOuterHero = false
            selectedBoardID = nil
        }
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
    @Environment(\.appLanguage) private var appLanguage

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardModelPreviewCard(board: board, doubleClickAction: {
                    showDetachedModel(board)
                })

                GroupBox(localized(isRP2350BoardID(board.id) ? "单 USB 连接" : "当前连接")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(localized(vm.controlPageBoardTitle), systemImage: "cpu.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                        Text("\(localized(vm.deviceConnectionText)) · \(localized(vm.deviceReachabilityText))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if isRP2350BoardID(board.id) {
                        Text("UF2 刷入与串口调试共用同一条 USB 连接。")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                    Text(localized(board.integrationStatus))
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
    @Environment(\.appLanguage) private var appLanguage
    @State private var showingDeviceSelector = false
    @State private var hoveredDeviceCandidateID: String?

    private var hoveredDeviceCandidate: DetectedBoardCandidate? {
        if let hoveredDeviceCandidateID {
            return vm.activeControlDeviceCandidates.first(where: { $0.id == hoveredDeviceCandidateID })
        }
        return vm.currentControlCandidate
    }

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if vm.controlPageIsTaishanPi {
                    HStack(spacing: 8) {
                        Text("环境")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if vm.canChooseTaishanPiDevelopmentMode {
                            Picker("编译模式", selection: Binding(
                                get: { vm.taishanPiDevelopmentMode },
                                set: { vm.setTaishanPiDevelopmentMode($0) }
                            )) {
                                ForEach(vm.availableTaishanPiDevelopmentModes) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 176)
                        } else {
                            Text(vm.taishanPiDevelopmentMode.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.toolkitPanelBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.toolkitPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .help("选择当前控制页、下载、安装、构建和用户镜像刷写使用的 TaishanPi 编译环境。")
                }

                Spacer(minLength: 18)

                if !vm.activeControlDeviceCandidates.isEmpty {
                    Button {
                        hoveredDeviceCandidateID = vm.currentControlCandidate?.id
                        showingDeviceSelector.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Text(localized(vm.activeControlDeviceMenuLabel))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.toolkitPanelBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("选择当前 GUI 用于控制和提交任务的开发板设备。")
                    .popover(
                        isPresented: $showingDeviceSelector,
                        attachmentAnchor: .point(.bottom),
                        arrowEdge: .top
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localized("当前激活控制设备"))
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 6) {
                                ForEach(vm.activeControlDeviceCandidates) { candidate in
                                    Button {
                                        vm.setPreferredControlDevice(candidate.deviceID)
                                        hoveredDeviceCandidateID = candidate.id
                                        showingDeviceSelector = false
                                    } label: {
                                        HStack(alignment: .center, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(localized(vm.activeControlDisplayLabel(for: candidate)))
                                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text(localized(candidate.transportName))
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                            if candidate.deviceID == vm.activeControlDeviceSelectionID {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.toolkitPanelBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .help(localized(vm.activeControlTooltip(for: candidate)))
                                    .onHover { hovering in
                                        if hovering {
                                            hoveredDeviceCandidateID = candidate.id
                                        } else if hoveredDeviceCandidateID == candidate.id {
                                            hoveredDeviceCandidateID = vm.currentControlCandidate?.id
                                        }
                                    }
                                }
                            }

                            Divider()

                            Text(localized(hoveredDeviceCandidate.map(vm.activeControlTooltip(for:)) ?? "选择用于当前控制页的设备"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .frame(width: 360)
                    }
                    .frame(maxWidth: 340, alignment: .trailing)
                }

                Text(localized(vm.localAgentRunning ? "DBT Agent 在线" : "DBT Agent 离线"))
                    .font(.caption)
                    .foregroundStyle(vm.localAgentRunning ? .green : .secondary)
                if vm.controlPageIsTaishanPi {
                    let rebootDeviceState = vm.actionAvailabilityState(for: .rebootDevice)
                    Button("设备重启") { requestRebootDevice() }
                        .disabled(!rebootDeviceState.enabled)
                        .help(rebootDeviceState.reason ?? "通过控制服务、SSH 或 Loader 恢复链路请求设备回到运行态")
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if vm.controlPageIsTaishanPi {
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
                    } else if let board = vm.detectedBoard, isRP2350BoardID(board.id) {
                        Picker("", selection: $selectedTab) {
                            Text("总览").tag(0)
                            Text("固件").tag(1)
                            if vm.rp2350Monitor.tabAvailable {
                                Text("监控").tag(2)
                                Text("通知").tag(3)
                            } else {
                                Text("通知").tag(2)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedTab == 0 {
                            ColorEasyPICO2OverviewTab(vm: vm, board: board)
                        } else if selectedTab == 1 {
                            ColorEasyPICO2FirmwareTab(vm: vm, board: board)
                        } else if selectedTab == 2, vm.rp2350Monitor.tabAvailable {
                            RP2350MonitorTab(vm: vm, board: board)
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
        .task(id: "\(vm.taishanPiDevelopmentMode.rawValue)::\(vm.controlPageBoardTitle)") {
            guard vm.controlPageIsTaishanPi else {
                return
            }
            await vm.refreshDevelopmentInstallStatus()
        }
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
                .background(Color.toolkitInputBackground)
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
            .background(Color.toolkitOverlayBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 18)
        }
    }
}

struct ContentView: View {
    @ObservedObject var vm: ToolkitViewModel
    let showDetachedModel: (SupportedBoard) -> Void
    @Environment(\.appLanguage) private var appLanguage
    @State private var selectedTab = 0
    @State private var detailBoard: SupportedBoard?
    @State private var boardCatalogViewID = UUID()
    @State private var hideCatalogHero = false
    @State private var rebootPromptPhase: RebootPromptPhase?
    @State private var rebootPromptProgress: Double = 0
    @State private var rebootPromptStatus = "正在下发重启指令…"

    var footerMessage: String {
        localized(vm.inlineErrorMessage.isEmpty ? vm.lastActionSummary : vm.inlineErrorMessage)
    }

    var footerIsError: Bool {
        !vm.inlineErrorMessage.isEmpty
    }

    private func localized(_ key: String) -> String {
        AppStrings.localized(key, language: appLanguage)
    }

    var heroAction: (() -> Void)? {
        if vm.isShowingBoardCatalog {
            if let board = vm.catalogHeroControlBoard {
                return {
                    vm.showControlPage(for: board)
                }
            }
            guard let candidate = vm.currentControllableLiveCandidate else {
                return nil
            }
            return {
                vm.chooseDetectedBoard(candidate)
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
                        .id(boardCatalogViewID)
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
            .background(Color.toolkitWindowBackground)
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
                            .fill(Color.toolkitOverlayBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if let prompt = vm.deviceSelectionPrompt, vm.activeControlDeviceCandidates.isEmpty {
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

            if let prompt = vm.rp2350FlashTargetPrompt {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                RP2350FlashTargetOverlay(vm: vm, prompt: prompt)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onChange(of: vm.connectedBoardID) { _, _ in
            selectedTab = 0
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != 3 {
                vm.selectedActivityEntry = nil
            }
        }
        .onChange(of: detailBoard?.id) { _, newValue in
            if vm.isShowingBoardCatalog, newValue == nil {
                boardCatalogViewID = UUID()
            }
        }
        .onChange(of: vm.isShowingBoardCatalog) { _, isShowingCatalog in
            if isShowingCatalog {
                detailBoard = nil
                hideCatalogHero = false
                boardCatalogViewID = UUID()
            }
        }
        .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
        .environment(\.appLanguage, vm.appLanguage)
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
                    withAnimation(.easeOut(duration: 0.28)) {
                        rebootPromptProgress = 1.0
                    }
                }
                try? await Task.sleep(for: .milliseconds(650))
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
    private var contactInfoWindowController: NSWindowController?
    private var developmentInstallWindowController: NSWindowController?
    private var developmentInstallWindowCloseGuard: WindowCloseGuard?
    private var updateWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
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
        contextMenu.removeAllItems()

        let settingsItem = NSMenuItem(title: AppStrings.localized("设置", language: vm.appLanguage), action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)

        contextMenu.addItem(.separator())

        let versionItem = NSMenuItem(title: AppStrings.localized("版本信息", language: vm.appLanguage), action: #selector(showVersionInfo), keyEquivalent: "")
        versionItem.target = self
        contextMenu.addItem(versionItem)

        let contactItem = NSMenuItem(title: AppStrings.localized("联系方式", language: vm.appLanguage), action: #selector(showContactInfo), keyEquivalent: "")
        contactItem.target = self
        contextMenu.addItem(contactItem)

        let updateItem = NSMenuItem(title: AppStrings.localized("软件更新", language: vm.appLanguage), action: #selector(showUpdateWindow), keyEquivalent: "")
        updateItem.target = self
        contextMenu.addItem(updateItem)

        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: AppStrings.localized("退出", language: vm.appLanguage), action: #selector(quitApp), keyEquivalent: "q")
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

        vm.$appLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.configureMenu()
                self?.updateStatusItemAppearance()
                self?.updateLocalizedWindowTitles()
            }
            .store(in: &cancellables)

        vm.$popoverCloseRequestID
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.closePopover()
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
        case "loader", "maskrom":
            return .systemBlue
        case "usb-ecm":
            if vm.taishanUSBECMTransportOnly() {
                return .systemOrange
            }
            if vm.status?.device?.board_id == "TaishanPi" || vm.detectedBoard?.id == "TaishanPi" {
                return (vm.status?.board?.ssh_port_open == true || vm.status?.board?.control_service == true) ? .systemGreen : .systemOrange
            }
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
        case loader
        case hidden
    }

    private func currentStatusIndicatorState() -> StatusIndicatorState {
        guard vm.localAgentRunning else {
            return .warning
        }
        if vm.taishanLoaderTransitionActive {
            return .loader
        }
        if isRP2350BoardID(vm.status?.device?.board_id) {
            let rpState = (vm.status?.rp2350?.state ?? vm.status?.usb?.mode ?? "absent").lowercased()
            switch rpState {
            case "runtime-resettable", "rp2350-runtime":
                return .online
            case "bootsel", "rp2350-bootsel":
                return .loader
            case "not-found", "absent":
                return .warning
            default:
                if vm.status?.device?.connected == true {
                    return .warning
                }
            }
        }
        let usbMode = (vm.status?.usb?.mode ?? "absent").lowercased()
        if usbMode == "absent" {
            return .warning
        }
        if usbMode == "loader" || usbMode == "maskrom" {
            return .loader
        }
        if vm.taishanUSBECMTransportOnly() {
            return .warning
        }
        if vm.status?.board?.ping == true || vm.status?.board?.ssh_port_open == true || vm.status?.board?.control_service == true {
            return .online
        }
        if usbMode == "loader" || usbMode == "maskrom" || usbMode == "usb-ecm" || usbMode == "detecting" || vm.status?.usbnet?.configured == true {
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
        case .loader:
            statusIndicatorView.isHidden = false
            layer.backgroundColor = NSColor.systemBlue.cgColor
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
        button.toolTip = vm.productDisplayName
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
        vm.refreshStatus(silent: true, force: true)
        Task { await vm.refreshDevelopmentInstallStatus() }
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

    private func updateLocalizedWindowTitles() {
        versionInfoWindowController?.window?.title = AppStrings.localized("版本信息", language: vm.appLanguage)
        contactInfoWindowController?.window?.title = AppStrings.localized("联系方式", language: vm.appLanguage)
        developmentInstallWindowController?.window?.title = AppStrings.localized("Embed Labs 开发环境", language: vm.appLanguage)
        updateWindowController?.window?.title = AppStrings.localized("Embed Labs 软件更新", language: vm.appLanguage)
        settingsWindowController?.window?.title = AppStrings.localized("设置", language: vm.appLanguage)
    }

    private func showBoardModelWindow(_ board: SupportedBoard) {
        let titleSuffixKey = boardModelOBJURL(for: board) == nil ? "外观视图" : "3D 视图"
        let titleSuffix = AppStrings.localized(titleSuffixKey, language: vm.appLanguage)
        let rootView = BoardModelStandaloneWindowView(
            board: board,
            closeAction: { [weak self] in
                self?.boardModelWindowController?.close()
            }
        )
        .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
        .environment(\.appLanguage, vm.appLanguage)

        if let controller = boardModelWindowController, let window = controller.window {
            window.title = "\(board.displayName) \(titleSuffix)"
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
        window.title = "\(board.displayName) \(titleSuffix)"
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
        window.contentViewController = NSHostingController(rootView: ToolkitInfoWindowView(page: page)
            .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
            .environment(\.appLanguage, vm.appLanguage))

        let controller = NSWindowController(window: window)
        switch page {
        case .version:
            versionInfoWindowController = controller
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

    @objc private func showContactInfo() {
        presentInfoWindow(page: .contact)
    }

    @objc private func showSettingsWindow() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.localized("设置", language: vm.appLanguage)
        window.center()
        window.setContentSize(NSSize(width: 440, height: 220))
        window.contentViewController = NSHostingController(rootView: SettingsWindowView(vm: vm)
            .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
            .environment(\.appLanguage, vm.appLanguage))

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor [weak self, weak window] in
                guard let self, window === self.settingsWindowController?.window else {
                    return
                }
                self.settingsWindowController = nil
            }
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 660),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.localized("Embed Labs 开发环境", language: vm.appLanguage)
        window.center()
        window.setContentSize(NSSize(width: 820, height: 660))
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
        window.contentViewController = NSHostingController(rootView: DevelopmentInstallWindowView(vm: vm)
            .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
            .environment(\.appLanguage, vm.appLanguage))

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
            if vm.updateConfigured,
               !vm.automaticToolkitUpdateInProgress,
               vm.toolkitUpdateStatus.remoteVersion.isEmpty
            {
                vm.checkToolkitUpdate()
            }
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 170),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.localized("Embed Labs 软件更新", language: vm.appLanguage)
        window.center()
        window.setContentSize(NSSize(width: 420, height: 170))
        window.contentViewController = NSHostingController(rootView: ToolkitUpdateWindowView(vm: vm)
            .environment(\.locale, Locale(identifier: vm.appLanguage.localeIdentifier))
            .environment(\.appLanguage, vm.appLanguage))

        let controller = NSWindowController(window: window)
        updateWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if vm.updateConfigured && !vm.automaticToolkitUpdateInProgress {
            vm.checkToolkitUpdate()
        }

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
        vm.stopOwnedLocalAgentIfNeeded()
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
