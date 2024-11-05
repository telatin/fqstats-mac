import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var isShowingFileImporter = false
    @State private var isDropTargeted = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Drag and Drop Area
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isDropTargeted ? .blue : .gray)
                    .frame(height: 200)
                    .animation(.default, value: isDropTargeted)
                
                VStack(spacing: 12) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 40))
                        .foregroundColor(isDropTargeted ? .blue : .gray)
                    
                    Text("Drop FASTQ/FASTA files here")
                        .font(.headline)
                    
                    Text("or")
                        .foregroundColor(.secondary)
                    
                    Button("Select File") {
                        isShowingFileImporter = true
                    }
                    .disabled(fileProcessor.isProcessing)
                }
            }
            .padding()
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers -> Bool in
                guard let provider = providers.first else { return false }
                
                let _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { urlData, _ in
                    DispatchQueue.main.async {
                        guard let urlData = urlData as? Data,
                              let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                            fileProcessor.error = "Could not access the dropped file"
                            return
                        }
                        
                        // Create a copy in the temporary directory
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempUrl = tempDir.appendingPathComponent(url.lastPathComponent)
                        
                        do {
                            if FileManager.default.fileExists(atPath: tempUrl.path) {
                                try FileManager.default.removeItem(at: tempUrl)
                            }
                            try FileManager.default.copyItem(at: url, to: tempUrl)
                            fileProcessor.processFile(url: tempUrl)
                        } catch {
                            fileProcessor.error = "Error copying file: \(error.localizedDescription)"
                        }
                    }
                }
                return true
            }
            
            if fileProcessor.isProcessing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.0)
                    Text("Processing...")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = fileProcessor.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            if fileProcessor.stats.totalSequences > 0 {
                StatsView(stats: fileProcessor.stats)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.data],
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sequence Statistics")
                .font(.headline)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                StatRow(label: "Total Sequences", value: "\(stats.totalSequences)")
                StatRow(label: "Total Bases", value: "\(stats.totalBases)")
                StatRow(label: "GC Content", value: String(format: "%.2f%%", stats.gcContent))
                StatRow(label: "Average Length", value: String(format: "%.2f", stats.averageLength))
                StatRow(label: "Longest Sequence", value: "\(stats.longestSequence)")
                StatRow(label: "Shortest Sequence", value: stats.shortestSequence == Int.max ? "N/A" : "\(stats.shortestSequence)")
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
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
