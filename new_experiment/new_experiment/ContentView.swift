import SwiftUI

struct ContentView: View {
    @StateObject private var profileVM = GameProfileViewModel()

    var body: some View {
        HackerMainMenuView()
            .environmentObject(profileVM)
    }
}

#Preview {
    ContentView()
}
