import { api } from '../api/client';
import type { Config } from '../api/types';

/** `/api/config`: column catalogue, thresholds, test patterns. Loaded once per sign-in. */
class ConfigState {
  value = $state<Config | null>(null);

  async load(): Promise<void> {
    this.value = await api.config();
  }
}

export const config = new ConfigState();
