import SwiftUI

// MARK: - UIViewControllerRepresentable
// 这个结构体将 UIKit 的 ContentView 封装成一个 SwiftUI 视图
struct ContentViewRepresentable: UIViewControllerRepresentable {
    // 当 SwiftUI 需要创建视图时调用
    func makeUIViewController(context: Context) -> ContentView {
        return ContentView()
    }

    // 当视图需要更新时调用（在这里我们不需要做什么）
    func updateUIViewController(_ uiViewController: ContentView, context: Context) {}
}

// MARK: - PreviewProvider
// 这个结构体为 Xcode 提供了预览
struct ContentView_Preview: PreviewProvider {
    static var previews: some View {
        ContentViewRepresentable()
            .edgesIgnoringSafeArea(.all) // 可以选择忽略安全区域以全屏预览
            .previewDevice("iPhone 14 Pro") // 您可以更改为您想预览的设备
    }
}