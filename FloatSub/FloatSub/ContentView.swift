import UIKit
import Combine
import ReplayKit
import CoreFoundation
import AVFoundation

let broadcastStartedNotification = "broadcastStarted"
let broadcastFinishedNotification = "broadcastFinished"

class ContentView: UIViewController, UITextViewDelegate {

    // MARK: - Properties
    private let pipView = UIPiPView()
    private let audioManager = AudioRecognitionManager()
    private var cancellables = Set<AnyCancellable>()
    private var broadcastPickerAdded = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var recordingTimer: Timer?
    private var recordingDuration: Int = 0

    // MARK: - UI Components
    private let titleLabel = UILabel()
    
    // Real-time Subtitle Card
    private let subtitleCardView = UIView()
    private let subtitleTitleLabel = UILabel()
    private let listeningStatusIndicator = UIView()
    private let listeningStatusLabel = UILabel()
    private let subtitleTextView = UITextView()
    private let timerLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let pipButton = UIButton(type: .system) // Renamed from languageToggleButton

    // Text Input Card
    private let textInputCardView = UIView()
    private let textInputTitleLabel = UILabel()
    private let textInputView = UITextView()
    private let readAloudButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    
    private let placeholderText = "欢迎使用语音转字幕工具,\n请点击录音按钮开始..."
    private let textInputPlaceholderText = "在此输入要朗读的文字"

    // PiP View Label
    private let pipSubtitleLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupActions()
        // Set initial state
        updateBroadcastButton(isBroadcasting: false)
        subtitleTextView.text = placeholderText
        textInputView.text = textInputPlaceholderText
        textInputView.textColor = .lightGray
        textInputView.delegate = self

        // Dismiss keyboard on tap outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !broadcastPickerAdded {
            addBroadcastPickerView(to: recordButton)
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
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1.0)

        // Main Title
        titleLabel.text = "语音转字幕"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center

        // Setup Cards and PiP View
        setupSubtitleCard()
        setupTextInputCard()
        setupPiPView()

        // Main Stack View
        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleCardView, textInputCardView, UIView()])
        mainStack.axis = .vertical
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupSubtitleCard() {
        subtitleCardView.backgroundColor = .white
        subtitleCardView.layer.cornerRadius = 12
        subtitleCardView.translatesAutoresizingMaskIntoConstraints = false

        subtitleTitleLabel.text = "实时字幕"
        subtitleTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        listeningStatusIndicator.backgroundColor = .green
        listeningStatusIndicator.layer.cornerRadius = 4
        
        listeningStatusLabel.text = "正在监听"
        listeningStatusLabel.font = .systemFont(ofSize: 14)
        listeningStatusLabel.textColor = .gray

        let statusStack = UIStackView(arrangedSubviews: [listeningStatusIndicator, listeningStatusLabel])
        statusStack.spacing = 6
        statusStack.alignment = .center

        let headerStack = UIStackView(arrangedSubviews: [subtitleTitleLabel, UIView(), statusStack])
        headerStack.axis = .horizontal

        subtitleTextView.font = .systemFont(ofSize: 16)
        subtitleTextView.textColor = .lightGray
        subtitleTextView.backgroundColor = .clear
        subtitleTextView.isEditable = false
        subtitleTextView.isScrollEnabled = true
        
        timerLabel.text = "00:00"
        timerLabel.font = .systemFont(ofSize: 14)
        timerLabel.textColor = .gray

        let subtitleContentStack = UIStackView(arrangedSubviews: [subtitleTextView, timerLabel])
        subtitleContentStack.axis = .vertical
        subtitleContentStack.spacing = 8
        subtitleContentStack.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        subtitleContentStack.layer.cornerRadius = 8
        subtitleContentStack.isLayoutMarginsRelativeArrangement = true
        subtitleContentStack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        configureButton(recordButton, title: "开始录音", iconName: "mic.fill", primaryColor: .systemBlue, titleColor: .white)
        // Changed icon to 'pip' for Picture-in-Picture
        configureButton(pipButton, title: "", iconName: "pip", primaryColor: .lightGray, titleColor: .darkGray, isIconOnly: true)

        let buttonStack = UIStackView(arrangedSubviews: [recordButton, pipButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 15
        
        let cardStack = UIStackView(arrangedSubviews: [headerStack, subtitleContentStack, buttonStack])
        cardStack.axis = .vertical
        cardStack.spacing = 15
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        subtitleCardView.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: subtitleCardView.topAnchor, constant: 15),
            cardStack.leadingAnchor.constraint(equalTo: subtitleCardView.leadingAnchor, constant: 15),
            cardStack.trailingAnchor.constraint(equalTo: subtitleCardView.trailingAnchor, constant: -15),
            cardStack.bottomAnchor.constraint(equalTo: subtitleCardView.bottomAnchor, constant: -15),
            
            listeningStatusIndicator.widthAnchor.constraint(equalToConstant: 8),
            listeningStatusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            subtitleTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 50),
            pipButton.widthAnchor.constraint(equalTo: pipButton.heightAnchor),
            pipButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupTextInputCard() {
        textInputCardView.backgroundColor = .white
        textInputCardView.layer.cornerRadius = 12
        textInputCardView.translatesAutoresizingMaskIntoConstraints = false

        textInputTitleLabel.text = "文本输入"
        textInputTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        textInputView.font = .systemFont(ofSize: 16)
        textInputView.layer.cornerRadius = 8
        textInputView.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        textInputView.isScrollEnabled = true

        configureButton(readAloudButton, title: "朗读", iconName: "speaker.wave.2.fill", primaryColor: .systemBlue, titleColor: .white)
        configureButton(clearButton, title: "", iconName: "trash.fill", primaryColor: .lightGray, titleColor: .darkGray, isIconOnly: true)

        let buttonStack = UIStackView(arrangedSubviews: [readAloudButton, clearButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 15

        let cardStack = UIStackView(arrangedSubviews: [textInputTitleLabel, textInputView, buttonStack])
        cardStack.axis = .vertical
        cardStack.spacing = 15
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        textInputCardView.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: textInputCardView.topAnchor, constant: 15),
            cardStack.leadingAnchor.constraint(equalTo: textInputCardView.leadingAnchor, constant: 15),
            cardStack.trailingAnchor.constraint(equalTo: textInputCardView.trailingAnchor, constant: -15),
            cardStack.bottomAnchor.constraint(equalTo: textInputCardView.bottomAnchor, constant: -15),
            
            textInputView.heightAnchor.constraint(equalToConstant: 120),
            readAloudButton.heightAnchor.constraint(equalToConstant: 50),
            clearButton.widthAnchor.constraint(equalTo: clearButton.heightAnchor),
            clearButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupPiPView() {
        // Add pipView to the view hierarchy. It doesn't need to be visible on screen.
        // We give it a width and position it off-screen. Its height will be determined by the label's content.
        view.addSubview(pipView)
        pipView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pipView.widthAnchor.constraint(equalToConstant: 300), // A reasonable width for the PiP view
            pipView.topAnchor.constraint(equalTo: view.bottomAnchor), // Position it off-screen
        ])

        pipView.addSubview(pipSubtitleLabel)
        pipSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipSubtitleLabel.leadingAnchor.constraint(equalTo: pipView.leadingAnchor, constant: 8),
            pipSubtitleLabel.trailingAnchor.constraint(equalTo: pipView.trailingAnchor, constant: -8),
            pipSubtitleLabel.topAnchor.constraint(equalTo: pipView.topAnchor, constant: 8),
            pipSubtitleLabel.bottomAnchor.constraint(equalTo: pipView.bottomAnchor, constant: -8)
        ])
        pipSubtitleLabel.textColor = .white
        pipSubtitleLabel.textAlignment = .center
        pipSubtitleLabel.numberOfLines = 1
        pipSubtitleLabel.lineBreakMode = .byTruncatingHead
        if #available(iOS 13.0, *) {
            pipSubtitleLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        }
    }

    private func configureButton(_ button: UIButton, title: String, iconName: String, primaryColor: UIColor, titleColor: UIColor, isIconOnly: Bool = false) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = isIconOnly ? nil : title
            config.baseBackgroundColor = primaryColor
            config.baseForegroundColor = titleColor
            config.cornerStyle = .large
            config.image = UIImage(systemName: iconName)
            config.imagePadding = 8
            button.configuration = config
        } else {
            button.setTitle(isIconOnly ? nil : title, for: .normal)
            button.setTitleColor(titleColor, for: .normal)
            button.backgroundColor = primaryColor
            button.layer.cornerRadius = 12
            if let icon = UIImage(systemName: iconName) {
                button.setImage(icon, for: .normal)
                button.tintColor = titleColor
            }
            if !isIconOnly {
                button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
                button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
            }
        }
    }

    // MARK: - Bindings & Actions
    private func setupBindings() {
        audioManager.$transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newText in
                guard let self = self else { return }
                if newText.isEmpty {
                    self.subtitleTextView.text = self.placeholderText
                    self.subtitleTextView.textColor = .lightGray
                } else {
                    self.subtitleTextView.text = newText
                    self.subtitleTextView.textColor = .black
                    // Automatically scroll to the bottom
                    if !self.subtitleTextView.text.isEmpty {
                        let range = NSMakeRange(self.subtitleTextView.text.count - 1, 1)
                        self.subtitleTextView.scrollRangeToVisible(range)
                    }
                }
                // Update PiP label as well
                self.pipSubtitleLabel.text = newText
            }
            .store(in: &cancellables)
        
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
        pipButton.addTarget(self, action: #selector(togglePiP), for: .touchUpInside)
        readAloudButton.addTarget(self, action: #selector(readAloudTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTextTapped), for: .touchUpInside)
    }

    @objc private func togglePiP() {
        if !pipView.isPictureInPictureActive() {
            pipView.startPictureInPicture(withRefreshInterval: 1.0 / 15.0)
        } else {
            pipView.stopPictureInPicture()
        }
    }

    @objc private func readAloudTapped() {
        guard let text = textInputView.text, !text.isEmpty, text != textInputPlaceholderText else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: audioManager.currentLanguage)
        speechSynthesizer.speak(utterance)
    }
    
    @objc private func clearTextTapped() {
        textInputView.text = ""
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Timer
    private func startTimer() {
        recordingDuration = 0
        updateTimerLabel()
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 1
            self.updateTimerLabel()
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
        updateTimerLabel()
    }

    private func updateTimerLabel() {
        let minutes = recordingDuration / 60
        let seconds = recordingDuration % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Helpers
    private func updateBroadcastButton(isBroadcasting: Bool) {
        let title = isBroadcasting ? "停止录音" : "开始录音"
        let iconName = isBroadcasting ? "stop.fill" : "mic.fill"
        let color = isBroadcasting ? UIColor.systemRed : UIColor.systemBlue
        configureButton(recordButton, title: title, iconName: iconName, primaryColor: color, titleColor: .white)
        listeningStatusIndicator.backgroundColor = isBroadcasting ? .green : .gray
        listeningStatusLabel.text = isBroadcasting ? "正在监听" : "未开始"

        if isBroadcasting {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func addBroadcastPickerView(to button: UIButton) {
        let broadcastPicker = RPSystemBroadcastPickerView(frame: button.bounds)
        broadcastPicker.preferredExtension = "ZY.FloatSub.AudioCapture"
        broadcastPicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let pickerView = broadcastPicker.subviews.first {
            pickerView.backgroundColor = .clear
        }
        button.insertSubview(broadcastPicker, at: 0)
    }
    
    // MARK: - UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == textInputPlaceholderText {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = textInputPlaceholderText
            textView.textColor = .lightGray
        }
    }
}

#if DEBUG
import SwiftUI

struct ContentView_Wrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ContentView {
        return ContentView()
    }

    func updateUIViewController(_ uiViewController: ContentView, context: Context) {
        // No update logic needed for preview
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_Wrapper()
    }
}
#endif
