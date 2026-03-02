import SwiftUI

struct PhotoThumbnailView: View {
    let fileName: String

    var body: some View {
        Group {
            if let image = PhotoFileStore.shared.loadImage(fileName: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.16)
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }
}
