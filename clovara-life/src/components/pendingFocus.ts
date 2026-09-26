/**
 * One element to bring into view after the next surface change.
 *
 * "Add body condition" on Home used to open Life at the top, leaving somebody
 * to scroll past First Nights, the certificate and the projection to find the
 * question it named (UAT run 1, D4). Home leaves the target here; the surface
 * that owns it takes it once, on mount.
 */
let pending: string | null = null

export function focusAfterNavigate(id: string): void {
  pending = id
}

export function takePendingFocus(): string | null {
  const id = pending
  pending = null
  return id
}
