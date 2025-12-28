internal import SwiftUI

struct StatOverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let percentageChange: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                if let change = percentageChange {
                    Text("\(change, specifier: "%.0f")%")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(change >= 0 ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((change >= 0 ? Color.green : Color.red).opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
