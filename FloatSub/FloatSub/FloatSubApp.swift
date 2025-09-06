import SwiftUI
import UMCommon

// 1. AppDelegate: 友盟初始化被移入一个独立的函数
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 为了等待用户同意，我们不再在这里自动初始化
        return true
    }
    
    func initializeUmeng() {
        // 此函数只在用户同意隐私政策后才会被调用
        // 参见: https://developer.umeng.com/docs/147377/detail/214848
        UMConfigure.setLogEnabled(false) // 调试时开启，发布时建议关闭
        UMConfigure.initWithAppkey("6872316dbc47b67d83ad954c", channel: "App Store")
    }
}

// 您项目原有的代码，保持不变
struct ViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ContentView {
        return ContentView()
    }

    func updateUIViewController(_ uiViewController: ContentView, context: Context) {
        // No update needed
    }
}

@main
struct FloatSubApp: App {
    
    // 2. 使用 @AppStorage 来保存用户的同意状态，这样下次启动时 App 会“记住”
    @AppStorage("hasAgreedToPrivacyPolicy") private var hasAgreedToPrivacyPolicy: Bool = false
    
    // 3. 获取 AppDelegate 的引用
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // 4. 根据用户的同意状态，决定显示哪个视图
            ZStack {
                ViewControllerRepresentable()
                    .onAppear {
                        // 如果用户已经同意过（例如，非首次启动），则直接初始化SDK
                        if hasAgreedToPrivacyPolicy {
                            appDelegate.initializeUmeng()
                        }
                    }

                // Conditionally show the PrivacyPolicyView as an overlay.
                if !hasAgreedToPrivacyPolicy {
                    PrivacyPolicyView(
                        hasAgreed: $hasAgreedToPrivacyPolicy,
                        onAgree: {
                            appDelegate.initializeUmeng()
                        }
                    )
                }
            }
        }
    }
}


