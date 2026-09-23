import { FIREBASE_CONFIG } from '../auth/config'
import {
  AVATAR_SIZE,
  FULL_MAX_EDGE,
  describeRejection,
  fitWithin,
  squareCrop,
} from './imageMath'

/**
 * Pet photos (SPEC §4.2): an avatar now, and a copy good enough to measure
 * later.
 *
 * TWO IMAGES, NOT ONE OR THREE.
 *
 *  - `avatar` — 512px square, shown everywhere. Small enough that Home does not
 *    download a phone photo on every load.
 *  - `full` — 2048px long edge. SPEC asks for "the original, for future
 *    body-condition trend"; what that needs is enough pixels to assess an
 *    animal's shape, which 2048px is and a 12MB HEIC nobody's browser can
 *    decode is not. Recorded as a spec divergence in ROADMAP rather than done
 *    quietly.
 *
 * Both are produced in the browser with canvas — no dependency, and the phone
 * uploads half a megabyte instead of twelve.
 */

export interface PetPhoto {
  /** Storage path of the analysable copy. */
  fullPath: string
  /** Storage path of the square avatar. */
  avatarPath: string
  /** Download URL for the avatar, so rendering costs no extra round trip. */
  avatarUrl: string
  uploadedAt: string
  width: number
  height: number
}

/** Decodes a file to an ImageBitmap, or an <img> where that is unavailable. */
async function decode(file: File): Promise<{ source: CanvasImageSource; width: number; height: number }> {
  if (typeof createImageBitmap === 'function') {
    const bitmap = await createImageBitmap(file)
    return { source: bitmap, width: bitmap.width, height: bitmap.height }
  }
  // Safari before 17 has no createImageBitmap for HEIC; the object URL path
  // works wherever the browser can display the format at all.
  const url = URL.createObjectURL(file)
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image()
      el.onload = () => resolve(el)
      el.onerror = () => reject(new Error('Could not read that image.'))
      el.src = url
    })
    return { source: img, width: img.naturalWidth, height: img.naturalHeight }
  } finally {
    URL.revokeObjectURL(url)
  }
}

function toBlob(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) =>
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error('Could not process that image.'))),
      'image/jpeg',
      quality,
    ),
  )
}

async function renderVariants(file: File) {
  const { source, width, height } = await decode(file)

  const fullSize = fitWithin({ width, height }, FULL_MAX_EDGE)
  const fullCanvas = document.createElement('canvas')
  fullCanvas.width = fullSize.width
  fullCanvas.height = fullSize.height
  const fc = fullCanvas.getContext('2d')
  if (!fc) throw new Error('Could not process that image.')
  fc.drawImage(source, 0, 0, fullSize.width, fullSize.height)

  const crop = squareCrop({ width, height })
  const avatarCanvas = document.createElement('canvas')
  avatarCanvas.width = AVATAR_SIZE
  avatarCanvas.height = AVATAR_SIZE
  const ac = avatarCanvas.getContext('2d')
  if (!ac) throw new Error('Could not process that image.')
  ac.drawImage(source, crop.sx, crop.sy, crop.size, crop.size, 0, 0, AVATAR_SIZE, AVATAR_SIZE)

  return {
    full: await toBlob(fullCanvas, 0.85),
    avatar: await toBlob(avatarCanvas, 0.88),
    width: fullSize.width,
    height: fullSize.height,
  }
}

/**
 * Resizes and uploads. Returns what to store on the pet.
 *
 * Path shape mirrors Firestore — `life/households/{id}/pets/{id}/…` — so the
 * Storage rule can ask the same question the Firestore rule does: is this
 * person in that household.
 */
export async function uploadPetPhoto(
  file: File,
  ctx: { householdId: string; petId: string },
): Promise<PetPhoto> {
  const rejection = describeRejection(file)
  if (rejection) throw new Error(rejection)

  const [{ getApps, getApp, initializeApp }, storageMod] = await Promise.all([
    import('firebase/app'),
    import('firebase/storage'),
  ])
  const { getStorage, ref, uploadBytes, getDownloadURL, connectStorageEmulator } = storageMod
  const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
  const storage = getStorage(app)
  if (import.meta.env.VITE_USE_EMULATORS === '1') {
    try {
      connectStorageEmulator(storage, '127.0.0.1', 9199)
    } catch {
      /* already connected */
    }
  }

  const variants = await renderVariants(file)
  const stamp = Date.now()
  const base = `life/households/${ctx.householdId}/pets/${ctx.petId}`
  const fullPath = `${base}/photo-${stamp}-full.jpg`
  const avatarPath = `${base}/photo-${stamp}-avatar.jpg`

  await uploadBytes(ref(storage, fullPath), variants.full, { contentType: 'image/jpeg' })
  const avatarRef = ref(storage, avatarPath)
  await uploadBytes(avatarRef, variants.avatar, { contentType: 'image/jpeg' })

  return {
    fullPath,
    avatarPath,
    avatarUrl: await getDownloadURL(avatarRef),
    uploadedAt: new Date(stamp).toISOString(),
    width: variants.width,
    height: variants.height,
  }
}
