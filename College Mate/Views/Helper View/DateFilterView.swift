//
//  DateFilterView.swift
//  College Mate
//
//  Created by Sagar Jangra on 10/01/2025.
//


import SwiftUI

struct DateFilterView: View {
    @State var start: Date
    
    var onSubmit: (Date) -> ()
    var onClose: () -> ()
    var body: some View {
        VStack(spacing: 15) {
            DatePicker("Select Date", selection: $start, displayedComponents: [.date])
                .datePickerStyle(.graphical)
            
             HStack(spacing: 15) {
                Button("Cancel") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 5))
                .tint(.red)
                
                Button("Filter") {
                    onSubmit(start)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 5))
                .tint(appTint)
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
        // End date 7 days from now
        onSubmit: { start in
            print("Date range submitted: \(start) to ")
        },
        onClose: {
            print("Date filter view closed")
        }
    )
}


