import type { Problem, Projector } from '../api/types';
import { formatStart } from './alerts';
import { withUnit } from './labels';

export type CardStatusTone = 'none' | 'warning' | 'error' | 'offline';

/** The card's status footer: one line, the projector's verdict (WEB_UI_PLAN step 14). */
export interface CardStatus {
  tone: CardStatusTone;
  icon: 'check' | 'warn' | 'error' | 'lock' | 'offline';
  text: string;
}

/** The worst problem in words: `Exhaust hot, 52 °C`, `Signal lost on SDI 2`, `Error F305`. */
function problemText(x: Problem, p: Projector): string {
  switch (x.kind) {
    case 'temperature':
      return `${x.badge}, ${withUnit(x.flag)}`;
    case 'signal':
      return `Signal lost on ${p.input}`;
    default:
      return x.badge;
  }
}

/**
 * Offline with the last answer's time, the worst warning or error with
 * `+N more` for the rest, or *No problems*. The footer is always there, so
 * every card has one height.
 */
export function cardStatus(p: Projector, now: Date): CardStatus {
  if (p.connection === 'offline') {
    return {
      tone: 'offline',
      icon: 'offline',
      text: p.lastSeen ? `Offline, last seen ${formatStart(new Date(p.lastSeen), now)}` : 'Offline',
    };
  }
  const problems = p.status.problems.filter((x) => x.level === 'warning' || x.level === 'error');
  const worst = problems[0];
  if (!worst) return { tone: 'none', icon: 'check', text: 'No problems' };
  const more = problems.length > 1 ? `, +${problems.length - 1} more` : '';
  return {
    tone: worst.level === 'error' ? 'error' : 'warning',
    icon: worst.kind === 'login' ? 'lock' : worst.level === 'error' ? 'error' : 'warn',
    text: problemText(worst, p) + more,
  };
}
