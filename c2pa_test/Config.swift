import SimpleC2PA
import Foundation

class Config: ObservableObject {
    static let shared = Config()
    
    @Published var rootCertificate: Certificate?
    @Published var contentCertificate: Certificate?
    
    func _init() {
        do {
            var rootCert = try createRootCertificate(organization: nil, validityDays: nil)
            
            self.rootCertificate = rootCert
            
            self.contentCertificate = try createContentCredentialsCertificate(rootCertificate: rootCert, organization: nil, validityDays: nil)
        } catch {
            print("Error: \(error)")
        }
    }
}
