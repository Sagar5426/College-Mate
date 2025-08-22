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
    
    private var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let earliestDate = Calendar.current.date(byAdding: .year, value: -1, to: today) ?? today
        return earliestDate...today
    }
    
    var body: some View {
        VStack(spacing: 15) {
            DatePicker("Select Date", selection: $start, in: dateRange, displayedComponents: [.date])
                .datePickerStyle(.graphical)
            
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
        .background(.bar, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 30)
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
