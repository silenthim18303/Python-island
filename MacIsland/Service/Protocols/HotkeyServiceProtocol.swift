//
//  HotkeyServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit
import Carbon

// MARK: - Hotkey Action

enum HotkeyAction: String, CaseIterable, Codable {
    case toggleIsland    // 显示/隐藏岛
    case playPause       // 播放/暂停
    case nextTrack       // 下一首
    case previousTrack   // 上一首

    var displayName: String {
        switch self {
        case .toggleIsland:  return "显示/隐藏岛"
        case .playPause:     return "播放/暂停"
        case .nextTrack:     return "下一首"
        case .previousTrack: return "上一首"
        }
    }
}

// MARK: - Key Combo

/// 快捷键组合（修饰键 + 按键），Codable 可持久化
struct KeyCombo: Codable, Equatable, Hashable {
    /// 修饰键原始值（NSEvent.ModifierFlags.rawValue）
    let modifiers: UInt
    /// 按键 keyCode
    let keyCode: UInt16

    /// 人类可读的快捷键字符串，如 "⌥⌘I"
    var displayString: String {
        var parts = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control)   { parts += "⌃" }
        if flags.contains(.option)    { parts += "⌥" }
        if flags.contains(.shift)     { parts += "⇧" }
        if flags.contains(.command)   { parts += "⌘" }
        parts += KeyCombo.keyDisplayString(for: keyCode)
        return parts
    }

    /// 默认快捷键绑定
    static let defaultBindings: [HotkeyAction: KeyCombo] = [
        .toggleIsland:  KeyCombo(modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, keyCode: 0x22),
        .playPause:     KeyCombo(modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, keyCode: 0x23),
        .nextTrack:     KeyCombo(modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, keyCode: 0x7C),
        .previousTrack: KeyCombo(modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, keyCode: 0x7B),
    ]

    /// keyCode → 显示字符串映射
    static func keyDisplayString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7E: return "↑"
        case 0x7D: return "↓"
        case 0x24: return "↩"
        case 0x30: return "⇥"
        case 0x33: return "⌫"
        case 0x35: return "⎋"
        case 0x37: return "⌘"
        case 0x38: return "⇧"
        case 0x3A: return "⌥"
        case 0x3B: return "⌃"
        case 0x3F: return "Fn"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        case 0x31: return "␣"
        case 0x47: return "Clear"
        default:
            // 尝试用当前键盘布局解析字符
            if let char = KeyCombo.characterForKeyCode(keyCode) {
                return char.uppercased()
            }
            return "?"
        }
    }

    /// 通过 UCKeyTranslate 获取 keyCode 对应的字符（依赖当前键盘布局）
    private static func characterForKeyCode(_ keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        guard let layoutDataRef = layoutDataRef else { return nil }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let layoutPtr = CFDataGetBytePtr(layoutData)!
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0
        let status = UCKeyTranslate(
            layoutPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
            keyCode, UInt16(kUCKeyActionDisplay), 0,
            UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState, chars.count, &length, &chars
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

// MARK: - Hotkey Service Protocol

/// 全局快捷键服务 — 监听 ⌥⌘ 系列组合键
protocol HotkeyServiceProtocol: AnyObject {
    var isAccessibilityGranted: Bool { get }
    func startMonitoring()
    func stopMonitoring()
}
