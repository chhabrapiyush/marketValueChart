import SwiftUI
import Combine

// MARK: - Models

/// Data point model for market value chart
struct MarketValuePoint: Identifiable, Equatable {
    var id = UUID()
    let date: Date
    let investedValue: Double
    let totalValue: Double
    
    var returns: Double {
        totalValue - investedValue
    }
}

/// Time period options for the chart
enum ChartTimePeriod: String, CaseIterable, Identifiable {
    case last5Days = "5D"
    case lastMonth = "1M"
    case ytd = "YTD"
    case oneYear = "1Y"
    case threeYears = "3Y"
    case fiveYears = "5Y"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .last5Days: return "5 Days"
        case .lastMonth: return "1 Month"
        case .ytd: return "Year to Date"
        case .oneYear: return "1 Year"
        case .threeYears: return "3 Years"
        case .fiveYears: return "5 Years"
        }
    }
}

// MARK: - Theme Configuration

/// Theme configuration for chart appearance
struct ChartTheme {
    let investedValueColor: Color
    let returnsColor: Color
    let lineColor: Color
    let gridColor: Color
    let labelColor: Color
    let selectedPeriodColor: Color
    let unselectedPeriodColor: Color
    let backgroundColor: Color
    
    static let `default` = ChartTheme(
        investedValueColor: Color.blue.opacity(0.3),
        returnsColor: Color.green.opacity(0.3),
        lineColor: Color.blue,
        gridColor: Color.gray.opacity(0.2),
        labelColor: Color.secondary,
        selectedPeriodColor: Color.blue,
        unselectedPeriodColor: Color.gray,
        backgroundColor: Color.white
    )
}

// MARK: - View Models

/// View model for the market value chart
class MarketValueChartViewModel: ObservableObject {
    @Published var dataPoints: [MarketValuePoint] = []
    @Published var selectedPeriod: ChartTimePeriod = .oneYear
    @Published var isLoading: Bool = false
    @Published var selectedDataPoint: MarketValuePoint?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSampleData()
        
        // Automatically update data when period changes
        $selectedPeriod
            .dropFirst()
            .sink { [weak self] period in
                self?.loadDataForPeriod(period)
            }
            .store(in: &cancellables)
    }
    
    func loadDataForPeriod(_ period: ChartTimePeriod) {
        isLoading = true
        
        // Reset selected data point when changing periods
        selectedDataPoint = nil
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.loadSampleData(for: period)
            self?.isLoading = false
            
            // Animate selection of the last data point
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    self?.selectedDataPoint = self?.dataPoints.last
//                }
//            }
        }
    }
    
    func loadSampleData(for period: ChartTimePeriod = .oneYear) {
        // Generate sample data based on selected time period
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        let pointCount: Int
        
        switch period {
        case .last5Days:
            startDate = calendar.date(byAdding: .day, value: -5, to: now)!
            pointCount = 6
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
            pointCount = 31
        case .ytd:
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: DateComponents(year: components.year, month: 1, day: 1))!
            pointCount = calendar.dateComponents([.day], from: startDate, to: now).day! + 1
        case .oneYear:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
            pointCount = 13
        case .threeYears:
            startDate = calendar.date(byAdding: .year, value: -3, to: now)!
            pointCount = 37
        case .fiveYears:
            startDate = calendar.date(byAdding: .year, value: -5, to: now)!
            pointCount = 61
        }
        
        // Generate data points with much more visible differences between invested and total value
        var newDataPoints: [MarketValuePoint] = []
        
        let timeInterval = Double(calendar.dateComponents([.second], from: startDate, to: now).second ?? 0) / Double(pointCount - 1)
        var investedBase: Double = 10000
        var totalBase: Double = 12500  // Start with a 25% return already
        
        // Define growth rates that will make difference more visible
        let investmentGrowthRate = 0.5  // Regular contributions
        let marketGrowthRate = 3.0      // Much higher market returns
        
        for i in 0..<pointCount {
            let pointDate = startDate.addingTimeInterval(timeInterval * Double(i))
            
            // Add regular investment for invested value
            if i > 0 {
                // Smaller regular investments
                investedBase += 300 + Double.random(in: -5...5)
            }
            
            // Add market fluctuation for total value - make returns much more significant
            let marketReturn = (totalBase - investedBase) * (1 + Double.random(in: -0.01...0.04))
            
            // Calculate new total with more dramatic growth
            if pointCount > 10 && i > pointCount / 3 {
                // Accelerate growth for longer time periods to make difference more visible
                totalBase = investedBase + marketReturn + Double(i) * marketGrowthRate * 100
            } else {
                totalBase = investedBase + marketReturn
            }
            
            // Add some volatility for realism
            let volatility = totalBase * Double.random(in: -0.02...0.03)
            totalBase += volatility
            
            // Ensure total value is at least invested value
            totalBase = max(totalBase, investedBase * 1.05)  // Always at least 5% above invested
            
            let point = MarketValuePoint(
                date: pointDate,
                investedValue: investedBase,
                totalValue: totalBase
            )
            newDataPoints.append(point)
        }
        
        dataPoints = newDataPoints
        selectedDataPoint = newDataPoints.last
    }
    
    func selectNearestPoint(at xPosition: CGFloat, in width: CGFloat) {
        guard !dataPoints.isEmpty else { return }
        
        let stepWidth = width / CGFloat(dataPoints.count - 1)
        let index = min(Int(xPosition / stepWidth), dataPoints.count - 1)
        selectedDataPoint = dataPoints[index]
    }
}

// MARK: - Chart Components

/// Area chart view component
struct AreaChartView: View {
    let dataPoints: [MarketValuePoint]
    let theme: ChartTheme
    let showInvestedValue: Bool
    let showReturns: Bool
    let maxY: Double
    @Binding var selectedPoint: MarketValuePoint?
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                GridLinesView(maxY: maxY, geometry: geometry, theme: theme)
                
                // Invested value area
                if showInvestedValue {
                    AreaPath(
                        dataPoints: dataPoints,
                        geometry: geometry,
                        maxY: maxY,
                        valueSelector: { $0.investedValue },
                        animationProgress: animationProgress
                    )
                    .fill(theme.investedValueColor)
                }
                
                // Total value (including returns) area
                if showReturns {
                    AreaPath(
                        dataPoints: dataPoints,
                        geometry: geometry,
                        maxY: maxY,
                        valueSelector: { $0.totalValue },
                        animationProgress: animationProgress
                    )
                    .fill(theme.returnsColor)
                }
                
                // Line graph for total value
                LinePath(
                    dataPoints: dataPoints,
                    geometry: geometry,
                    maxY: maxY,
                    valueSelector: { $0.totalValue },
                    animationProgress: animationProgress
                )
                .stroke(theme.lineColor, lineWidth: 2)
                
                // Value tracker line
                if let selectedPoint = selectedPoint,
                   let index = dataPoints.firstIndex(where: { $0.id == selectedPoint.id }) {
                    let x = geometry.size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                    
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    .stroke(theme.lineColor.opacity(0.5), lineWidth: 1)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: selectedPoint.id)
                }
                
                // Interactive overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                selectNearestPoint(at: x, in: geometry.size.width)
                            }
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) {
                    animationProgress = 1.0
                }
            }
            .onChange(of: dataPoints) { _ in
                // Reset and replay animation when data changes
                animationProgress = 0
                withAnimation(.easeInOut(duration: 1.2)) {
                    animationProgress = 1.0
                }
            }
        }
    }
    
    private func selectNearestPoint(at xPosition: CGFloat, in width: CGFloat) {
        guard !dataPoints.isEmpty else { return }
        
        let stepWidth = width / CGFloat(dataPoints.count - 1)
        let index = min(Int(xPosition / stepWidth), dataPoints.count - 1)
        selectedPoint = dataPoints[index]
    }
}

/// Grid lines for the chart
struct GridLinesView: View {
    let maxY: Double
    let geometry: GeometryProxy
    let theme: ChartTheme
    let gridLineCount = 5
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<gridLineCount, id: \.self) { index in
                Spacer()
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                }
                .stroke(theme.gridColor, lineWidth: 1)
            }
        }
    }
}

/// Area path generator
struct AreaPath: Shape {
    let dataPoints: [MarketValuePoint]
    let geometry: GeometryProxy
    let maxY: Double
    let valueSelector: (MarketValuePoint) -> Double
    var animationProgress: CGFloat
    
    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            guard !dataPoints.isEmpty else { return }
            
            let width = rect.width
            let height = rect.height
            
            // Start at bottom-left
            path.move(to: CGPoint(x: 0, y: height))
            
            // Calculate the number of points to draw based on animation progress
            let pointsToDraw = Int(CGFloat(dataPoints.count) * animationProgress)
            guard pointsToDraw > 0 else { return }
            
            // Draw line to first data point
            let firstPointValue = valueSelector(dataPoints[0])
            let firstPointY = height * (1 - CGFloat(firstPointValue / maxY))
            path.addLine(to: CGPoint(x: 0, y: firstPointY))
            
            // Draw the area up to animation progress
            for index in 0..<min(pointsToDraw, dataPoints.count) {
                let point = dataPoints[index]
                let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let y = height * (1 - CGFloat(valueSelector(point) / maxY))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // If we're still animating and have at least one point drawn
            if animationProgress < 1.0 && pointsToDraw < dataPoints.count && pointsToDraw > 0 {
                // Add a line to where the next point would start to appear
                let partialIndex = CGFloat(dataPoints.count) * animationProgress
                let fullIndex = floor(partialIndex)
                let fraction = partialIndex - fullIndex
                
                if fullIndex < CGFloat(dataPoints.count - 1) && fraction > 0 {
                    let currentPoint = dataPoints[Int(fullIndex)]
                    let nextPoint = dataPoints[Int(fullIndex) + 1]
                    
                    let currentX = width * fullIndex / CGFloat(dataPoints.count - 1)
                    let nextX = width * CGFloat(Int(fullIndex) + 1) / CGFloat(dataPoints.count - 1)
                    let interpolatedX = currentX + (nextX - currentX) * fraction
                    
                    let currentY = height * (1 - CGFloat(valueSelector(currentPoint) / maxY))
                    let nextY = height * (1 - CGFloat(valueSelector(nextPoint) / maxY))
                    let interpolatedY = currentY + (nextY - currentY) * fraction
                    
                    path.addLine(to: CGPoint(x: interpolatedX, y: interpolatedY))
                }
            }
            
            // If we've drawn all points, complete the path to bottom-right
            if pointsToDraw >= dataPoints.count {
                path.addLine(to: CGPoint(x: width, y: height))
            } else {
                // Otherwise, drop down to the bottom from the last drawn point
                let lastX = width * CGFloat(pointsToDraw - 1) / CGFloat(dataPoints.count - 1)
                path.addLine(to: CGPoint(x: lastX, y: height))
            }
            
            path.closeSubpath()
        }
    }
}

/// Line path generator
struct LinePath: Shape {
    let dataPoints: [MarketValuePoint]
    let geometry: GeometryProxy
    let maxY: Double
    let valueSelector: (MarketValuePoint) -> Double
    var animationProgress: CGFloat
    
    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            guard !dataPoints.isEmpty else { return }
            
            let width = rect.width
            let height = rect.height
            
            // Calculate the number of points to draw based on animation progress
            let pointsToDraw = Int(CGFloat(dataPoints.count) * animationProgress)
            guard pointsToDraw > 0 else { return }
            
            // Start at first data point
            let firstPointValue = valueSelector(dataPoints[0])
            let firstPointY = height * (1 - CGFloat(firstPointValue / maxY))
            path.move(to: CGPoint(x: 0, y: firstPointY))
            
            // Draw the line through points up to animation progress
            for index in 0..<min(pointsToDraw, dataPoints.count) {
                let point = dataPoints[index]
                let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let y = height * (1 - CGFloat(valueSelector(point) / maxY))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // If we're still animating and have at least one point drawn
            if animationProgress < 1.0 && pointsToDraw < dataPoints.count && pointsToDraw > 0 {
                // Add a line to where the next point would start to appear
                let partialIndex = CGFloat(dataPoints.count) * animationProgress
                let fullIndex = floor(partialIndex)
                let fraction = partialIndex - fullIndex
                
                if fullIndex < CGFloat(dataPoints.count - 1) && fraction > 0 {
                    let currentPoint = dataPoints[Int(fullIndex)]
                    let nextPoint = dataPoints[Int(fullIndex) + 1]
                    
                    let currentX = width * fullIndex / CGFloat(dataPoints.count - 1)
                    let nextX = width * CGFloat(Int(fullIndex) + 1) / CGFloat(dataPoints.count - 1)
                    let interpolatedX = currentX + (nextX - currentX) * fraction
                    
                    let currentY = height * (1 - CGFloat(valueSelector(currentPoint) / maxY))
                    let nextY = height * (1 - CGFloat(valueSelector(nextPoint) / maxY))
                    let interpolatedY = currentY + (nextY - currentY) * fraction
                    
                    path.addLine(to: CGPoint(x: interpolatedX, y: interpolatedY))
                }
            }
        }
    }
}

// MARK: - Main Chart View

struct MarketValueChartView: View {
    @StateObject private var viewModel = MarketValueChartViewModel()
    var theme: ChartTheme = .default
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with current values
            if let selectedPoint = viewModel.selectedDataPoint {
                ChartHeaderView(dataPoint: selectedPoint, theme: theme)
            }
            
            // Main chart
            chartView
                .frame(height: 250)
                .padding(.horizontal)
            
            // Time period selector
            timePeriodSelector
                .padding(.horizontal)
        }
        .padding()
        .background(theme.backgroundColor)
    }
    
    private var chartView: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                AreaChartView(
                    dataPoints: viewModel.dataPoints,
                    theme: theme,
                    showInvestedValue: true,
                    showReturns: true,
                    maxY: viewModel.dataPoints.map { $0.totalValue }.max() ?? 1000,
                    selectedPoint: $viewModel.selectedDataPoint
                )
                .id(viewModel.selectedPeriod) // Force view recreation when period changes for animations
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedPeriod)
            }
        }
    }
    
    private var timePeriodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(ChartTimePeriod.allCases) { period in
                    Button(action: {
                        viewModel.selectedPeriod = period
                    }) {
                        Text(period.rawValue)
                            .fontWeight(viewModel.selectedPeriod == period ? .bold : .regular)
                            .foregroundColor(viewModel.selectedPeriod == period ? theme.selectedPeriodColor : theme.unselectedPeriodColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                viewModel.selectedPeriod == period ?
                                    theme.selectedPeriodColor.opacity(0.1) :
                                    Color.clear
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct ChartHeaderView: View {
    let dataPoint: MarketValuePoint
    let theme: ChartTheme
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formattedDate(dataPoint.date))
                .font(.subheadline)
                .foregroundColor(theme.labelColor)
            
            Text("$\(Int(dataPoint.totalValue))")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 24) {
                ValueInfoView(
                    title: "Invested",
                    value: dataPoint.investedValue,
                    color: theme.investedValueColor
                )
                
                ValueInfoView(
                    title: "Returns",
                    value: dataPoint.returns,
                    color: theme.returnsColor,
                    showPlusSign: true
                )
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ValueInfoView: View {
    let title: String
    let value: Double
    let color: Color
    var showPlusSign: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text("\(showPlusSign && value > 0 ? "+" : "")\(currencyFormatter.string(from: NSNumber(value: value)) ?? "$0")")
                    .font(.headline)
            }
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter
    }
}

// MARK: - Preview

struct MarketValueChartView_Previews: PreviewProvider {
    static var previews: some View {
        MarketValueChartView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

