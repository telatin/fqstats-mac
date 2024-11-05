import SwiftUI
import Gzip

struct SequenceStats {
    var totalSequences: Int = 0
    var totalBases: Int = 0
    var gcContent: Double = 0.0
    var averageLength: Double = 0.0
    var longestSequence: Int = 0
    var shortestSequence: Int = Int.max
}

class FileProcessor: ObservableObject {
    @Published var stats = SequenceStats()
    @Published var isProcessing = false
    @Published var error: String?
    
    func processFile(url: URL) {
        isProcessing = true
        error = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let fileData = try Data(contentsOf: url)
                let decompressedData: Data
                
                // Check if file is gzipped and decompress if needed
                if url.pathExtension.lowercased() == "gz" {
                    if fileData.isGzipped {
                        decompressedData = try fileData.gunzipped()
                    } else {
                        throw NSError(domain: "FileProcessing", code: 2,
                                    userInfo: [NSLocalizedDescriptionKey: "File has .gz extension but is not gzipped"])
                    }
                } else {
                    decompressedData = fileData
                }
                
                // Convert to string and process
                if let content = String(data: decompressedData, encoding: .ascii) {
                    self?.processContent(content)
                } else {
                    throw NSError(domain: "FileProcessing", code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to decode file content"])
                }
                
            } catch {
                DispatchQueue.main.async {
                    self?.error = error.localizedDescription
                    self?.isProcessing = false
                }
            }
        }
    }
    
    private func processContent(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.error = "File is empty"
                self?.isProcessing = false
            }
            return
        }
        
        var stats = SequenceStats()
        var sequences: [String] = []
        var currentSequence = ""
        let isFastq = lines[0].hasPrefix("@")
        
        if isFastq {
            // Process FASTQ
            var lineCount = 0
            for line in lines {
                if line.isEmpty { continue }
                
                lineCount += 1
                if lineCount % 4 == 2 { // Sequence line
                    sequences.append(line)
                }
            }
        } else {
            // Process FASTA
            for line in lines {
                if line.isEmpty { continue }
                
                if line.hasPrefix(">") {
                    if !currentSequence.isEmpty {
                        sequences.append(currentSequence)
                        currentSequence = ""
                    }
                } else {
                    currentSequence += line
                }
            }
            if !currentSequence.isEmpty {
                sequences.append(currentSequence)
            }
        }
        
        // Calculate stats
        stats.totalSequences = sequences.count
        
        for sequence in sequences {
            let length = sequence.count
            stats.totalBases += length
            stats.longestSequence = max(stats.longestSequence, length)
            stats.shortestSequence = min(stats.shortestSequence, length)
            
            let gcCount = sequence.filter { "GCgc".contains($0) }.count
            stats.gcContent = (Double(gcCount) / Double(stats.totalBases)) * 100
        }
        
        if stats.totalSequences > 0 {
            stats.averageLength = Double(stats.totalBases) / Double(stats.totalSequences)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.stats = stats
            self?.isProcessing = false
        }
    }
}
