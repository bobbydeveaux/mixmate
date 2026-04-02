import { useEffect, useRef } from 'react'

const TRACKS = [
  { name: 'Spotify',       color: '#1db954', volume: 0.35 },
  { name: 'Zoom',          color: '#2d8cff', volume: 0.80 },
  { name: 'Safari',        color: '#7c5cfc', volume: 1.00 },
  { name: 'Slack',         color: '#e01e5a', volume: 0.55 },
]

export default function Hero() {
  const canvasRef = useRef(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    let raf
    let t = 0

    const resize = () => {
      canvas.width = canvas.offsetWidth * window.devicePixelRatio
      canvas.height = canvas.offsetHeight * window.devicePixelRatio
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio)
    }
    resize()
    window.addEventListener('resize', resize)

    const draw = () => {
      const w = canvas.offsetWidth
      const h = canvas.offsetHeight
      ctx.clearRect(0, 0, w, h)

      const trackH = h / TRACKS.length
      TRACKS.forEach((track, i) => {
        const cy = trackH * i + trackH / 2
        const amp = trackH * 0.28 * track.volume
        const freq = 0.018 + i * 0.004
        const speed = 0.8 + i * 0.15

        ctx.beginPath()
        for (let x = 0; x <= w; x += 2) {
          const y = cy + Math.sin(x * freq + t * speed + i * 1.2) * amp
                       + Math.sin(x * freq * 1.7 + t * speed * 0.6) * amp * 0.35
          x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        }
        ctx.strokeStyle = track.color
        ctx.globalAlpha = 0.55
        ctx.lineWidth = 1.5
        ctx.stroke()

        // glow pass
        ctx.beginPath()
        for (let x = 0; x <= w; x += 2) {
          const y = cy + Math.sin(x * freq + t * speed + i * 1.2) * amp
                       + Math.sin(x * freq * 1.7 + t * speed * 0.6) * amp * 0.35
          x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        }
        ctx.strokeStyle = track.color
        ctx.globalAlpha = 0.12
        ctx.lineWidth = 6
        ctx.stroke()
        ctx.globalAlpha = 1
      })

      t += 0.025
      raf = requestAnimationFrame(draw)
    }
    draw()

    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', resize)
    }
  }, [])

  return (
    <section style={{ position: 'relative', minHeight: '100vh', display: 'flex', alignItems: 'center', overflow: 'hidden' }}>
      {/* Background gradient */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        background: 'radial-gradient(ellipse 70% 60% at 50% 20%, rgba(124,92,252,0.12) 0%, transparent 70%)',
      }} />

      {/* Waveform canvas */}
      <canvas ref={canvasRef} style={{
        position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.6,
      }} />

      <div className="container" style={{ position: 'relative', zIndex: 1, padding: '120px 24px 80px', textAlign: 'center' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          background: 'rgba(124,92,252,0.1)', border: '1px solid rgba(124,92,252,0.25)',
          borderRadius: 100, padding: '5px 14px', marginBottom: 32,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--green)', boxShadow: '0 0 8px var(--green)', flexShrink: 0 }} />
          <span style={{ fontSize: 12, fontWeight: 500, color: 'var(--text-muted)', letterSpacing: '0.01em' }}>
            Free &amp; Open Source · macOS 14.2+
          </span>
        </div>

        <h1 style={{
          fontSize: 'clamp(42px, 7vw, 80px)', fontWeight: 800,
          lineHeight: 1.05, letterSpacing: '-0.04em', marginBottom: 24,
        }}>
          Volume control,{' '}
          <span style={{
            background: 'linear-gradient(135deg, var(--accent-bright) 0%, #c084fc 100%)',
            WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
          }}>per app.</span>
        </h1>

        <p style={{
          fontSize: 'clamp(16px, 2vw, 20px)', color: 'var(--text-muted)', fontWeight: 400,
          maxWidth: 560, margin: '0 auto 40px', lineHeight: 1.65,
        }}>
          MixMate lives in your menu bar and gives you independent volume sliders for every app playing audio — no configuration required.
        </p>

        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap', marginBottom: 64 }}>
          <a href="https://github.com/bobbydeveaux/mixmate/releases/latest" target="_blank" rel="noopener">
            <button className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, padding: '13px 28px' }}>
              <AppleIcon />
              Download for macOS
            </button>
          </a>
          <a href="https://github.com/bobbydeveaux/mixmate" target="_blank" rel="noopener">
            <button className="btn-ghost" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, padding: '13px 24px' }}>
              <GitHubIcon />
              View on GitHub
            </button>
          </a>
        </div>

        {/* App preview card */}
        <div style={{
          display: 'inline-block', background: 'rgba(19,19,31,0.9)',
          border: '1px solid var(--border-bright)', borderRadius: 16,
          padding: '14px 14px 10px', backdropFilter: 'blur(20px)',
          boxShadow: '0 32px 80px rgba(0,0,0,0.5), 0 0 0 1px rgba(124,92,252,0.1)',
          width: '100%', maxWidth: 340, textAlign: 'left',
        }}>
          {/* Titlebar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, paddingBottom: 10, borderBottom: '1px solid var(--border)' }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M2 8c0 0 1-3 2.5-3s2 6 3.5 6 2-6 3.5-6 1.5 3 1.5 3" stroke="var(--accent-bright)" strokeWidth="1.4" strokeLinecap="round"/>
            </svg>
            <span style={{ fontSize: 13, fontWeight: 600, flex: 1 }}>MixMate</span>
            <button style={{ background: 'none', border: 'none', color: 'var(--text-dim)', cursor: 'pointer', padding: 0, lineHeight: 1 }}>↺</button>
          </div>

          {/* Tracks */}
          {TRACKS.map(track => (
            <div key={track.name} style={{ marginBottom: 8 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
                <div style={{ width: 24, height: 24, borderRadius: 6, background: `${track.color}22`, border: `1px solid ${track.color}44`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <div style={{ width: 8, height: 8, borderRadius: 2, background: track.color }} />
                </div>
                <span style={{ fontSize: 12, fontWeight: 500, flex: 1 }}>{track.name}</span>
                <span style={{ fontSize: 11, color: 'var(--text-dim)', width: 32, textAlign: 'right' }}>{Math.round(track.volume * 100)}%</span>
                <span style={{ color: 'var(--text-dim)', fontSize: 11 }}>🔊</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ fontSize: 9, color: 'var(--text-dim)' }}>🔈</span>
                <div style={{ flex: 1, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.06)', position: 'relative', overflow: 'hidden' }}>
                  <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${track.volume * 100}%`, background: track.color, borderRadius: 2, opacity: 0.8 }} />
                </div>
                <span style={{ fontSize: 9, color: 'var(--text-dim)' }}>🔊</span>
              </div>
            </div>
          ))}

          <div style={{ borderTop: '1px solid var(--border)', marginTop: 10, paddingTop: 8, display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 10, color: 'var(--text-dim)' }}>Launch at Login</span>
            <span style={{ fontSize: 10, color: 'var(--text-dim)' }}>Quit</span>
          </div>
        </div>
      </div>
    </section>
  )
}

function AppleIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 814 1000" fill="currentColor">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 376.7 0 248.3 0 124.8 0 57.5 25.3 25.7 85.3 25.7c58 0 102.8 40.2 137.4 40.2 33 0 81.8-41.4 137.4-41.4 51.3 0 96.6 26 129.5 78.9zM531.3 55.2c14.4-16.9 27.9-40.8 27.9-64.7 0-3.2-.3-6.5-.6-9.7-26.4 1-57.5 17.5-76.2 38.5-14.4 15.5-28.6 39.5-28.6 63.7 0 3.5.6 6.8 1 9.7 1.9.3 4.2.3 6.5.3 23.7 0 51.3-15.3 69.9-37.8z"/>
    </svg>
  )
}

function GitHubIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.604-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z"/>
    </svg>
  )
}
