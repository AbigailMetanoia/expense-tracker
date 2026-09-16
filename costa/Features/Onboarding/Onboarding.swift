//
//  OnboardingView.swift
//  costa
//

import SwiftUI

struct OnboardingView: View {
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    CostaImageBackground(imageName: "Gradient1", alignment: .bottom).padding(.bottom, 110)
                    Spacer()
                }
            
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    Image("white_logotext")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 89, height: 28)
                        .padding(.bottom, 20)

                    Text("Own Your Money,\nShape \(Text("Your Life.").foregroundStyle(Color(red: 0.55, green: 0.65, blue: 1.0)))")
                        .foregroundStyle(.white)
                        .font(.system(size: 36, weight: .bold))
                        .padding(.bottom, 15)

                    Text("From saving smart to spending wise, your financial goals begin to rise.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 28)

                    StyledGradientButton(title: "Get Started") {
                        showLogin = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthController())
}
