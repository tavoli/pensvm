import SwiftUI

struct MarginStripView: View {
    let assetPath: String?

    private var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PENSVM")
    }

    var body: some View {
        ScrollView {
            VStack {
                if let path = assetPath {
                    let imageURL = baseDirectory.appendingPathComponent(path)
                    if let nsImage = NSImage(contentsOf: imageURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        placeholderView
                    }
                } else {
                    placeholderView
                }
            }
            .padding(8)
        }
        .background(Color.white)
    }

    private var placeholderView: some View {
        VStack {
            Spacer()
            Text("Margin")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
