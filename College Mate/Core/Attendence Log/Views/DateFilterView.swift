//
//  DateFilterView.swift
//  College Mate
//
//  Created by Sagar Jangra on 22/08/2025.
//


import SwiftUI

struct DateFilterView: View {
    @State var start: Date
    
    var onSubmit: (Date) -> ()
    var onClose: () -> ()
    
    // 1. Add a state variable to track if the view has "settled"
    @State private var hasAppeared = false
    
    private var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let earliestDate = Calendar.current.date(byAdding: .year, value: -1, to: today) ?? today
        return earliestDate...today
    }
    
    var body: some View {
        VStack(spacing: 15) {
            DatePicker("Select Date", selection: $start, in: dateRange, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                // 2. Use opacity to hide the picker until it has settled
                .opacity(hasAppeared ? 1 : 0)
                .onAppear {
                    // 3. Give the DatePicker a tiny delay (50ms) to layout, then fade it in.
                    // This is a common workaround for the graphical picker "jump" bug.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            hasAppeared = true
                        }
                    }
                }
            
            HStack(spacing: 15) {
                Button("Cancel") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 5))
                .tint(.red)
                
                Button("Done") {
                    onSubmit(start)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 5))
            }
            .padding(.top, 10)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(.bar, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 30)
        // MODIFICATION: Constrain the max width for larger screens like iPad
        .frame(maxWidth: 540)
        // 4. Removed the non-working .animation(nil, value: 0)
    }
}

#Preview {
    DateFilterView(
        start: Date(), // Start with the current date
        onSubmit: { start in
            print("Date submitted: \(start)")
        },
        onClose: {
            print("Date filter view closed")
        }
    )
}

