import Foundation

// From Supabase → Project Settings → API. The publishable (anon) key is meant to ship in the app;
// row-level security protects the data. Never put the service_role / secret key here.
enum Config {
    static let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    static let supabaseKey = "YOUR-PUBLISHABLE-KEY"
}
