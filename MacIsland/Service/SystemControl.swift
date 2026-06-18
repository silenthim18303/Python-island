//
//  SystemControl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import CoreAudio
import AudioToolbox
import CoreGraphics

// MARK: - System Control

/// 系统音量和亮度控制
final class SystemControl {
    static let shared = SystemControl()

    // MARK: - Volume

    func getVolume() -> Float {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return 0.5 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : 0.5
    }

    func setVolume(_ volume: Float) {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }

    private func getDefaultOutputDeviceID() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectSystemObject)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    // MARK: - Brightness (DisplayServices via dlopen)

    private static let dsHandle: UnsafeMutableRawPointer? = {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        return dlopen(path, RTLD_NOW)
    }()

    private typealias GetBrightFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightFunc = @convention(c) (UInt32, Float) -> Int32

    private static let getBrightFn: GetBrightFunc? = {
        guard let handle = dsHandle,
              let ptr = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(ptr, to: GetBrightFunc.self)
    }()

    private static let setBrightFn: SetBrightFunc? = {
        guard let handle = dsHandle,
              let ptr = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(ptr, to: SetBrightFunc.self)
    }()

    func getBrightness() -> Float {
        guard let fn = Self.getBrightFn else { return 0.5 }
        var brightness: Float = 0
        _ = fn(CGMainDisplayID(), &brightness)
        return brightness
    }

    func setBrightness(_ brightness: Float) {
        guard let fn = Self.setBrightFn else { return }
        let val = max(0, min(1, brightness))
        _ = fn(CGMainDisplayID(), val)
    }
}
