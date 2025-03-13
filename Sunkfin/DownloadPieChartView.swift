//
//  DownloadPieChartView.swift
//  Sunkfin
//
//  Created by Jack Crane on 3/13/25.
//

import SwiftUI

struct DownloadPieChartView: View {
    var progress: Double

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.blue, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 12, height: 12)
            Text("Downloading")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    DownloadPieChartView(progress: 0.4)
}
