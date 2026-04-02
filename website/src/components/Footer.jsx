export default function Footer() {
  return (
    <footer style={{ borderTop: '1px solid var(--border)', padding: '32px 0' }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="18" height="18" viewBox="0 0 22 22" fill="none">
            <rect width="22" height="22" rx="6" fill="var(--accent)" fillOpacity="0.15"/>
            <path d="M4 11c0 0 1.5-4 3.5-4s2.5 8 4.5 8 2.5-8 4.5-8 2 4 2 4" stroke="var(--accent-bright)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          <span style={{ fontSize: 13, fontWeight: 600 }}>MixMate</span>
          <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>· MIT License</span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
          <a href="https://github.com/bobbydeveaux/mixmate" target="_blank" rel="noopener"
            style={{ fontSize: 13, color: 'var(--text-muted)', transition: 'color 0.15s' }}
            onMouseEnter={e => e.target.style.color = 'var(--text)'}
            onMouseLeave={e => e.target.style.color = 'var(--text-muted)'}>
            GitHub
          </a>
          <a href="https://github.com/bobbydeveaux/mixmate/releases" target="_blank" rel="noopener"
            style={{ fontSize: 13, color: 'var(--text-muted)', transition: 'color 0.15s' }}
            onMouseEnter={e => e.target.style.color = 'var(--text)'}
            onMouseLeave={e => e.target.style.color = 'var(--text-muted)'}>
            Releases
          </a>
          <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>
            Deployed with{' '}
            <a href="https://github.com/bobbydeveaux/stackramp" target="_blank" rel="noopener"
              style={{ color: 'var(--accent)', transition: 'opacity 0.15s' }}
              onMouseEnter={e => e.target.style.opacity = '0.7'}
              onMouseLeave={e => e.target.style.opacity = '1'}>
              StackRamp
            </a>
          </span>
        </div>
      </div>
    </footer>
  )
}
