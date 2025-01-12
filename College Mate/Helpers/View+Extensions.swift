//
//  View+Extension.swift
//  Expense Tracker -Sagar
//
//  Created by Sagar Jangra on 29/08/2024.
//

import SwiftUI

extension View {
    @ViewBuilder
    func hSpacing(_ alignment: Alignment = .center) -> some View {
        self
        .frame(maxWidth: .infinity, alignment: alignment)
    }
    
    @ViewBuilder
    func vSpacing(_ alignment: Alignment = .center) -> some View {
        self
        .frame(maxHeight: .infinity, alignment: alignment)
    }
    
    @available(iOSApplicationExtension, unavailable)
    var safeArea: UIEdgeInsets {
        if let windowScene = (UIApplication.shared.connectedScenes.first as? UIWindowScene) {
            return windowScene.keyWindow?.safeAreaInsets ?? .zero
        }
        return .zero
    }
    
    func format(date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // Updated Profile Icon in Header View
        @ViewBuilder
        func HeaderView(size: CGSize, title: String, isShowingProfileView: Binding<Bool>) -> some View {
            HStack(spacing: 10) {
                Text(title)
                    .font(.title.bold())
                
                Spacer(minLength: 0)
                
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 55, height: 55) // Larger circle for profile
                    )
                    .shadow(radius: 5)
                    .onTapGesture {
                        isShowingProfileView.wrappedValue = true // Modify via the binding
                    }
                
            }
            .padding(.bottom, 10)
            .background {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    Divider()
                }
                .visualEffect { content, geometryProxy in
                    content
                        .opacity(headerBGOpacity(geometryProxy))
                }
                .padding(.horizontal, -15)
                .padding(.top, -(safeArea.top + 15))
            }
        }
        
        func headerBGOpacity(_ proxy: GeometryProxy) -> CGFloat {
            // Since we ignored the safe area by applying the negative padding, the minY starts with the safe area top value instead of zero.
            
            let minY = proxy.frame(in: .scrollView).minY + safeArea.top
            return minY > 0 ? 0 : (-minY/15)
        }
        
        func headerScale(_ size: CGSize, proxy: GeometryProxy) -> CGFloat {
            let minY = proxy.frame(in: .scrollView).minY
            let screenHeight = size.height
            
            let progress = minY / screenHeight
            let scale = (min(max(progress,0),1)) * 0.4
            
            return 1 + scale
        }
    
    
    
}
