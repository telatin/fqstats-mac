import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var isShowingFileImporter = false
    @State private var isDropTargeted = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: geometry.size.height * 0.03) {
                // Drag and Drop Area
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .foregroundColor(isDropTargeted ? .blue : .gray)
                        .frame(height: geometry.size.height * 0.25)
                        .animation(.default, value: isDropTargeted)
                    
                    VStack(spacing: geometry.size.height * 0.02) {
                        Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .font(.system(size: min(geometry.size.width * 0.08, 60)))
                            .foregroundColor(isDropTargeted ? .blue : .gray)
                        
                        Text("Drop FASTQ/FASTA files here")
                            .font(.system(size: min(geometry.size.width * 0.03, 24)))
                            .fontWeight(.medium)
                        
                        /*
                         Text("or")
                            .foregroundColor(.secondary)
                            .font(.system(size: min(geometry.size.width * 0.02, 18)))
                        
                        
                         Button("Select File") {
                            isShowingFileImporter = true
                        }
                        */
                        .disabled(fileProcessor.isProcessing)
                        .font(.system(size: min(geometry.size.width * 0.02, 18)))
                    }
                }
                .padding(geometry.size.width * 0.03)
                .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers -> Bool in
                                    guard let provider = providers.first else { return false }
                                    
                                    provider.loadObject(ofClass: URL.self) { reading, error in
                                        DispatchQueue.main.async {
                                            if let url = reading as? URL {
                                                fileProcessor.processFile(url: url)
                                            } else {
                                                fileProcessor.error = "Could not access the dropped file"
                                            }
                                        }
                                    }
                                    return true
                                }
                
                // Processing indicator
                if fileProcessor.isProcessing {
                    VStack(spacing: geometry.size.height * 0.02) {
                        ProgressView()
                            .scaleEffect(min(geometry.size.width * 0.002, 1.5))
                        Text("Processing \(fileProcessor.stats.filename)...")
                            .font(.system(size: min(geometry.size.width * 0.02, 18)))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error display
                if let error = fileProcessor.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(size: min(geometry.size.width * 0.02, 18)))
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // Stats display
                if fileProcessor.stats.totalSequences > 0 {
                    StatsView(stats: fileProcessor.stats)
                        .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [
                .plainText,
                UTType(filenameExtension: "fastq")!,
                UTType(filenameExtension: "fq")!,
                UTType(filenameExtension: "fasta")!,
                UTType(filenameExtension: "fa")!,
                UTType(filenameExtension: "gz")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    fileProcessor.processFile(url: url)
                }
            case .failure(let error):
                fileProcessor.error = error.localizedDescription
            }
        }
    }
}
// MARK: - Stats View
struct StatsView: View {
    let stats: SequenceStats
    @Environment(\.colorScheme) var colorScheme // For better color adaptation
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: geometry.size.height * 0.03) {
                    // Header
                    Text("Sequence Statistics")
                        .font(.system(size: min(geometry.size.width * 0.05, 40)))
                        .fontWeight(.bold)
                        .padding(.bottom, geometry.size.height * 0.02)
                    
                    // Stats Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: geometry.size.width * 0.3)),
                            GridItem(.flexible(minimum: geometry.size.width * 0.3))
                        ],
                        alignment: .leading,
                        spacing: geometry.size.height * 0.03
                    ) {
                        ResponsiveStatRow(
                            label: "Filename",
                            value: stats.filename,
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "Total Sequences",
                            value: "\(stats.totalSequences)",
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "Total Bases",
                            value: formatNumber(stats.totalBases),
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "N50",
                            value: formatNumber(stats.n50),
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "Average Length",
                            value: formatNumber(Int(stats.averageLength)),
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "Longest Sequence",
                            value: formatNumber(stats.longestSequence),
                            geometry: geometry
                        )
                        ResponsiveStatRow(
                            label: "Shortest Sequence",
                            value: stats.shortestSequence == Int.max ? "N/A" : formatNumber(stats.shortestSequence),
                            geometry: geometry
                        )
                    }
                }
                .padding(geometry.size.width * 0.03)
                .frame(minHeight: geometry.size.height)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? Color(.windowBackgroundColor).opacity(0.3) : Color(.windowBackgroundColor).opacity(0.5))
                        .shadow(radius: 5)
                )
                .padding(geometry.size.width * 0.02)
            }
        }
    }
    
    // Helper function to format large numbers with commas
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// Responsive stat row component
struct ResponsiveStatRow: View {
    let label: String
    let value: String
    let geometry: GeometryProxy
    
    private var fontSize: CGFloat {
        min(geometry.size.width * 0.025, 24) // Cap the maximum font size
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: geometry.size.height * 0.01) {
            Text(label)
                .font(.system(size: fontSize))
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            Text(value)
                .font(.system(size: fontSize))
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(geometry.size.width * 0.015)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor).opacity(0.3))
        )
    }
}

// Preview provider for testing
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleStats = SequenceStats(
            filename: "sample.fastq.gz",
            totalSequences: 1234567,
            totalBases: 987654321,
            averageLength: 123.45,
            longestSequence: 54321,
            shortestSequence: 12,
            n50: 45678
        )
        
        StatsView(stats: sampleStats)
            .frame(width: 800, height: 600)
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
// MARK: - Stat Row View
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 150, alignment: .leading)
                .foregroundColor(.secondary)
            Text(value)
                .frame(width: 100, alignment: .trailing)
                .bold()
        }
    }
}
