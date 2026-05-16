import SwiftUI

struct PrivacyPolicyView: View {
    @Binding var hasAgreed: Bool

    var body: some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack(spacing: 15) {
                    Text("个人信息保护指引")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    ScrollView {
                        Text(
                            """
                            欢迎使用浮窗字幕！我们非常重视您的隐私和个人信息保护。

                            为了向您提供服务，在您使用本应用前，请务必仔细阅读并理解《隐私政策》。
                            
                            本应用需要请求录屏权限来捕捉手机音频用于进行语音识别。所有的捕捉均在本地完成。

                            本应用不包含任何第三方统计分析服务，仅用于语音识别功能。

                            • 点击"同意"，即表示您已阅读并同意我们的《隐私政策》，我们将为您开启全部功能。
                            • 点击"不同意"，将退出应用。
                            """
                        )
                        .font(.footnote)
                        .lineSpacing(6)
                        .padding(.horizontal)
                    }

                    VStack(spacing: 10) {
                        Button(action: {
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
        PrivacyPolicyView(hasAgreed: .constant(false))
    }
}
#endif
