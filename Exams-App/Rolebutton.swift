import SwiftUI

struct RoleButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .imageScale(.medium)
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .font(.headline)
        .padding()
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
