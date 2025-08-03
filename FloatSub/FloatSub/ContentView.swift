import UIKit
import Combine
import ReplayKit
import CoreFoundation
import AVFoundation

let broadcastStartedNotification = "broadcastStarted"
let broadcastFinishedNotification = "broadcastFinished"

class ContentView: UIViewController {

    // MARK: - Properties
    private let pipView = UIPiPView()
    private let startButton = UIButton()
    private let broadcastButton = UIButton()
    private let timeLabel = UILabel()
    private let inputTextField = UITextField()
    private let readAloudButton = UIButton()
    private let clearButton = UIButton() // 添加清空按钮
    private let languageSegmentedControl = UISegmentedControl(items: ["中文", "英文"]) // 添加语言选择控件
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let audioManager = AudioRecognitionManager()
    private var cancellables = Set<AnyCancellable>()
    private var broadcastPickerAdded = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupActions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 在视图完全出现后添加选择器，此时按钮的 frame 已被正确计算
        if !broadcastPickerAdded {
            addBroadcastPickerView(to: broadcastButton)
            broadcastPickerAdded = true
        }
    }
    
    deinit {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, CFNotificationName(broadcastStartedNotification as CFString), nil)
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, CFNotificationName(broadcastFinishedNotification as CFString), nil)
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Gradient Background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor, UIColor.black.cgColor]
        view.layer.insertSublayer(gradientLayer, at: 0)

        // Main Stack View
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 30
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "浮窗字幕"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textAlignment = .center
        
        // 添加醒目的提醒标签
        let reminderLabel = UILabel()
        reminderLabel.text = "点击开始录音后会需要申请录屏权限用来获得手机音频和麦克风音频"
        reminderLabel.textColor = .systemYellow  // 使用系统黄色使其更醒目
        reminderLabel.font = .systemFont(ofSize: 14, weight: .medium)  // 稍微增大字体
        reminderLabel.textAlignment = .center
        reminderLabel.numberOfLines = 0
        reminderLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)  // 添加背景色
        reminderLabel.layer.cornerRadius = 8  // 添加圆角
        reminderLabel.clipsToBounds = true
        reminderLabel.setContentCompressionResistancePriority(.required, for: .vertical)  // 防止被压缩
        
        // Control Buttons Stack
        let controlsStack = UIStackView(arrangedSubviews: [broadcastButton, startButton])
        controlsStack.spacing = 15
        controlsStack.distribution = .fillEqually
        
        // Subtitle Display View (PiP View)
        pipView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        pipView.layer.cornerRadius = 12
        pipView.clipsToBounds = true
        pipView.addSubview(timeLabel)
        timeLabel.frame = .init(x: 15, y: 0, width: view.bounds.width - 60, height: 40)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .left
        timeLabel.lineBreakMode = .byTruncatingHead
        if #available(iOS 13.0, *) {
            timeLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        }

        // Language Selection
        languageSegmentedControl.selectedSegmentIndex = 0 // 默认选择中文
        languageSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        languageSegmentedControl.selectedSegmentTintColor = .systemBlue
        
        // 设置文本颜色
        let font = UIFont.systemFont(ofSize: 16, weight: .medium)
        languageSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: font], for: .normal)
        languageSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: font], for: .selected)

        // Text-to-Speech Section
        // 创建一个垂直栈视图来包含输入框和按钮
        let ttsStack = UIStackView()
        ttsStack.axis = .vertical
        ttsStack.spacing = 10
        
        ttsStack.addArrangedSubview(inputTextField)
        
        // 创建一个水平栈视图来包含朗读和清空按钮
        let buttonStack = UIStackView(arrangedSubviews: [readAloudButton, clearButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 15
        
        // 将按钮栈视图添加到文本输入框下方
        ttsStack.addArrangedSubview(buttonStack)
        
        inputTextField.placeholder = "在此输入要朗读的文字"
        inputTextField.borderStyle = .none
        inputTextField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        inputTextField.textColor = .white
        inputTextField.layer.cornerRadius = 10
        inputTextField.setLeftPaddingPoints(15)
        inputTextField.font = .systemFont(ofSize: 16)
        
        configureButton(readAloudButton, title: "朗读", iconName: "speaker.wave.2.fill", primaryColor: .systemGreen)
        configureButton(clearButton, title: "清空", iconName: "trash.fill", primaryColor: .systemGray) // 配置清空按钮
        
        // Add components to main stack (正确的添加顺序)
        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(reminderLabel)  // 提醒标签放在标题下面
        mainStack.addArrangedSubview(controlsStack)  // 控制按钮放在提醒标签下面
        mainStack.addArrangedSubview(languageSegmentedControl) // 语言选择控件
        mainStack.addArrangedSubview(pipView)  // 字幕浮窗视图
        mainStack.addArrangedSubview(ttsStack)  // 文本朗读区域
        
        configureButton(broadcastButton, title: "开始录音", iconName: "record.circle", primaryColor: .systemRed)
        configureButton(startButton, title: "字幕浮窗", iconName: "pip", primaryColor: .systemBlue)

        // Layout Constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            pipView.heightAnchor.constraint(equalToConstant: 40),
            inputTextField.heightAnchor.constraint(equalToConstant: 50),
            broadcastButton.heightAnchor.constraint(equalToConstant: 50),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            readAloudButton.heightAnchor.constraint(equalToConstant: 50),
            clearButton.widthAnchor.constraint(equalToConstant: 80), // 设置清空按钮宽度
            languageSegmentedControl.heightAnchor.constraint(equalToConstant: 40) // 设置语言选择控件高度
        ])
    }

    private func configureButton(_ button: UIButton, title: String, iconName: String, primaryColor: UIColor) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.baseBackgroundColor = primaryColor
            config.baseForegroundColor = .white
            config.cornerStyle = .large
            config.image = UIImage(systemName: iconName)
            config.imagePadding = 8
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = primaryColor
            button.layer.cornerRadius = 12
            if let icon = UIImage(systemName: iconName) {
                button.setImage(icon, for: .normal)
            }
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        }
    }

    // MARK: - Bindings & Actions
    private func setupBindings() {
        // Subscribe to transcribed text
        audioManager.$transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.timeLabel.text = newText
            }
            .store(in: &cancellables)
        
        // Listen for broadcast notifications
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { _, obs, _, _, _ in
            guard let obs = obs else { return }
            let mySelf = Unmanaged<ContentView>.fromOpaque(obs).takeUnretainedValue()
            DispatchQueue.main.async {
                mySelf.updateBroadcastButton(isBroadcasting: true)
            }
        }, broadcastStartedNotification as CFString, nil, .deliverImmediately)

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { _, obs, _, _, _ in
            guard let obs = obs else { return }
            let mySelf = Unmanaged<ContentView>.fromOpaque(obs).takeUnretainedValue()
            DispatchQueue.main.async {
                mySelf.updateBroadcastButton(isBroadcasting: false)
            }
        }, broadcastFinishedNotification as CFString, nil, .deliverImmediately)
    }
    
    private func setupActions() {
        startButton.addTarget(self, action: #selector(togglePiP), for: .touchUpInside)
        readAloudButton.addTarget(self, action: #selector(readAloudTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTextTapped), for: .touchUpInside) // 添加清空按钮事件
        languageSegmentedControl.addTarget(self, action: #selector(languageChanged), for: .valueChanged) // 添加语言选择事件
    }

    @objc private func togglePiP() {
        if !pipView.isPictureInPictureActive() {
            pipView.startPictureInPicture(withRefreshInterval: 1.0 / 15.0)
        } else {
            pipView.stopPictureInPicture()
        }
    }

    @objc private func readAloudTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        
        // 根据语言选择设置语音
        let language = languageSegmentedControl.selectedSegmentIndex == 0 ? "zh-CN" : "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        speechSynthesizer.speak(utterance)
    }
    
    // 添加清空按钮点击事件
    @objc private func clearTextTapped() {
        inputTextField.text = ""
    }
    
    // 添加语言选择改变事件
    @objc private func languageChanged() {
        let language = languageSegmentedControl.selectedSegmentIndex == 0 ? "zh-CN" : "en-US"
        audioManager.currentLanguage = language
    }

    // MARK: - Helpers
    private func updateBroadcastButton(isBroadcasting: Bool) {
        let title = isBroadcasting ? "停止录音" : "开始录音"
        let iconName = isBroadcasting ? "stop.circle.fill" : "record.circle"
        configureButton(broadcastButton, title: title, iconName: iconName, primaryColor: .systemRed)
    }

    private func addBroadcastPickerView(to button: UIButton) {
        // 使用按钮的 bounds 来初始化选择器，此时 bounds 应该是正确的尺寸
        let broadcastPicker = RPSystemBroadcastPickerView(frame: button.bounds)
        broadcastPicker.preferredExtension = "ZY.FloatSub.AudioCapture"
        broadcastPicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let pickerView = broadcastPicker.subviews.first {
            pickerView.backgroundColor = .clear
        }
        // 将选择器插入到按钮视图层级的最底层，以确保按钮的标题和图标在其之上
        button.insertSubview(broadcastPicker, at: 0)
    }
}

// Helper extension for UITextField padding
extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}
