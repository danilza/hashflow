import SwiftUI

  @main
  struct HashFlowApp: App {
      @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

      var body: some Scene {
          WindowGroup {
              RootView()
          }
      }
  }

  struct RootView: View {
      @StateObject var profileVM = GameProfileViewModel()

      var body: some View {
          NavigationView {
              MainMenuView()
                  .environmentObject(profileVM)
          }
          .navigationViewStyle(StackNavigationViewStyle())
          .onOpenURL { url in
              Task {
                  do {
                      try await SupabaseService.shared.handleDeepLink(url)
                  } catch {
                      print("onOpenURL error:", error.localizedDescription)
                  }
              }
          }
      }
  }
