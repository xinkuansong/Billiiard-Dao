//
//  OnboardingView.swift
//  BilliardTrainer
//
//  首次启动引导页
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "欢迎使用球道",
            description: "专业的中式八球训练App\n用科学的方法提升你的球技",
            imageName: "sportscourt.fill",
            color: .green
        ),
        OnboardingPage(
            title: "系统化课程",
            description: "从基础到进阶的18节课程\n瞄准、杆法、走位全覆盖",
            imageName: "book.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "真实物理引擎",
            description: "专业级物理模拟\n2D/3D视角自由切换",
            imageName: "cube.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack {
            // 页面内容
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // 页面指示器
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            
            // 按钮
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    isPresented = false
                }
            }) {
                Text(currentPage < pages.count - 1 ? "下一步" : "开始使用")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            
            // 跳过按钮
            if currentPage < pages.count - 1 {
                Button("跳过") {
                    isPresented = false
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 图标
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.color)
            
            // 标题
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
            
            // 描述
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
