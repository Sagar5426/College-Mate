//import SwiftUI
//import SwiftData
//
//struct AttendanceView: View {
//    @Query var subjects: [Subject]
//    
//    // The View creates and owns the ViewModel.
//    @StateObject private var viewModel = AttendanceViewModel()
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView(.vertical) {
//                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
//                    Section {
//                        // Subviews now get data and actions from the ViewModel.
//                        DatePickerHeader(viewModel: viewModel)
//                        HolidayButton(viewModel: viewModel)
//                        Divider().padding(.vertical)
//                        ClassesList(viewModel: viewModel)
//                    } header: {
//                        GeometryReader { proxy in
//                            HeaderView(size: proxy.size, title: "Attendance 🙋", isShowingProfileView: $viewModel.isShowingProfileView)
//                        }
//                        .frame(height: 50)
//                    }
//                }
//                .padding()
//            }
//            .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
//            .blur(radius: viewModel.isShowingDatePicker ? 8 : 0)
//            .disabled(viewModel.isShowingDatePicker)
//        }
//        .fullScreenCover(isPresented: $viewModel.isShowingProfileView) {
//            // Use the initializer that accepts the @Query result.
//            ProfileView(isShowingProfileView: $viewModel.isShowingProfileView, subjects: subjects)
//        }
//        .overlay {
//            if viewModel.isShowingDatePicker {
//                DateFilterView(
//                    start: viewModel.selectedDate,
//                    onSubmit: { start in
//                        viewModel.selectedDate = start
//                        viewModel.isShowingDatePicker = false
//                    },
//                    onClose: { viewModel.isShowingDatePicker = false }
//                )
//                .transition(.move(edge: .leading))
//            }
//        }
//        .animation(.snappy, value: viewModel.isShowingDatePicker)
//        .onAppear {
//            // When the view appears, give the subjects to the ViewModel.
//            viewModel.updateSubjects(subjects)
//        }
//        .onChange(of: subjects) {
//            // If subjects change (e.g., a new one is added), update the ViewModel.
//            viewModel.updateSubjects(subjects)
//        }
//    }
//}
//
//// MARK: - Subviews
//
//struct DatePickerHeader: View {
//    @ObservedObject var viewModel: AttendanceViewModel
//    
//    private var isNextDayDisabled: Bool {
//        Calendar.current.isDateInToday(viewModel.selectedDate)
//    }
//    
//    var body: some View {
//        HStack {
//            Button(action: viewModel.moveToPreviousDay) {
//                Image(systemName: "chevron.left").font(.title2).padding()
//            }
//            
//            Spacer()
//            
//            Text(viewModel.selectedDate, formatter: Self.dateFormatter)
//                .font(.headline)
//                .onTapGesture {
//                    withAnimation {
//                        viewModel.isShowingDatePicker.toggle()
//                    }
//                }
//            
//            Spacer()
//            
//            Button(action: viewModel.moveToNextDay) {
//                Image(systemName: "chevron.right")
//                    .font(.title2)
//                    .padding()
//                    .foregroundColor(isNextDayDisabled ? .gray : .accentColor)
//            }
//            .disabled(isNextDayDisabled)
//        }
//        .padding(.horizontal)
//    }
//    
//    static var dateFormatter: DateFormatter {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .full
//        return formatter
//    }
//}
//
//struct HolidayButton: View {
//    @ObservedObject var viewModel: AttendanceViewModel
//    
//    var body: some View {
//        Button(action: {
//            viewModel.isHoliday.toggle()
//        }) {
//            Text(viewModel.isHoliday ? "Marked as Holiday" : "Mark Today as Holiday")
//                .frame(maxWidth: .infinity)
//                .padding()
//                .foregroundColor(.white)
//                .background(viewModel.isHoliday ? Color.red : Color.blue)
//                .clipShape(RoundedRectangle(cornerRadius: 10))
//                .padding(.horizontal)
//        }
//    }
//}
//
//struct ClassesList: View {
//    @ObservedObject var viewModel: AttendanceViewModel
//    
//    var body: some View {
//        if viewModel.isHoliday {
//            Text("No classes today. Enjoy your holiday!")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .padding()
//        } else if viewModel.scheduledSubjects.isEmpty {
//            Text("No classes scheduled for this day.")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .padding()
//        } else {
//            VStack(alignment: .leading, spacing: 20) {
//                ForEach(viewModel.scheduledSubjects) { subject in
//                    ForEach(subject.schedules.filter { $0.day == viewModel.selectedDate.formatted(Date.FormatStyle().weekday(.wide)) }) { schedule in
//                        ForEach(schedule.classTimes) { classTime in
//                            ClassAttendanceRow(subject: subject, classTime: classTime, viewModel: viewModel)
//                        }
//                    }
//                }
//            }
//            .padding()
//        }
//    }
//}
//
//struct ClassAttendanceRow: View {
//    // This view now receives the specific models it needs to display.
//    let subject: Subject
//    let classTime: ClassTime
//    // It gets a reference to the ViewModel to call its functions.
//    @ObservedObject var viewModel: AttendanceViewModel
//    
//    var body: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 5) {
//                Text(subject.name)
//                    .font(.title2)
//                    .foregroundStyle(.primary)
//                
//                Text("Attendance: \(Int(subject.attendance.percentage))%")
//                    .font(.caption)
//                    .foregroundColor(subject.attendance.percentage >= 75 ? .green : .red)
//            }
//            
//            Spacer()
//            
//            Menu {
//                Button("Attended") {
//                    viewModel.updateAttendance(for: subject, classTime: classTime, to: "Attended")
//                }
//                Button("Not Attended") {
//                    viewModel.updateAttendance(for: subject, classTime: classTime, to: "Not Attended")
//                }
//                Button("Canceled") {
//                    viewModel.updateAttendance(for: subject, classTime: classTime, to: "Canceled")
//                }
//            } label: {
//                Text(classTime.label)
//                    .padding()
//                    .foregroundColor(.white)
//                    .background(labelColor)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//            }
//        }
//        .padding()
//        .background(Color.secondary.opacity(0.2))
//        .cornerRadius(10)
//    }
//    
//    private var labelColor: Color {
//        switch classTime.label {
//        case "Attended": return .green
//        case "Not Attended": return .blue
//        case "Canceled": return .red
//        default: return .gray
//        }
//    }
//}
//
//// MARK: - Preview
//#Preview {
//    AttendanceView()
//        .modelContainer(for: Subject.self, inMemory: true)
//}
