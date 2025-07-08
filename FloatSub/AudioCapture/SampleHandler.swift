//
//  SampleHandler.swift
//  AudioCapture
//
//  Created by Zhengyuan Tang on 2025/3/1.
//

import ReplayKit
import os.log
import CoreFoundation

let broadcastStartedNotification = "broadcastStarted"
let broadcastFinishedNotification = "broadcastFinished"

class SampleHandler: RPBroadcastSampleHandler {
    private let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.FloatSub")
    private let logger = OSLog(subsystem: "FloatSub", category: "FloatSub.AudioCapture")
    private var appAudioDataBuffer = Data()
    private var micAudioDataBuffer = Data()
    private let targetBytesPer0_1Sec = Int(44100 * 0.1 * 4) // 转换为 Int 类型
    
    private var hasValidatedAppAudioFormat = false
    private var hasValidatedMicAudioFormat = false
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        os_log("broadcasting", log: logger, type: .info)
        // 记录广播状态到文件
        if let statusURL = containerURL?.appendingPathComponent("broadcastStatus.txt") {
            try? "broadcasting".write(to: statusURL, atomically: true, encoding: .utf8)
        }
        
        // 发送广播开始的通知
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(broadcastStartedNotification as CFString), nil, nil, true)
    }
    
    override func broadcastPaused() {
        os_log("broadcasting paused", log: logger, type: .info)
    }
    
    override func broadcastResumed() {
        os_log("broadcasting resumed", log: logger, type: .info)
    }
    
    override func broadcastFinished() {
        os_log("broadcasting finished", log: logger, type: .info)
        // 更新广播状态
        if let statusURL = containerURL?.appendingPathComponent("broadcastStatus.txt") {
            try? "finished".write(to: statusURL, atomically: true, encoding: .utf8)
        }
        
        // 发送广播结束的通知
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(broadcastFinishedNotification as CFString), nil, nil, true)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .audioApp:
            handleAppAudioSample(sampleBuffer)
        case .audioMic:
            handleMicAudioSample(sampleBuffer)
        default:
            break
        }
    }
    
    private func handleAppAudioSample(_ sampleBuffer: CMSampleBuffer) {
        // 首次验证音频格式
        if !hasValidatedAppAudioFormat {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                os_log("Cannot get formatDescription for App Audio", log: logger, type: .error)
                return
            }
            
            let audioFormat: AVAudioFormat? = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            guard let format = audioFormat else {
                os_log("Cannot get audioFormat for App Audio", log: logger, type: .error)
                return
            }
            
            let streamDesc = format.streamDescription.pointee
            os_log("Actual App Audio format: SampleRate=%f, Channels=%d, BitsPerChannel=%d, FormatFlags=%u", log: logger, type: .info, streamDesc.mSampleRate, streamDesc.mChannelsPerFrame, streamDesc.mBitsPerChannel, streamDesc.mFormatFlags)
            
            let isFormatValid = (streamDesc.mSampleRate == 44100 &&
                                 streamDesc.mChannelsPerFrame == 2 &&
                                 streamDesc.mBitsPerChannel == 16 &&
                                 (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0)
            
            guard isFormatValid else {
                os_log("App Audio format validation failed.", log: logger, type: .error)
                return
            }
            
            hasValidatedAppAudioFormat = true
            os_log("hasValidatedAppAudioFormat", log: logger, type: .info)
        }

        // 获取并处理音频数据
        writeData(from: sampleBuffer, to: "latestAudio.data", buffer: &appAudioDataBuffer)
    }
    
    private func handleMicAudioSample(_ sampleBuffer: CMSampleBuffer) {
        // 首次验证音频格式
        if !hasValidatedMicAudioFormat {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                os_log("Cannot get formatDescription for Mic Audio", log: logger, type: .error)
                return
            }
            
            let audioFormat: AVAudioFormat? = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            guard let format = audioFormat else {
                os_log("Cannot get audioFormat for Mic Audio", log: logger, type: .error)
                return
            }
            
            let streamDesc = format.streamDescription.pointee
            os_log("Actual Mic Audio format: SampleRate=%f, Channels=%d, BitsPerChannel=%d, FormatFlags=%u", log: logger, type: .info, streamDesc.mSampleRate, streamDesc.mChannelsPerFrame, streamDesc.mBitsPerChannel, streamDesc.mFormatFlags)
            
            let isFormatValid = (streamDesc.mSampleRate == 48000 &&
                                 streamDesc.mChannelsPerFrame == 1 &&
                                 streamDesc.mBitsPerChannel == 16)
            
            guard isFormatValid else {
                os_log("Mic Audio format validation failed.", log: logger, type: .error)
                return
            }
            
            hasValidatedMicAudioFormat = true
            os_log("hasValidatedMicAudioFormat", log: logger, type: .info)
        }

        // 获取并处理音频数据
        writeData(from: sampleBuffer, to: "latestMicAudio.data", buffer: &micAudioDataBuffer)
    }
    
    private func writeData(from sampleBuffer: CMSampleBuffer, to fileName: String, buffer: inout Data) {
        // 获取音频数据
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        guard CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr else { return }
        
        // 将原始数据添加到缓冲区
        let rawData = Data(bytes: dataPointer!, count: length)
        buffer.append(rawData)
        
        // 当累积到足够的数据量时处理
        if buffer.count >= Int(targetBytesPer0_1Sec) {
            let chunk = buffer.prefix(Int(targetBytesPer0_1Sec))
            buffer.removeFirst(Int(targetBytesPer0_1Sec))
            
            // 写入共享文件
            if let audioURL = containerURL?.appendingPathComponent(fileName) {
                try? chunk.write(to: audioURL)
                os_log("已写入 0.1秒音频数据到 %{public}@: %d bytes", log: logger, type: .debug, fileName, chunk.count)
            }
        }
    }
}
