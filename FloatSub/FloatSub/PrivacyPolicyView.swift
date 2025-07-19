import SwiftUI

struct PrivacyPolicyView: View {
    // 这个变量会与 App 主入口的存储状态绑定
    @Binding var hasAgreed: Bool
    
    // 这是一个回调函数，当用户点击同意时，我们会调用它来初始化友盟SDK
    var onAgree: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("隐私政策与服务条款")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 50)

            ScrollView {
                Text(
                    """
                    欢迎使用 FloatSub！

                    为了给您提供更好的服务，我们非常重视您的隐私和个人信息保护。

                    在您使用本应用前，请务必仔细阅读并理解《隐私政策》。本应用集成了友盟+ SDK，用于应用性能监控和统计分析。在您同意本政策后，友盟+ SDK 会收集您的设备信息（如IDFA、OAID等）、网络信息及应用使用情况。

                    我们承诺，将严格保护您的个人信息安全。

                    - 点击“同意”，即表示您已阅读并同意我们的《隐私政策》，我们将为您开启全部功能。
                    - 点击“不同意”，将退出应用。
                    """
                )
                .font(.body)
                .lineSpacing(8)
                .padding(.horizontal, 25)
            }

            Spacer()

            HStack(spacing: 20) {
                Button(action: {
                    // 用户不同意，退出 App
                    exit(0)
                }) {
                    Text("不同意")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }

                Button(action: {
                    // 1. 调用回调函数，执行友盟初始化
                    onAgree()
                    // 2. 更新状态，显示 App 主界面
                    hasAgreed = true
                }) {
                    Text("同意并继续")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
    }
}