/**
 * The pure half of photo handling: what size to draw, and where to crop.
 *
 * Separated out because canvas does not exist in node, and the arithmetic is
 * the part that goes wrong — an avatar that stretches a dog sideways, or a
 * "resize" that quietly upscales a small photo into a blurry big one.
 */

export interface Size {
  width: number
  height: number
}

/**
 * Fits an image inside a square of `max`, preserving aspect ratio.
 *
 * Never upscales. An image already smaller than the box is returned untouched:
 * enlarging it adds bytes and no detail, and the "full" copy exists to be
 * analysed later, where a real 800px photo beats a fake 2048px one.
 */
export function fitWithin(source: Size, max: number): Size {
  const { width, height } = source
  if (width <= 0 || height <= 0 || max <= 0) return { width: 0, height: 0 }
  const longest = Math.max(width, height)
  if (longest <= max) return { width: Math.round(width), height: Math.round(height) }
  const scale = max / longest
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  }
}

export interface Crop {
  sx: number
  sy: number
  size: number
}

/**
 * The square to take for an avatar.
 *
 * Centred horizontally, but biased UP vertically on a portrait photo: a photo
 * of an animal taken by their owner has the head in the top half far more often
 * than not, and a dead-centre crop of a standing dog is a picture of its chest.
 */
export function squareCrop(source: Size): Crop {
  const { width, height } = source
  if (width <= 0 || height <= 0) return { sx: 0, sy: 0, size: 0 }
  const size = Math.min(width, height)
  const sx = Math.round((width - size) / 2)
  // A third of the way down the spare height, not half.
  const sy = height > width ? Math.round((height - size) / 3) : Math.round((height - size) / 2)
  return { sx, sy, size }
}

/** Longest edge kept for the analysable copy, and the avatar's square size. */
export const FULL_MAX_EDGE = 2048
export const AVATAR_SIZE = 512

/** What we will accept from a file picker. */
export const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']

/** Hard ceiling before we even try to decode. Phones produce big files. */
export const MAX_UPLOAD_BYTES = 12 * 1024 * 1024

export function describeRejection(file: { type: string; size: number }): string | null {
  if (file.size > MAX_UPLOAD_BYTES) {
    return `That photo is ${(file.size / 1024 / 1024).toFixed(1)}MB, which is larger than we can take. Most phones have a "smaller size" option when sharing.`
  }
  if (!ACCEPTED_IMAGE_TYPES.includes(file.type)) {
    return 'That looks like it is not a photo. JPEG, PNG or WebP all work.'
  }
  return null
}
