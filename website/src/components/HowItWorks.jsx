const STEPS = [
  {
    num: '01',
    title: 'Launch MixMate',
    desc: 'Run the app. A speaker icon appears in your menu bar. On first launch, macOS will ask for microphone access — required for the audio tap API.',
  },
  {
    num: '02',
    title: 'Play some audio',
    desc: 'Open Spotify, join a Zoom call, watch a video in Safari. MixMate automatically detects every app actively playing audio.',
  },
  {
    num: '03',
    title: 'Take control',
    desc: 'Click the menu bar icon. Drag any slider to set that app\'s volume independently. Mute or unmute with one click.',
  },
]

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="section" style={{ background: 'linear-gradient(180deg, transparent 0%, rgba(124,92,252,0.04) 50%, transparent 100%)' }}>
      <div className="container">
        <div style={{ textAlign: 'center', marginBottom: 64 }}>
          <p style={{ fontSize: 12, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--accent)', marginBottom: 12 }}>How it works</p>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>
            Up and running in seconds.
          </h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 24 }}>
          {STEPS.map((step, i) => (
            <div key={step.num} style={{ position: 'relative' }}>
              {/* Connector line */}
              {i < STEPS.length - 1 && (
                <div style={{
                  display: 'none',
                  position: 'absolute', top: 22, left: 'calc(50% + 28px)',
                  right: 'calc(-50% + 28px)', height: 1,
                  background: 'linear-gradient(90deg, var(--border-bright), transparent)',
                }} />
              )}
              <div style={{
                background: 'var(--bg-card)', border: '1px solid var(--border)',
                borderRadius: 16, padding: '28px 24px',
              }}>
                <div style={{
                  fontSize: 12, fontWeight: 700, letterSpacing: '0.05em',
                  color: 'var(--accent)', fontVariantNumeric: 'tabular-nums',
                  marginBottom: 16, opacity: 0.7,
                }}>
                  {step.num}
                </div>
                <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 10, letterSpacing: '-0.02em' }}>{step.title}</h3>
                <p style={{ fontSize: 14, color: 'var(--text-muted)', lineHeight: 1.65 }}>{step.desc}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Tech note */}
        <div style={{
          marginTop: 48, padding: '20px 24px',
          background: 'rgba(124,92,252,0.05)', border: '1px solid rgba(124,92,252,0.15)',
          borderRadius: 12, display: 'flex', gap: 14, alignItems: 'flex-start',
          maxWidth: 680, margin: '48px auto 0',
        }}>
          <span style={{ fontSize: 18, flexShrink: 0 }}>⚡</span>
          <div>
            <p style={{ fontSize: 13, fontWeight: 600, marginBottom: 4 }}>Under the hood</p>
            <p style={{ fontSize: 13, color: 'var(--text-muted)', lineHeight: 1.6 }}>
              MixMate uses <code style={{ background: 'rgba(124,92,252,0.12)', padding: '1px 6px', borderRadius: 4, fontSize: 12, color: 'var(--accent-bright)' }}>AudioHardwareCreateProcessTap</code> — a macOS 14.2 API that intercepts a specific app's audio stream. A CoreAudio aggregate device routes the audio through an IOProc that scales the samples before sending them to your speakers. No virtual drivers. No latency.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
