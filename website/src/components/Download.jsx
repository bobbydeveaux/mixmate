export default function Download() {
  return (
    <section className="section">
      <div className="container">
        <div style={{
          background: 'linear-gradient(135deg, rgba(124,92,252,0.12) 0%, rgba(192,132,252,0.06) 100%)',
          border: '1px solid rgba(124,92,252,0.2)',
          borderRadius: 24, padding: 'clamp(48px, 6vw, 80px) clamp(24px, 6vw, 80px)',
          textAlign: 'center', position: 'relative', overflow: 'hidden',
        }}>
          {/* Subtle radial glow */}
          <div style={{
            position: 'absolute', top: -60, left: '50%', transform: 'translateX(-50%)',
            width: 400, height: 300, borderRadius: '50%',
            background: 'radial-gradient(ellipse, rgba(124,92,252,0.2) 0%, transparent 70%)',
            pointerEvents: 'none',
          }} />

          <div style={{ position: 'relative' }}>
            <div style={{
              width: 64, height: 64, borderRadius: 16,
              background: 'linear-gradient(135deg, var(--accent) 0%, #c084fc 100%)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 24px', boxShadow: '0 8px 32px rgba(124,92,252,0.4)',
            }}>
              <svg width="28" height="28" viewBox="0 0 22 22" fill="none">
                <path d="M3 11c0 0 1.8-5 4-5s3 10 5 10 3-10 5-10 2 5 2 5" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>

            <h2 style={{ fontSize: 'clamp(28px, 4vw, 44px)', fontWeight: 800, letterSpacing: '-0.03em', marginBottom: 16 }}>
              Ready to mix?
            </h2>

            <p style={{ fontSize: 17, color: 'var(--text-muted)', maxWidth: 440, margin: '0 auto 36px', lineHeight: 1.6 }}>
              Download MixMate for free. Build from source or grab the latest release.
            </p>

            <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap', marginBottom: 24 }}>
              <a href="https://github.com/bobbydeveaux/mixmate/releases/latest" target="_blank" rel="noopener">
                <button className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, padding: '13px 28px' }}>
                  <svg width="15" height="15" viewBox="0 0 814 1000" fill="currentColor">
                    <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 376.7 0 248.3 0 124.8 0 57.5 25.3 25.7 85.3 25.7c58 0 102.8 40.2 137.4 40.2 33 0 81.8-41.4 137.4-41.4 51.3 0 96.6 26 129.5 78.9zM531.3 55.2c14.4-16.9 27.9-40.8 27.9-64.7 0-3.2-.3-6.5-.6-9.7-26.4 1-57.5 17.5-76.2 38.5-14.4 15.5-28.6 39.5-28.6 63.7 0 3.5.6 6.8 1 9.7 1.9.3 4.2.3 6.5.3 23.7 0 51.3-15.3 69.9-37.8z"/>
                  </svg>
                  Download for macOS
                </button>
              </a>
              <a href="https://github.com/bobbydeveaux/mixmate" target="_blank" rel="noopener">
                <button className="btn-ghost" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, padding: '13px 24px' }}>
                  Build from source →
                </button>
              </a>
            </div>

            <p style={{ fontSize: 12, color: 'var(--text-dim)' }}>
              Requires macOS Sonoma 14.2 or later · MIT License · No telemetry
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
