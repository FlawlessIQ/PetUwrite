import type { PetProfile } from '../data/types'

/**
 * Their face, or their initial.
 *
 * The fallback is a letter rather than a generic animal icon: a stock puppy
 * silhouette on someone's fourteen-year-old cat reads as carelessness, and an
 * initial never claims to be a picture of anything.
 */
export function PetAvatar({
  pet,
  size = 40,
  className = '',
}: {
  pet: PetProfile
  size?: number
  className?: string
}) {
  const initial = pet.name.trim().charAt(0).toUpperCase() || '·'
  const style = { width: size, height: size }

  if (pet.photo?.avatarUrl) {
    return (
      <img
        src={pet.photo.avatarUrl}
        alt=""
        width={size}
        height={size}
        loading="lazy"
        decoding="async"
        style={style}
        className={`shrink-0 rounded-full object-cover ring-1 ring-line ${className}`}
      />
    )
  }

  return (
    <span
      aria-hidden="true"
      style={{ ...style, fontSize: Math.round(size * 0.42) }}
      className={`grid shrink-0 place-items-center rounded-full bg-sage font-display font-semibold text-deep ring-1 ring-line ${className}`}
    >
      {initial}
    </span>
  )
}
