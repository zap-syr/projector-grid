import { api, ApiError } from '../api/client';
import type { Role } from '../api/types';

type Status = 'loading' | 'signedOut' | 'signedIn';

class SessionState {
  status = $state<Status>('loading');
  projectName = $state('');
  role = $state<Role | null>(null);
  /** Shown on the login page after the server ended the session. */
  notice = $state<string | null>(null);

  async refresh(): Promise<void> {
    const s = await api.session();
    this.projectName = s.projectName;
    this.role = s.role ?? null;
    this.status = s.authenticated ? 'signedIn' : 'signedOut';
  }

  /** Null on success, else the message to show under the PIN field. */
  async login(pin: string): Promise<string | null> {
    try {
      const res = await api.login(pin);
      this.role = res.role;
      this.notice = null;
      this.status = 'signedIn';
      return null;
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      if (e.body?.error === 'locked_out') {
        return `Too many attempts — try again in ${e.body.retryAfter} s`;
      }
      return e.body?.error === 'invalid_pin' ? 'Wrong PIN' : 'Sign-in failed';
    }
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
