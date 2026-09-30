import { api, ApiError } from '../api/client';
import type { Access, Role } from '../api/types';

type Status = 'loading' | 'signedOut' | 'signedIn';

/** The message under a PIN field for a refused login / unlock. */
function pinRefused(e: unknown, fallback: string): string {
  if (!(e instanceof ApiError)) throw e;
  if (e.body?.error === 'locked_out') {
    return `Too many attempts — try again in ${e.body.retryAfter} s`;
  }
  return e.body?.error === 'invalid_pin' ? 'Wrong PIN' : fallback;
}

class SessionState {
  status = $state<Status>('loading');
  projectName = $state('');
  role = $state<Role | null>(null);
  /** *Allow control* is on in the app, so *Unlock control* is offered. */
  controlAllowed = $state(false);
  /** Shown on the login page after the server ended the session. */
  notice = $state<string | null>(null);

  async refresh(): Promise<void> {
    const s = await api.session();
    this.projectName = s.projectName;
    this.role = s.role ?? null;
    this.controlAllowed = s.controlAllowed;
    this.status = s.authenticated ? 'signedIn' : 'signedOut';
  }

  /** Null on success, else the message to show under the PIN field. */
  async login(pin: string): Promise<string | null> {
    try {
      const res = await api.login(pin);
      this.applyAccess(res);
      this.notice = null;
      this.status = 'signedIn';
      return null;
    } catch (e) {
      return pinRefused(e, 'Sign-in failed');
    }
  }

  /** *Unlock control* with the Operator PIN; null on success, else the message. */
  async unlock(pin: string): Promise<string | null> {
    try {
      this.applyAccess(await api.unlock(pin));
      return null;
    } catch (e) {
      return pinRefused(e, 'Unlock failed');
    }
  }

  async lock(): Promise<void> {
    this.applyAccess(await api.lock());
  }

  /** From our own unlock / lock, or the `access` event (another tab, the app's settings). */
  applyAccess(a: Access): void {
    this.role = a.role;
    this.controlAllowed = a.controlAllowed;
  }

  async logout(): Promise<void> {
    await api.logout();
    this.role = null;
    this.status = 'signedOut';
  }

  /** The server closed our session (PIN changed, signed out, app restarted). */
  async ended(): Promise<void> {
    await this.refresh();
    if (this.status === 'signedOut') this.notice = 'Signed out by the app';
  }
}

export const session = new SessionState();
