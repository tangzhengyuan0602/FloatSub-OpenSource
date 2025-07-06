import Foundation
import Speech
import AVFoundation
import os.log

private let logger = Logger(subsystem: "FloatSub", category: "FloatSub.AudioRecognition")
    
class AudioRecognitionManager: ObservableObject {
    @Published var transcribedText: String = ""
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timer: Timer?
    private let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.FloatSub")
    
    init() {
        // 初始化语音识别器并配置
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
        speechRecognizer.defaultTaskHint = .dictation
        speechRecognizer.queue = OperationQueue()

        setupTimer()
        requestAuthorization()
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkForNewAudioData()
        }
    }
    
    private func processAudioData(_ data: Data) {
        logger.info("开始处理音频数据: \(data.count) bytes")
        
        guard let pcmBuffer = preprocessAudio(data: data) else {
            logger.error("音频预处理失败")
            return
        }
        
        if recognitionRequest == nil {
            logger.info("创建新的识别请求")
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                self.recognitionTask = self.speechRecognizer.recognitionTask(with: self.recognitionRequest!) { result, error in
                    if let error = error {
                        logger.error("识别错误: \(error.localizedDescription)")
                        return
                    }
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        logger.info("识别结果: \(text)")
                        DispatchQueue.main.async {
                            self.transcribedText = text
                        }
                    }
                }
            }
        }
        
        recognitionRequest?.append(pcmBuffer)
        logger.debug("已添加音频数据到识别请求")
    }
    
    private func preprocessAudio(data: Data) -> AVAudioPCMBuffer? {
        // 步骤1: 分离左右声道并转换字节序
        var leftSamples = [Int16]()
        var rightSamples = [Int16]()
        
        data.withUnsafeBytes { ptr in
            let samples = ptr.bindMemory(to: Int16.self)
            let count = ptr.count / MemoryLayout<Int16>.size
            for i in stride(from: 0, to: count, by: 2) {
                let left = Int16(bigEndian: samples[i])
                let right = Int16(bigEndian: samples[i + 1])
                leftSamples.append(left)
                rightSamples.append(right)
            }
        }
        
        // 步骤2: 混合为单声道
        let monoData = leftSamples.enumerated().map { (index, left) in
            let right = rightSamples[index]
            return Int16((Int32(left) + Int32(right)) / 2)
        }
        
        let finalData = Data(bytes: monoData, count: monoData.count * MemoryLayout<Int16>.size)
        
        // 步骤3: 创建单通道 PCM Buffer
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(monoData.count)) else {
            return nil
        }
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        finalData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.baseAddress!.assumingMemoryBound(to: Int16.self)
            memcpy(pcmBuffer.int16ChannelData![0], int16Ptr, finalData.count)
        }
        
        return pcmBuffer
    }
    
    private func checkForNewAudioData() {
        guard let statusURL = containerURL?.appendingPathComponent("broadcastStatus.txt") else {
            logger.error("获取状态文件路径失败")
            return
        }
        do {
            let status = try String(contentsOf: statusURL, encoding: .utf8)
            logger.debug("当前广播状态: \(status)")
            if status == "finished" {
                cleanupBroadcastData()
                DispatchQueue.main.async {
                    // 确保在主线程更新UI相关的属性
                    if self.transcribedText != "" { // 只有在文本非空时才清空，避免不必要的UI更新
                        self.transcribedText = ""
                    }
                }
                return // 清理后当前周期不再处理，等待下一次Timer触发
            }
            guard status == "broadcasting" else {
                logger.debug("广播未开始或状态不是broadcasting")
                return
            }
            guard let audioURL = containerURL?.appendingPathComponent("latestAudio.data") else {
                logger.error("获取共享音频文件路径失败")
                return
            }
            let data = try Data(contentsOf: audioURL)
            logger.info("成功读取音频数据: \(data.count) bytes")
            processAudioData(data)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                // 文件不存在，这在广播启动前或结束后是正常情况
                logger.debug("广播状态文件 'broadcastStatus.txt' 不存在，可能广播尚未开始或已结束。")
                // 可以在这里也确保 transcribedText 是空的，如果之前是 finished 状态后被删除
                DispatchQueue.main.async {
                    if self.transcribedText != "" {
                        self.transcribedText = ""
                    }
                }
            } else {
                // 其他类型的读取错误
                logger.error("读取广播状态或音频数据失败: \(error.localizedDescription)")
            }
        } catch {
            // 其他未知错误
            logger.error("处理广播数据时发生未知错误: \(error.localizedDescription)")
        }
    }

    private func cleanupBroadcastData() {
        logger.info("清理广播数据")
        
        // 清理状态文件
        if let statusURL = containerURL?.appendingPathComponent("broadcastStatus.txt") {
            try? FileManager.default.removeItem(at: statusURL)
        }
        
        // 清理音频数据文件
        if let audioURL = containerURL?.appendingPathComponent("latestAudio.data") {
            try? FileManager.default.removeItem(at: audioURL)
        }

        // 重置识别相关状态
        // 这些操作应该是幂等的，多次调用不应产生副作用
        recognitionRequest?.endAudio() // 结束当前请求（如果有）
        recognitionRequest = nil
        recognitionTask?.cancel() // 取消当前任务（如果有）
        recognitionTask = nil
        // transcribedText 的清空移到 checkForNewAudioData 中，确保在主线程执行
        // 并且只在状态变为 finished 或文件不存在时清空，避免在 broadcasting 状态下被意外清空
    }

    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            let statusString = switch status {
                case .authorized: "已授权"
                case .denied: "已拒绝"
                case .restricted: "受限"
                case .notDetermined: "未决定"
                @unknown default: "未知状态"
            }
            logger.info("语音识别授权状态: \(statusString)")
        }
    }
    
    deinit {
        timer?.invalidate()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}