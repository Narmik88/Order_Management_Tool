import type { DatabaseConfig } from '../types';

const DB_CONFIG_KEY = 'supabase_config';

export function getStoredDatabaseConfig(): DatabaseConfig | null {
  const stored = localStorage.getItem(DB_CONFIG_KEY);
  if (!stored) return null;
  
  try {
    return JSON.parse(stored) as DatabaseConfig;
  } catch {
    return null;
  }
}

export async function saveDatabaseConfig(config: DatabaseConfig): Promise<void> {
  localStorage.setItem(DB_CONFIG_KEY, JSON.stringify(config));
}

export function clearDatabaseConfig(): void {
  localStorage.removeItem(DB_CONFIG_KEY);
}