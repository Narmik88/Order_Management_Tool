import React, { useState, useEffect } from 'react';
import { Save, Database, RefreshCw } from 'lucide-react';
import { getStoredDatabaseConfig, saveDatabaseConfig } from '../../utils/databaseConfig';
import { db } from '../../services/supabase';
import type { DatabaseConfig } from '../../types';

export const DatabaseSettings: React.FC = () => {
  const [config, setConfig] = useState<DatabaseConfig>({
    url: '',
    anonKey: '',
  });
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const storedConfig = getStoredDatabaseConfig();
    if (storedConfig) {
      setConfig(storedConfig);
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    setIsLoading(true);

    try {
      await saveDatabaseConfig(config);
      await db.reinitialize();
      setSuccess('Database configuration updated successfully');
    } catch (err) {
      setError('Failed to update database configuration');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Database className="w-5 h-5 text-indigo-600" />
        <h2 className="text-xl font-semibold">Database Configuration</h2>
      </div>

      {error && (
        <div className="bg-red-50 text-red-600 p-3 rounded-lg">
          {error}
        </div>
      )}

      {success && (
        <div className="bg-green-50 text-green-600 p-3 rounded-lg">
          {success}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Supabase URL
          </label>
          <input
            type="text"
            value={config.url}
            onChange={(e) => setConfig({ ...config, url: e.target.value })}
            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            placeholder="https://your-project.supabase.co"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">
            Anon Key
          </label>
          <input
            type="password"
            value={config.anonKey}
            onChange={(e) => setConfig({ ...config, anonKey: e.target.value })}
            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            placeholder="your-anon-key"
            required
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading ? (
            <RefreshCw className="w-5 h-5 mr-2 animate-spin" />
          ) : (
            <Save className="w-5 h-5 mr-2" />
          )}
          {isLoading ? 'Saving...' : 'Save Configuration'}
        </button>
      </form>
    </div>
  );
};