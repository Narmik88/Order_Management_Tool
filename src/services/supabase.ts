import { createClient } from '@supabase/supabase-js';
import { getStoredDatabaseConfig } from '../utils/databaseConfig';
import type { Order, Department, DashboardStats } from '../types';

// Default configuration as fallback
const DEFAULT_CONFIG = {
  url: 'https://covlghocbmreatukbgdc.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvdmxnaG9jYm1yZWF0dWtiZ2RjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA3MzI0MTksImV4cCI6MjA0NjMwODQxOX0.ZBbyUFHKJMm27FygO68Tk3ycq1iHWdGYrVc4T85ayEQ'
};

function getSupabaseClient() {
  const storedConfig = getStoredDatabaseConfig();
  const config = storedConfig || DEFAULT_CONFIG;
  
  return createClient(config.url, config.anonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true
    },
    db: {
      schema: 'public'
    }
  });
}

class DatabaseService {
  private initialized = false;
  private initializationPromise: Promise<void> | null = null;
  private supabase = getSupabaseClient();

  async initialize(): Promise<void> {
    if (this.initialized) return;
    
    if (this.initializationPromise) {
      return this.initializationPromise;
    }

    this.initializationPromise = (async () => {
      try {
        const { data, error } = await this.supabase
          .from('departments')
          .select('count');

        if (error) {
          throw new Error(`Database connection failed: ${error.message}`);
        }

        this.initialized = true;
      } catch (error: any) {
        console.error('Database initialization failed:', error);
        throw new Error(error.message || 'Failed to connect to database');
      } finally {
        this.initializationPromise = null;
      }
    })();

    return this.initializationPromise;
  }

  private async ensureInitialized() {
    if (!this.initialized) {
      await this.initialize();
    }
  }

  async getAllDepartments(): Promise<Department[]> {
    try {
      await this.ensureInitialized();

      const { data: departments, error: deptError } = await this.supabase
        .from('departments')
        .select(`
          name,
          agents (
            name,
            email,
            extension,
            completed_orders,
            total_orders
          )
        `);

      if (deptError) {
        throw new Error(`Failed to fetch departments: ${deptError.message}`);
      }

      if (!departments) {
        return [];
      }

      return departments.map(dept => ({
        name: dept.name,
        agents: (dept.agents || []).map((agent: any) => ({
          name: agent.name,
          email: agent.email || '',
          extension: agent.extension || '',
          completedOrders: agent.completed_orders || 0,
          totalOrders: agent.total_orders || 0
        }))
      }));
    } catch (error: any) {
      console.error('Failed to fetch departments:', error);
      throw new Error(error.message || 'Failed to load departments');
    }
  }

  async saveDepartment(department: Department): Promise<void> {
    try {
      await this.ensureInitialized();

      const { error } = await this.supabase
        .from('departments')
        .upsert({ 
          name: department.name,
          created_at: new Date().toISOString()
        });

      if (error) {
        throw new Error(`Failed to save department: ${error.message}`);
      }
    } catch (error: any) {
      console.error('Failed to save department:', error);
      throw new Error(error.message || 'Failed to save department');
    }
  }

  async deleteDepartment(name: string): Promise<void> {
    try {
      await this.ensureInitialized();

      const { error: agentsError } = await this.supabase
        .from('agents')
        .delete()
        .eq('department_name', name);

      if (agentsError) {
        throw new Error(`Failed to delete department agents: ${agentsError.message}`);
      }

      const { error: deptError } = await this.supabase
        .from('departments')
        .delete()
        .eq('name', name);

      if (deptError) {
        throw new Error(`Failed to delete department: ${deptError.message}`);
      }
    } catch (error: any) {
      console.error('Failed to delete department:', error);
      throw new Error(error.message || 'Failed to delete department');
    }
  }

  async getAllOrders(): Promise<Order[]> {
    try {
      await this.ensureInitialized();

      const { data: orders, error: orderError } = await this.supabase
        .from('orders')
        .select('*');

      if (orderError) {
        throw new Error(`Failed to fetch orders: ${orderError.message}`);
      }

      if (!orders) {
        return [];
      }

      return orders.map(order => ({
        id: order.id,
        title: order.title,
        type: order.type,
        status: order.status,
        priority: order.priority,
        details: order.details || {},
        tasks: order.tasks || [],
        assignedTo: order.assigned_to,
        createdAt: order.created_at,
        completedAt: order.completed_at
      }));
    } catch (error: any) {
      console.error('Failed to fetch orders:', error);
      throw new Error(error.message || 'Failed to load orders');
    }
  }

  async getStats(): Promise<DashboardStats> {
    try {
      await this.ensureInitialized();

      const { data: orders, error } = await this.supabase
        .from('orders')
        .select('status');

      if (error) {
        throw new Error(`Failed to fetch stats: ${error.message}`);
      }

      if (!orders) {
        return {
          totalOrders: 0,
          completedOrders: 0,
          pendingOrders: 0
        };
      }

      const totalOrders = orders.length;
      const completedOrders = orders.filter(order => order.status === 'completed').length;

      return {
        totalOrders,
        completedOrders,
        pendingOrders: totalOrders - completedOrders
      };
    } catch (error: any) {
      console.error('Failed to fetch stats:', error);
      throw new Error(error.message || 'Failed to load statistics');
    }
  }

  reinitialize() {
    this.initialized = false;
    this.supabase = getSupabaseClient();
    return this.initialize();
  }
}

export const db = new DatabaseService();
export const supabase = getSupabaseClient();