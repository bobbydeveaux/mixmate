import { useState, useEffect } from 'react'

export default function Nav() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <nav style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
      transition: 'background 0.2s, border-color 0.2s',
      background: scrolled ? 'rgba(8,8,16,0.85)' : 'transparent',
      backdropFilter: scrolled ? 'blur(16px)' : 'none',
      borderBottom: scrolled ? '1px solid var(--border)' : '1px solid transparent',
    }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', height: 60, gap: 32 }}>
        <a href="#" style={{ display: 'flex', alignItems: 'center', gap: 9, fontWeight: 700, fontSize: 16, letterSpacing: '-0.02em' }}>
          <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
            <rect width="22" height="22" rx="6" fill="var(--accent)" fillOpacity="0.15"/>
            <path d="M4 11c0 0 1.5-4 3.5-4s2.5 8 4.5 8 2.5-8 4.5-8 2 4 2 4" stroke="var(--accent-bright)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          MixMate
        </a>

        <div style={{ display: 'flex', alignItems: 'center', gap: 28, marginLeft: 'auto' }}>
          <a href="#features" style={{ fontSize: 14, color: 'var(--text-muted)', fontWeight: 500, transition: 'color 0.15s' }}
            onMouseEnter={e => e.target.style.color = 'var(--text)'}
            onMouseLeave={e => e.target.style.color = 'var(--text-muted)'}>
            Features
          </a>
          <a href="#how-it-works" style={{ fontSize: 14, color: 'var(--text-muted)', fontWeight: 500, transition: 'color 0.15s' }}
            onMouseEnter={e => e.target.style.color = 'var(--text)'}
            onMouseLeave={e => e.target.style.color = 'var(--text-muted)'}>
            How it works
          </a>
          <a href="https://github.com/bobbydeveaux/mixmate" target="_blank" rel="noopener" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 14, color: 'var(--text-muted)', fontWeight: 500, transition: 'color 0.15s' }}
            onMouseEnter={e => e.currentTarget.style.color = 'var(--text)'}
            onMouseLeave={e => e.currentTarget.style.color = 'var(--text-muted)'}>
            <GitHubIcon />
            GitHub
          </a>
          <a href="https://github.com/bobbydeveaux/mixmate/releases/latest" target="_blank" rel="noopener">
            <button className="btn-primary" style={{ padding: '8px 18px', fontSize: 13 }}>
              Download
            </button>
          </a>
        </div>
      </div>
    </nav>
  )
}

function GitHubIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.604-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z"/>
    </svg>
  )
}
