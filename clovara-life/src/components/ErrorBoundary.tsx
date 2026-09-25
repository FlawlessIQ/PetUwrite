import { Component, type ErrorInfo, type ReactNode } from 'react'
import { CloverMark } from './CloverMark'

const STORAGE_KEY = 'clovara-life.pets.v1'

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

/**
 * The last line of defence.
 *
 * This exists for one scenario: something throws during render in front of an
 * audience, and the person holding the laptop cannot open devtools. Without a
 * boundary that is a permanent white screen. With one it is a branded card and a
 * button that clears stored pets and reloads.
 *
 * `Start over` clears localStorage rather than just re-rendering, because the
 * realistic cause of a render throw here is a malformed or stale pet in storage —
 * re-rendering the same bad state would simply throw again.
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Left in deliberately: if this ever fires in a rehearsal we want the trace.
    console.error('Clovara Life crashed:', error, info.componentStack)
  }

  private startOver = () => {
    try {
      localStorage.removeItem(STORAGE_KEY)
    } catch {
      /* storage blocked — reloading is still the right move */
    }
    window.location.replace(window.location.pathname)
  }

  render() {
    if (!this.state.error) return this.props.children

    return (
      <div className="flex min-h-screen items-center justify-center bg-cream px-5 py-10">
        <div className="card w-full max-w-[440px] px-6 py-8 text-center">
          <div className="mx-auto mb-5 w-fit">
            <CloverMark size={36} />
          </div>
          <h1 className="font-display text-[26px] leading-tight text-ink">
            Something went wrong
          </h1>
          <p className="mx-auto mt-2.5 max-w-[36ch] text-[14.5px] leading-relaxed text-ink-2">
            This one is on us, not on you. Starting over clears the pets saved in this browser and
            reloads a clean demo.
          </p>
          <button type="button" onClick={this.startOver} className="pill-primary mt-6">
            Start over
          </button>
          <p className="mt-5 break-words text-[12px] leading-relaxed text-ink-2/70">
            {this.state.error.message}
          </p>
        </div>
      </div>
    )
  }
}
