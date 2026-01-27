//
//  ContentView.swift
//  BilliardTrainer
//
//  主内容视图 - 根据状态显示引导页或主界面
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showOnboarding: Bool = false
    
    var body: some View {
        Group {
            if appState.isFirstLaunch && showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            showOnboarding = appState.isFirstLaunch
        }
    }
}

// MARK: - Main Tab View
/// 主界面底部Tab导航
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case course
        case training
        case statistics
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            CourseListView()
                .tabItem {
                    Label("课程", systemImage: "book.fill")
                }
                .tag(Tab.course)
            
            TrainingListView()
                .tabItem {
                    Label("训练", systemImage: "target")
                }
                .tag(Tab.training)
            
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(Tab.statistics)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.green) // 台球绿色主题
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
