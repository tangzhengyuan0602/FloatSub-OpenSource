import SwiftUI

struct PrivacyPolicyView: View {
    // 这个变量会与 App 主入口的存储状态绑定
    @Binding var hasAgreed: Bool
    
    // 这是一个回调函数，当用户点击同意时，我们会调用它来初始化友盟SDK
    var onAgree: () -> Void

    var body: some View {
        // 1. 半透明背景
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                // 2. 居中弹窗卡片
                VStack(spacing: 15) {
                    Text("个人信息保护指引")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    ScrollView {
                        Text(
                            """
                            欢迎使用 浮窗字幕！我们非常重视您的隐私和个人信息保护。

                            为了向您提供服务，在您使用本应用前，请务必仔细阅读并理解《隐私政策》。
                            
                            本应用需要请求录屏权限来捕捉手机音频用于进行识别。所有的捕捉均在本地完成。此外，本应用集成了阿里旗下友盟+ SDK，用于应用性能监控和统计分析。友盟+ SDK 会收集您的设备信息（如IDFA、OAID等）、网络信息及应用使用情况。该信息仅用于应用的故障分析和性能监控。我们依赖阿里旗下友盟+严格保护您的个人信息安全。此外本应用不收集任何用户信息。

                            • 点击“同意”，即表示您已阅读并同意我们的《隐私政策》，我们将为您开启全部功能。
                            • 点击“不同意”，将退出应用。
                            """
                        )
                        .font(.footnote)
                        .lineSpacing(6)
                        .padding(.horizontal)
                    }

                    VStack(spacing: 10) {
                        Button(action: {
                            // 1. 调用回调函数，执行友盟初始化
                            onAgree()
                            // 2. 更新状态，显示 App 主界面
                            hasAgreed = true
                        }) {
                            Text("同意")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            // 用户不同意，退出 App
                            exit(0)
                        }) {
                            Text("不同意")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding([.horizontal, .bottom])

                }
                .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.height * 0.6)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 10)
            )
    }
}

#if DEBUG
struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView(hasAgreed: .constant(false), onAgree: {})
    }
}
#endif
