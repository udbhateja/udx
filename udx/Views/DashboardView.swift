import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var workoutLogs: [WorkoutLog]
    @Query private var workoutPlans: [WorkoutPlan]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Workout Calendar
                    CalendarSummaryView()
                    
                    // Workout Stats
                    StatsCardView(
                        totalWorkouts: workoutPlans.count,
                        thisMonth: workoutPlans.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count,
                        thisWeek: workoutPlans.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count
                    )
                    
                    // Placeholder for charts
                    Text("Progress Charts")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(Text("Charts will appear here"))
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct CalendarSummaryView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Workout Calendar")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Placeholder for calendar
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 250)
                .overlay(Text("Calendar will appear here"))
        }
    }
}

struct StatsCardView: View {
    var totalWorkouts: Int
    var thisMonth: Int
    var thisWeek: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Your Stats")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                StatBox(title: "Total", value: "\(totalWorkouts)", color: .blue)
                StatBox(title: "This Month", value: "\(thisMonth)", color: .green)
                StatBox(title: "This Week", value: "\(thisWeek)", color: .orange)
            }
        }
    }
}

struct StatBox: View {
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}
