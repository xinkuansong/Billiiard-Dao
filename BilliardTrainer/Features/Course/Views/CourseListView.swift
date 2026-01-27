//
//  CourseListView.swift
//  BilliardTrainer
//
//  课程列表视图
//

import SwiftUI

struct CourseListView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 免费课程
                    CourseSection(
                        title: "入门课程",
                        subtitle: "免费",
                        courses: Course.freeCourses,
                        isLocked: false
                    )
                    
                    // 基础课程
                    CourseSection(
                        title: "基础课程",
                        subtitle: "¥18",
                        courses: Course.basicCourses,
                        isLocked: true
                    )
                    
                    // 进阶课程
                    CourseSection(
                        title: "进阶课程",
                        subtitle: "¥25",
                        courses: Course.advancedCourses,
                        isLocked: true
                    )
                    
                    // 高级课程
                    CourseSection(
                        title: "高级课程",
                        subtitle: "¥20",
                        courses: Course.expertCourses,
                        isLocked: true
                    )
                }
                .padding()
            }
            .navigationTitle("课程")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Course Section
struct CourseSection: View {
    let title: String
    let subtitle: String
    let courses: [Course]
    let isLocked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isLocked ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(isLocked ? .orange : .green)
                    .cornerRadius(4)
                
                Spacer()
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                }
            }
            
            // 课程卡片
            ForEach(courses) { course in
                CourseCard(course: course, isLocked: isLocked)
            }
        }
    }
}

// MARK: - Course Card
struct CourseCard: View {
    let course: Course
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 课程编号
            Text("L\(course.id)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(isLocked ? Color.gray : Color.green)
                .cornerRadius(8)
            
            // 课程信息
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(course.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 状态/时长
            VStack(alignment: .trailing, spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                } else if course.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                }
                
                Text("\(course.duration)分钟")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .opacity(isLocked ? 0.7 : 1)
    }
}

// MARK: - Course Model
struct Course: Identifiable {
    let id: Int
    let title: String
    let description: String
    let duration: Int  // 分钟
    var isCompleted: Bool = false
    
    // 免费课程 L1-L3
    static let freeCourses: [Course] = [
        Course(id: 1, title: "认识台球", description: "规则、术语、基本概念", duration: 5, isCompleted: true),
        Course(id: 2, title: "瞄准入门", description: "直球瞄准、厚薄球概念", duration: 8, isCompleted: true),
        Course(id: 3, title: "第一次进球", description: "完成10个直球进袋", duration: 10)
    ]
    
    // 基础课程 L4-L8
    static let basicCourses: [Course] = [
        Course(id: 4, title: "角度球基础", description: "30°/45°/60°角度进球", duration: 12),
        Course(id: 5, title: "打点入门", description: "中杆、高杆、低杆", duration: 12),
        Course(id: 6, title: "分离角原理", description: "预判母球碰撞后方向", duration: 10),
        Course(id: 7, title: "左右塞基础", description: "塞球对库边的影响", duration: 12),
        Course(id: 8, title: "单球走位", description: "进球+控制母球落点", duration: 15)
    ]
    
    // 进阶课程 L9-L14
    static let advancedCourses: [Course] = [
        Course(id: 9, title: "翻袋入门", description: "一库翻袋原理与练习", duration: 12),
        Course(id: 10, title: "颗星公式基础", description: "一库颗星计算方法", duration: 15),
        Course(id: 11, title: "K球技术", description: "库边解球基础", duration: 12),
        Course(id: 12, title: "传球与组合", description: "传球、组合球打法", duration: 12),
        Course(id: 13, title: "多球走位", description: "2-3球连续进球规划", duration: 15),
        Course(id: 14, title: "塞修正进阶", description: "塞对翻袋/K球的影响", duration: 12)
    ]
    
    // 高级课程 L15-L18
    static let expertCourses: [Course] = [
        Course(id: 15, title: "解球策略", description: "薄解、多库解球", duration: 15),
        Course(id: 16, title: "安全球与防守", description: "做斯诺克、安全球", duration: 12),
        Course(id: 17, title: "清台思路", description: "7+1球最优进球顺序", duration: 15),
        Course(id: 18, title: "炸球与散球", description: "打散球堆的时机与技巧", duration: 12)
    ]
}

#Preview {
    CourseListView()
}
