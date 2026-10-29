import Foundation

// Same project as the desktop (app/data/sync.py). From Supabase → Project Settings → API. The publishable (anon) key is meant to ship in the app;
// row-level security protects the data. Never put the service_role / secret key here.
enum Config {
    static let supabaseURL = URL(string: "https://xgyzufobwmmlansdbvmm.supabase.co")!
    static let supabaseKey = "sb_publishable_EXwjXnAGh1s1_IsDWdZuHA_vbNMXPbo"
}
