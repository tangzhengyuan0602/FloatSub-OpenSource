//
//  ContentView.swift
//  FloatSub
//
//  Created by Zhengyuan Tang on 7/5/2025.
//  Copyright (c) 2025 Zhengyuan Tang. All rights reserved.
//

import UIKit
import Combine
import ReplayKit
import CoreFoundation

let broadcastStartedNotification = "broadcastStarted"
let broadcastFinishedNotification = "broadcastFinished"

class ContentView: UIViewController {

    private let pipView = UIPiPView()
    private let startButton = UIButton()
    private let broadcastButton = UIButton() // 1. 新增一个直播按钮
    private let timeLabel = UILabel()

    // 2. 移除旧的 timer 和 formatter，添加 audioManager 和 cancellables
    private let audioManager = AudioRecognitionManager()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let width = CGFloat(240)
        let margin = ((self.view.bounds.width - width) / 2)

        // 1. 调整顺序：先创建和配置直播按钮
        broadcastButton.frame = .init(x: margin, y: 80, width: width, height: 40)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "开始录音"
            config.baseBackgroundColor = .white
            config.baseForegroundColor = .black
            config.cornerStyle = .medium
            // 在右侧添加边距
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20)
            broadcastButton.configuration = config
            // 将内容（文字）水平对齐到右侧
            broadcastButton.contentHorizontalAlignment = .right
        } else {
            broadcastButton.setTitle("开始录音", for: .normal)
            broadcastButton.setTitleColor(.black, for: .normal)
            broadcastButton.backgroundColor = .white
            broadcastButton.layer.cornerRadius = 10
            // 将内容（文字）水平对齐到右侧
            broadcastButton.contentHorizontalAlignment = .right
            // 在右侧添加边距
            broadcastButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        }

        self.view.addSubview(broadcastButton)

        // 2. 将屏幕广播选择器添加到直播按钮上
        addBroadcastPickerView(to: broadcastButton)

        /// Start Button (for PiP)
        startButton.frame = .init(x: margin, y: broadcastButton.frame.maxY + 20, width: width, height: 40)
        startButton.addTarget(self, action: #selector(ContentView.toggle), for: .touchUpInside)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "字幕浮窗"
            config.baseBackgroundColor = .white
            config.baseForegroundColor = .black
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20)
            startButton.configuration = config
            startButton.contentHorizontalAlignment = .right
        } else {
            startButton.setTitle("字幕浮窗", for: .normal)
            startButton.setTitleColor(.black, for: .normal)
            startButton.backgroundColor = .white
            startButton.layer.cornerRadius = 10
            startButton.contentHorizontalAlignment = .right
            startButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        }
        self.view.addSubview(startButton)

        /// PiP View
        let pipMargin = CGFloat(10) // 设置左右边距
        let pipWidth = view.bounds.width - (pipMargin * 2) // 计算新的宽度
        pipView.frame = .init(x: pipMargin, y: startButton.frame.maxY + 20, width: pipWidth, height: 40)
        pipView.backgroundColor = .black
        self.view.addSubview(pipView)

        /// Time Label on PiPView
        timeLabel.frame = .init(x: 10, y: 0, width: pipWidth - 20, height: 40)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .left
        timeLabel.lineBreakMode = .byTruncatingHead
        pipView.addSubview(timeLabel)

        if #available(iOS 13.0, *) {
            timeLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        }

        // 3. 移除旧的 Timer 相关代码，替换为对 transcribedText 的订阅
        audioManager.$transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.timeLabel.text = newText
            }
            .store(in: &cancellables)
        
        // 监听广播开始的通知
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { (center, observer, name, object, userInfo) in
            guard let observer = observer else { return }
            let mySelf = Unmanaged<ContentView>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                mySelf.updateBroadcastButton(isBroadcasting: true)
            }
        }, broadcastStartedNotification as CFString, nil, .deliverImmediately)

        // 监听广播结束的通知
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { (center, observer, name, object, userInfo) in
            guard let observer = observer else { return }
            let mySelf = Unmanaged<ContentView>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                mySelf.updateBroadcastButton(isBroadcasting: false)
            }
        }, broadcastFinishedNotification as CFString, nil, .deliverImmediately)
    }

    private func updateBroadcastButton(isBroadcasting: Bool) {
        let title = isBroadcasting ? "停止录音" : "开始录音"
        if #available(iOS 15.0, *) {
            var config = broadcastButton.configuration
            config?.title = title
            broadcastButton.configuration = config
        } else {
            broadcastButton.setTitle(title, for: .normal)
        }
    }

    // 4. 修改方法，使其可以将选择器添加到任意按钮上
    private func addBroadcastPickerView(to button: UIButton) {
        let broadcastPicker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: button.bounds.width, height: button.bounds.height)
        )
        broadcastPicker.preferredExtension = "ZY.FloatSub.AudioCapture"
        broadcastPicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.addSubview(broadcastPicker)
    }

    @objc func toggle() {
        print("Toggle button tapped")
        if (!pipView.isPictureInPictureActive()) {
            print("Starting Picture in Picture")
            pipView.startPictureInPicture(withRefreshInterval: (0.1 / 60.0))
        } else {
            print("Stopping Picture in Picture")
            pipView.stopPictureInPicture()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
