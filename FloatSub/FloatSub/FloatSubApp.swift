import SwiftUI

// 1. AppDelegate: 开源版本移除了友盟统计
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
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
    
    // 2. 使用 @AppStorage 来保存用户的同意状态
    @AppStorage("hasAgreedToPrivacyPolicy") private var hasAgreedToPrivacyPolicy: Bool = false
    
    // 3. 获取 AppDelegate 的引用
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // 开源版本：直接显示主界面，不包含友盟统计
            ZStack {
                ViewControllerRepresentable()

                if !hasAgreedToPrivacyPolicy {
                    PrivacyPolicyView(hasAgreed: $hasAgreedToPrivacyPolicy)
                }
            }
        }
    }
}
