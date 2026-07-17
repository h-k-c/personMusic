import SwiftUI

struct FavoriteButton: View {
    let fileId: String
    @State private var isFav: Bool
    @State private var trigger = false

    init(fileId: String, isFavorite: Bool) {
        self.fileId = fileId
        self._isFav = State(initialValue: isFavorite)
    }

    var body: some View {
        Button {
            isFav.toggle()
            trigger.toggle()
            LocalMusicManager.shared.toggleFavorite(fileId)
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 16))
                .foregroundColor(isFav ? .red : .secondary)
                .symbolEffect(.bounce, value: trigger)
        }
        .buttonStyle(.plain)
    }
}
