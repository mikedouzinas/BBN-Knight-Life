# LOCAL VERIFY ONLY (never commit): points the app at the Firebase emulators and signs in the seeded student.
import sys
root = sys.argv[1]
p = root + '/BBNDaily/AppDelegate.swift'
s = open(p).read()
needle = "        FirebaseApp.configure()\n"
patch = needle + '''        if ProcessInfo.processInfo.environment["KL_EMU"] == "1" {
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
            let settings = Firestore.firestore().settings
            settings.host = "127.0.0.1:8080"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            Firestore.firestore().settings = settings
            var done = false
            Auth.auth().signIn(withEmail: "test.student@bbns.org", password: "verify-only-123") { _, err in
                if let err = err { print("KL_EMU sign-in failed", err) }
                done = true
            }
            let until = Date().addingTimeInterval(15)
            while !done && Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        }
'''
assert needle in s
s = s.replace(needle, patch, 1)
if 'import FirebaseFirestore' not in s:
    s = s.replace('import Firebase\n', 'import Firebase\nimport FirebaseFirestore\nimport FirebaseAuth\n', 1)
open(p, 'w').write(s)
print('patched')
