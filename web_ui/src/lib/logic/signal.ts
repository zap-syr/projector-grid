import type { Projector } from '../api/types';

/** How the signal pill reads (`SignalTone` in `domain/signal_state.dart`). */
export type SignalTone = 'good' | 'missing' | 'unknown';

/** `isUnusableSignalValue` in `projector_node.dart`. */
export function isUnusableSignal(raw: string | null | undefined): boolean {
  if (!raw) return true;
  if (raw === '-' || raw === 'Timeout' || raw === 'ER401') return true;
  return raw.toUpperCase() === 'NO SIGNAL';
}

/**
 * The signal pill's label and tone (`signalStateOf`): green with the
 * resolution; red *No signal* only while the projector is on; grey
 * otherwise, since no signal is expected in standby, warming up or cooling,
 * and nothing is known offline or with a failed login.
 */
export function signalState(p: Projector): { label: string; tone: SignalTone } {
  const reachable = p.connection === 'connected' || p.connection === 'unprotected';
  if (!reachable) return { label: 'Unknown', tone: 'unknown' };
  if (!isUnusableSignal(p.signal)) return { label: p.signal, tone: 'good' };
  if (p.signal.toUpperCase() === 'NO SIGNAL') {
    return { label: 'No signal', tone: p.power === 'on' ? 'missing' : 'unknown' };
  }
  return { label: 'Unknown', tone: 'unknown' };
}
