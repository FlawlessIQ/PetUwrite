import { shareFilename } from './cardLayout'

/**
 * Getting a rendered card off the device (SPEC §6.1 "image download/share
 * sheet").
 *
 * Two paths, and the order matters. On a phone the share sheet is what people
 * mean by "share" — it reaches the message thread the card is actually for. On
 * a desktop there usually is no share sheet, and a download is what works.
 *
 * NOTHING IS UPLOADED. The card is drawn on the device and handed to the
 * operating system; it never touches our servers, which is the right default
 * for a photograph of somebody's pet and is what the Data Covenant implies.
 */

export type ShareOutcome = 'shared' | 'downloaded' | 'cancelled' | 'failed'

/** Whether this browser can put an image file into a share sheet. */
export function canShareFiles(file: File): boolean {
  const nav = navigator as Navigator & { canShare?: (d: ShareData) => boolean }
  return typeof nav.share === 'function' && typeof nav.canShare === 'function' && nav.canShare({ files: [file] })
}

export async function shareCardImage(
  blob: Blob,
  opts: { name: string; kind: string; title: string; now?: Date },
): Promise<ShareOutcome> {
  const filename = shareFilename(opts.name, opts.kind, opts.now ?? new Date())
  const file = new File([blob], filename, { type: 'image/png' })

  if (canShareFiles(file)) {
    try {
      await navigator.share({ files: [file], title: opts.title })
      return 'shared'
    } catch (err) {
      // AbortError is somebody closing the sheet. That is a decision, not a
      // failure, and must not trigger a fallback download they did not ask for
      // — a file appearing in Downloads after you cancelled is alarming.
      if ((err as { name?: string }).name === 'AbortError') return 'cancelled'
      /* anything else falls through to the download */
    }
  }

  try {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    a.remove()
    // Revoked late: revoking immediately races the download in Safari.
    setTimeout(() => URL.revokeObjectURL(url), 30_000)
    return 'downloaded'
  } catch {
    return 'failed'
  }
}
