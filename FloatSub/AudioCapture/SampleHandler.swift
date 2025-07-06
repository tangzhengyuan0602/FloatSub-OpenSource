//
//  SampleHandler.swift
//  AudioCapture
//
//  Created by Zhengyuan Tang on 2025/3/1.
//

import ReplayKit
import os.log

class SampleHandler: RPBroadcastSampleHandler {
    private let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.FloatSub")
    private let logger = OSLog(subsystem: "FloatSub", category: "FloatSub.AudioCapture")
    private var audioDataBuffer = Data()
    private let targetBytesPer0_1Sec = Int(44100 * 0.1 * 4) // 转换为 Int 类型
    
    private var hasValidatedAudioFormat = false
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        os_log("broadcasting", log: logger, type: .info)
        // 记录广播状态到文件
        if let statusURL = containerURL?.appendingPathComponent("broadcastStatus.txt") {
            try? "broadcasting".write(to: statusURL, atomically: true, encoding: .utf8)
        }
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
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .audioApp:
            handleAudioSample(sampleBuffer)
        default:
            break
        }
    }
    
    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        // 首次验证音频格式
        if !hasValidatedAudioFormat {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                os_log("Cannot get formatDescription", log: logger, type: .error)
                return
            }
            
            let audioFormat: AVAudioFormat? = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            guard let format = audioFormat else {
                os_log("Cannot get audioFormat", log: logger, type: .error)
                return
            }
            
            let streamDesc = format.streamDescription.pointee
            guard streamDesc.mSampleRate == 44100,
                  streamDesc.mChannelsPerFrame == 2,
                  streamDesc.mBitsPerChannel == 16,
                  (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0 else {
                return
            }
            
            hasValidatedAudioFormat = true
            os_log("hasValidatedAudioFormat", log: logger, type: .info)
        }

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
        audioDataBuffer.append(rawData)
        
        // 当累积到足够的数据量时处理
        if audioDataBuffer.count >= Int(targetBytesPer0_1Sec) {
            let chunk = audioDataBuffer.prefix(Int(targetBytesPer0_1Sec))
            audioDataBuffer.removeFirst(Int(targetBytesPer0_1Sec))
            
            // 写入共享文件
            if let audioURL = containerURL?.appendingPathComponent("latestAudio.data") {
                try? chunk.write(to: audioURL)
                os_log("已写入 0.1秒音频数据: %d bytes", log: logger, type: .debug, chunk.count)
            }
        }
    }
}
