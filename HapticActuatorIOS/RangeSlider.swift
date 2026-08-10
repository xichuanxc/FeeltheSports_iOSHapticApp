import SwiftUI

struct RangeSlider: View {
    @Binding var lower: Double
    @Binding var upper: Double
    let range: ClosedRange<Double>
    let step: Double
    let minGap: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: xPos(upper, in: w) - xPos(lower, in: w), height: 4)
                    .offset(x: xPos(lower, in: w))

                thumb(xPos(lower, in: w))
                    .gesture(DragGesture().onChanged { v in
                        let snapped = snap(valueAt(v.location.x, in: w))
                        lower = max(range.lowerBound, min(upper - minGap, snapped))
                    })

                thumb(xPos(upper, in: w))
                    .gesture(DragGesture().onChanged { v in
                        let snapped = snap(valueAt(v.location.x, in: w))
                        upper = min(range.upperBound, max(lower + minGap, snapped))
                    })
            }
        }
        .frame(height: 22)
    }

    private func thumb(_ x: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .offset(x: x - 11)
    }

    private func xPos(_ value: Double, in width: CGFloat) -> CGFloat {
        let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(ratio) * width
    }

    private func valueAt(_ x: CGFloat, in width: CGFloat) -> Double {
        let ratio = Double(max(0, min(x, width))) / Double(width)
        return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
    }

    private func snap(_ value: Double) -> Double {
        let steps = round((value - range.lowerBound) / step)
        return max(range.lowerBound, min(range.upperBound, range.lowerBound + steps * step))
    }
}
