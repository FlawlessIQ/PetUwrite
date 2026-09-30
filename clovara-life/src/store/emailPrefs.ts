/**
 * Moment-email opt-in (Phase B, AO6), through the Life functions — the choice
 * lives server-side in `life_prefs/{uid}`, which no client rule can reach.
 *
 * EMAIL_MOMENTS_ENABLED is a build flag and is OFF in production: the switch
 * must not appear until the functions it calls are deployed and a sending
 * domain exists. Set VITE_EMAIL_MOMENTS=1 to build it in (emulator, preview).
 */
import { callable } from './callable'

export const EMAIL_MOMENTS_ENABLED = import.meta.env.VITE_EMAIL_MOMENTS === '1'

export const getEmailPrefs = () => callable<{ moments: boolean }>('getEmailPrefs', {})
export const setEmailPrefs = (moments: boolean) => callable<{ moments: boolean }>('setEmailPrefs', { moments })
