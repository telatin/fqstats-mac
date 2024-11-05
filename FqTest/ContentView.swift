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
                        .fixedSize(horizontal: false, vertical: true)  // This makes it fit the content
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sequence Statistics")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                StatPair(
                    leftLabel: "Filename",
                    leftValue: stats.filename,
                    rightLabel: "Total Sequences",
                    rightValue: "\(stats.totalSequences)"
                )
                
                StatPair(
                    leftLabel: "Total Bases",
                    leftValue: formatNumber(stats.totalBases),
                    rightLabel: "N50",
                    rightValue: formatNumber(stats.n50)
                )
                
                StatPair(
                    leftLabel: "Average Length",
                    leftValue: formatNumber(Int(stats.averageLength)),
                    rightLabel: "Longest Sequence",
                    rightValue: formatNumber(stats.longestSequence)
                )
                
                StatPair(
                    leftLabel: "Shortest Sequence",
                    leftValue: stats.shortestSequence == Int.max ? "N/A" : formatNumber(stats.shortestSequence),
                    rightLabel: "",
                    rightValue: ""
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ?
                      Color(.windowBackgroundColor).opacity(0.3) :
                      Color(.windowBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}


struct StatPair: View {
    let leftLabel: String
    let leftValue: String
    let rightLabel: String
    let rightValue: String
    
    var body: some View {
        HStack(alignment: .top) {
            StatItem(label: leftLabel, value: leftValue)
            Spacer()
            if !rightLabel.isEmpty {
                StatItem(label: rightLabel, value: rightValue)
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .foregroundColor(.secondary)
                .font(.callout)
            HStack {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                if showCopied {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())  // Makes the entire area clickable
        .onTapGesture {
            copyToClipboard()
        }
        .help("Click to copy \(label): \(value)")  // Shows tooltip on hover
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        
        withAnimation {
            showCopied = true
        }
        
        // Hide the checkmark after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

#Preview {
    StatsView(stats: SequenceStats(
        filename: "sample.fastq.gz",
        totalSequences: 1234567,
        totalBases: 987654321,
        averageLength: 123.45,
        longestSequence: 54321,
        shortestSequence: 12,
        n50: 45678
    ))
    .padding()
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
