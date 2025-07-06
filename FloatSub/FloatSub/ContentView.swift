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

        /// Start Button (for PiP)
        startButton.frame = .init(x: margin, y: 80, width: width, height: 40)
        startButton.addTarget(self, action: #selector(ContentView.toggle), for: .touchUpInside)
        startButton.setTitle("Toggle PiP", for: .normal)
        startButton.setTitleColor(.black, for: .normal)
        startButton.backgroundColor = .white
        startButton.layer.cornerRadius = 10
        self.view.addSubview(startButton)

        // 2. 创建并配置新的直播按钮
        broadcastButton.frame = .init(x: margin, y: startButton.frame.maxY + 20, width: width, height: 40)
        broadcastButton.setTitle("Start Broadcast", for: .normal)
        broadcastButton.setTitleColor(.black, for: .normal)
        broadcastButton.backgroundColor = .white
        broadcastButton.layer.cornerRadius = 10
        self.view.addSubview(broadcastButton)

        // 3. 将屏幕广播选择器添加到新的直播按钮上
        addBroadcastPickerView(to: broadcastButton)

        /// PiP View
        pipView.frame = .init(x: margin, y: broadcastButton.frame.maxY + 20, width: width, height: 40)
        pipView.backgroundColor = .black
        self.view.addSubview(pipView)

        /// Time Label on PiPView
        timeLabel.frame = .init(x: 10, y: 0, width: width - 20, height: 40)
        timeLabel.textColor = .white
        pipView.addSubview(timeLabel)

        if #available(iOS 13.0, *) {
            timeLabel.font = .monospacedSystemFont(ofSize: 30, weight: .medium)
            timeLabel.adjustsFontSizeToFitWidth = true
        }

        // 3. 移除旧的 Timer 相关代码，替换为对 transcribedText 的订阅
        audioManager.$transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.timeLabel.text = newText
            }
            .store(in: &cancellables)
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
