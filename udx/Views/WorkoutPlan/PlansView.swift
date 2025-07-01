import SwiftUI
import SwiftData

struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.date, order: .reverse) private var workoutPlans: [WorkoutPlan]
    @State private var showingAddPlan = false
    @State private var showingClonePlan = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedDate: Date = Date()
    @State private var showTemplates = false
    
    enum ViewMode {
        case list, calendar
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode toggle
                Picker("View Mode", selection: $viewMode) {
                    Label("List", systemImage: "list.bullet")
                        .tag(ViewMode.list)
                    Label("Calendar", systemImage: "calendar")
                        .tag(ViewMode.calendar)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected mode
                Group {
                    if viewMode == .list {
                        workoutListView
                    } else {
                        workoutCalendarView
                    }
                }
            }
            .navigationTitle("Workout Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewMode == .list {
                        Button(showTemplates ? "Show Plans" : "Show Templates") {
                            showTemplates.toggle()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddPlan = true
                        } label: {
                            Label("Create New", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showingClonePlan = true
                        } label: {
                            Label("Clone Workout", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                CreatePlanView()
            }
            .sheet(isPresented: $showingClonePlan) {
                CloneWorkoutView()
            }
        }
    }
    
    // List view (existing functionality)
    private var workoutListView: some View {
        let filteredPlans = workoutPlans.filter { showTemplates ? $0.isTemplate : !$0.isTemplate }
        
        return List {
            if filteredPlans.isEmpty {
                ContentUnavailableView(
                    showTemplates ? "No Templates" : "No Workout Plans",
                    systemImage: showTemplates ? "doc.text" : "dumbbell",
                    description: Text(showTemplates ? "Save a workout as template to reuse it" : "Tap the + button to create a new workout plan")
                )
            } else if showTemplates {
                // Show templates
                Section("Workout Templates") {
                    ForEach(filteredPlans) { plan in
                        planRow(for: plan)
                    }
                }
            } else {
                // Today's workouts
                let todayPlans = filteredPlans.filter { Calendar.current.isDateInToday($0.date) }
                if !todayPlans.isEmpty {
                    Section(todayPlans.count == 1 ? "Today's Workout" : "Today's Workouts") {
                        ForEach(todayPlans) { plan in
                            planRow(for: plan)
                        }
                    }
                }
                
                // Upcoming workouts
                let upcomingPlans = filteredPlans.filter {
                    $0.date > Date() && !Calendar.current.isDateInToday($0.date)
                }
                
                if !upcomingPlans.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingPlans) { plan in
                            planRow(for: plan)
                        }
                    }
                }
                
                // Past workouts
                let pastPlans = filteredPlans.filter {
                    $0.date < Date() && !Calendar.current.isDateInToday($0.date)
                }
                
                if !pastPlans.isEmpty {
                    Section("Past Workouts") {
                        ForEach(pastPlans) { plan in
                            planRow(for: plan)
                        }
                    }
                }
            }
        }
    }
    
    // New calendar view
    private var workoutCalendarView: some View {
        VStack {
            // Month header
            monthHeader
            
            // Weekday headers
            weekdayHeader
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                let dates = generateCalendarDates()
                
                ForEach(dates, id: \.self) { date in
                    calendarCell(for: date)
                }
            }
            .padding(.horizontal)
            
            // Selected date workouts
            if let selectedDateWorkouts = getWorkoutsForDate(selectedDate), !selectedDateWorkouts.isEmpty {
                List {
                    Section(header: Text(formatDate(selectedDate))) {
                        ForEach(selectedDateWorkouts) { plan in
                            planRow(for: plan)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: 250)
            } else {
                ContentUnavailableView(
                    "No workouts on \(formatDate(selectedDate))",
                    systemImage: "calendar.badge.minus",
                    description: Text("Tap the + button to add a workout")
                )
                .frame(height: 250)
            }
        }
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            
            Text(formatMonth(selectedDate))
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var weekdayHeader: some View {
        HStack {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    private func calendarCell(for date: Date) -> some View {
        let sameMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let workouts = getWorkoutsForDate(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        
        return Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16))
                    .fontWeight(isToday ? .bold : .regular)
                
                if let workouts = workouts, !workouts.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<min(workouts.count, 3), id: \.self) { index in
                            Circle()
                                .fill(colorForWorkout(workouts[index]))
                                .frame(width: 6, height: 6)
                        }
                        
                        if workouts.count > 3 {
                            Text("+\(workouts.count - 3)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
            )
            .foregroundColor(sameMonth ? .primary : .secondary.opacity(0.5))
        }
    }
    
    // Helper functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func generateCalendarDates() -> [Date] {
        let calendar = Calendar.current
        
        // Get start of the month
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let startOfMonth = calendar.date(from: components),
              let firstWeekday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }
        
        // Adjust to start of week (Sunday)
        let startDate = calendar.date(
            byAdding: .day,
            value: calendar.component(.weekday, from: startOfMonth) == 1 ? 0 : -(calendar.component(.weekday, from: startOfMonth) - 1),
            to: startOfMonth
        ) ?? startOfMonth
        
        // Calculate days needed for the end of the grid
        let daysAfterEndOfMonth = 7 - calendar.component(.weekday, from: endOfMonth)
        let endDate = calendar.date(byAdding: .day, value: daysAfterEndOfMonth == 7 ? 0 : daysAfterEndOfMonth, to: endOfMonth) ?? endOfMonth
        
        // Generate array of dates
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    private func getWorkoutsForDate(_ date: Date) -> [WorkoutPlan]? {
        let workoutsOnDate = workoutPlans.filter { plan in
            Calendar.current.isDate(plan.date, inSameDayAs: date)
        }
        return workoutsOnDate.isEmpty ? nil : workoutsOnDate
    }
    
    private func changeMonth(by amount: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: amount, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func colorForWorkout(_ workout: WorkoutPlan) -> Color {
        // Color based on muscle groups
        guard let muscles = workout.targetMuscles, let primaryMuscle = muscles.first else {
            return .blue
        }
        
        // Match colors to muscle groups
        switch primaryMuscle.name {
        case "Chest": return .red
        case "Back": return .green
        case "Shoulders": return .orange
        case "Arms": return .purple
        case "Legs": return .blue
        case "Core": return .yellow
        case "Full Body": return .pink
        default: return .gray
        }
    }
    
    private func planRow(for plan: WorkoutPlan) -> some View {
        NavigationLink(destination: WorkoutDetailView(plan: plan)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.name)
                        .font(.headline)
                    
                    if plan.isTemplate {
                        Label("Template", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .labelStyle(.iconOnly)
                    }
                }
                
                HStack {
                    Text(plan.formattedDate)
                    Spacer()
                    if plan.isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text(plan.muscleGroupNames)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let exercises = plan.exercises, !exercises.isEmpty {
                    Text("\(plan.completedExercises)/\(plan.exerciseCount) exercises completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contextMenu {
            Button {
                toggleTemplate(plan)
            } label: {
                Label(
                    plan.isTemplate ? "Remove from Templates" : "Save as Template",
                    systemImage: plan.isTemplate ? "doc.text.badge.minus" : "doc.text.badge.plus"
                )
            }
            
            Button(role: .destructive) {
                deletePlan(plan)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func toggleTemplate(_ plan: WorkoutPlan) {
        plan.isTemplate.toggle()
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func deletePlan(_ plan: WorkoutPlan) {
        modelContext.delete(plan)
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
}

struct PlansView_Previews: PreviewProvider {
    static var previews: some View {
        PlansView()
    }
}
