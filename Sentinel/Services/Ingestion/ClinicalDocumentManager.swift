import Foundation
import os.log

actor ClinicalDocumentManager {
    static let shared = ClinicalDocumentManager()
    private let logger = Logger.ai
    private let targetFilename = "synthetic_discharge_summary.json"
    
    func scanForDocuments() async -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = documentsURL.appendingPathComponent(targetFilename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        logger.warning("📄 MedGemma Document Ingestion: Found \(self.targetFilename)")
        logger.warning("🔄 Parsing clinical FHIR document into context window...")
        
        do {
            let data = try Data(contentsOf: fileURL)
            // Use Codable for robust parsing of the synthetic FHIR structure
            struct FHIRText: Decodable { let div: String }
            struct FHIRDocument: Decodable { let text: FHIRText }
            
            let document = try JSONDecoder().decode(FHIRDocument.self, from: data)
            
            try archiveFile(at: fileURL)
            return cleanHTML(document.text.div)
        } catch {
            logger.error("Failed to ingest document: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func archiveFile(at url: URL) throws {
        let fileManager = FileManager.default
        let processedDir = url.deletingLastPathComponent().appendingPathComponent("Processed_Clinical_Docs")
        
        if !fileManager.fileExists(atPath: processedDir.path) {
            try fileManager.createDirectory(at: processedDir, withIntermediateDirectories: true)
        }
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let destination = processedDir.appendingPathComponent("archived_\(timestamp).json")
        try fileManager.moveItem(at: url, to: destination)
    }
    
    private func cleanHTML(_ html: String) -> String {
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}
