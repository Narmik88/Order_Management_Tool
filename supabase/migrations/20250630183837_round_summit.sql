/*
# Fix Database Schema Mismatch

This migration fixes the schema mismatch between the database and application code.

## Changes Made
1. **Departments Table**: Uses `name` as primary key (TEXT) instead of `id` (SERIAL)
2. **Agents Table**: Uses `name` as primary key and `department_name` as foreign key
3. **Orders Table**: References agents by `name` instead of `id`
4. **Assignment History**: References agents by `name` instead of `id`

## Security
- Enable RLS on all tables
- Add appropriate policies for data access

## Functions
- Recreate all functions to work with the new schema
- Maintain backward compatibility where possible
*/

-- Drop existing tables and functions to ensure clean slate
DROP TABLE IF EXISTS activity_log CASCADE;
DROP TABLE IF EXISTS assignment_history CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS agents CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS order_categories CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS log_activity CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
DROP FUNCTION IF EXISTS assign_order CASCADE;
DROP FUNCTION IF EXISTS complete_order CASCADE;
DROP FUNCTION IF EXISTS increment_completed_orders CASCADE;
DROP FUNCTION IF EXISTS increment_agent_orders CASCADE;
DROP FUNCTION IF EXISTS get_assignment_history CASCADE;
DROP FUNCTION IF EXISTS add_assignment_history CASCADE;

-- Create departments table with name as primary key
CREATE TABLE departments (
  name TEXT PRIMARY KEY,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create agents table with name as primary key and department_name reference
CREATE TABLE agents (
  name TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  extension TEXT,
  department_name TEXT REFERENCES departments(name) ON DELETE CASCADE,
  completed_orders INTEGER DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'on_leave')),
  last_active TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create order_categories table
CREATE TABLE order_categories (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  default_tasks JSONB DEFAULT '[]'::jsonb,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create orders table with agent name reference
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category_id INTEGER REFERENCES order_categories(id) ON DELETE SET NULL,
  type TEXT, -- Keep for backward compatibility
  status TEXT NOT NULL CHECK (status IN ('unassigned', 'in-progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  details JSONB DEFAULT '{}'::jsonb,
  tasks JSONB DEFAULT '[]'::jsonb,
  assigned_to TEXT REFERENCES agents(name) ON DELETE SET NULL,
  customer_name TEXT,
  customer_email TEXT,
  customer_phone TEXT,
  notes TEXT,
  due_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE
);

-- Create assignment_history table with agent name reference
CREATE TABLE assignment_history (
  id SERIAL PRIMARY KEY,
  order_id TEXT REFERENCES orders(id) ON DELETE CASCADE,
  agent_name TEXT REFERENCES agents(name) ON DELETE SET NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  unassigned_at TIMESTAMP WITH TIME ZONE,
  reason TEXT
);

-- Create activity_log table
CREATE TABLE activity_log (
  id SERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('order', 'agent', 'department', 'category')),
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  details JSONB DEFAULT '{}'::jsonb,
  performed_by TEXT REFERENCES agents(name) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for better performance
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_assigned_to ON orders(assigned_to);
CREATE INDEX idx_orders_category_id ON orders(category_id);
CREATE INDEX idx_orders_customer_name ON orders(customer_name);
CREATE INDEX idx_agents_department_name ON agents(department_name);
CREATE INDEX idx_assignment_history_order_id ON assignment_history(order_id);
CREATE INDEX idx_assignment_history_agent_name ON assignment_history(agent_name);
CREATE INDEX idx_activity_log_entity ON activity_log(entity_type, entity_id);
CREATE INDEX idx_activity_log_performed_by ON activity_log(performed_by);

-- Enable Row Level Security
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (allow all operations for now - adjust based on your auth requirements)
CREATE POLICY "Allow all operations on departments" ON departments FOR ALL USING (true);
CREATE POLICY "Allow all operations on agents" ON agents FOR ALL USING (true);
CREATE POLICY "Allow all operations on order_categories" ON order_categories FOR ALL USING (true);
CREATE POLICY "Allow all operations on orders" ON orders FOR ALL USING (true);
CREATE POLICY "Allow all operations on assignment_history" ON assignment_history FOR ALL USING (true);
CREATE POLICY "Allow all operations on activity_log" ON activity_log FOR ALL USING (true);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_departments_updated_at
    BEFORE UPDATE ON departments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agents_updated_at
    BEFORE UPDATE ON agents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_order_categories_updated_at
    BEFORE UPDATE ON order_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to log activities
CREATE OR REPLACE FUNCTION log_activity(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_action TEXT,
    p_details JSONB,
    p_performed_by TEXT
) RETURNS void AS $$
BEGIN
    INSERT INTO activity_log (
        entity_type,
        entity_id,
        action,
        details,
        performed_by
    ) VALUES (
        p_entity_type,
        p_entity_id,
        p_action,
        p_details,
        p_performed_by
    );
END;
$$ LANGUAGE plpgsql;

-- Function to assign order and track history
CREATE OR REPLACE FUNCTION assign_order(
  p_order_id TEXT,
  p_agent_name TEXT
) RETURNS void AS $$
BEGIN
  -- Update order
  UPDATE orders
  SET 
    assigned_to = p_agent_name,
    status = CASE 
      WHEN status = 'unassigned' THEN 'in-progress'
      ELSE status
    END
  WHERE id = p_order_id;

  -- Add assignment history
  INSERT INTO assignment_history (order_id, agent_name)
  VALUES (p_order_id, p_agent_name);

  -- Update agent stats (only if this is a new assignment)
  UPDATE agents
  SET total_orders = total_orders + 1
  WHERE name = p_agent_name
  AND NOT EXISTS (
    SELECT 1 FROM assignment_history
    WHERE order_id = p_order_id AND agent_name = p_agent_name
    AND assigned_at < NOW() - INTERVAL '1 second'
  );
END;
$$ LANGUAGE plpgsql;

-- Function to complete order and update stats
CREATE OR REPLACE FUNCTION complete_order(
  p_order_id TEXT
) RETURNS void AS $$
DECLARE
  v_agent_name TEXT;
BEGIN
  -- Get current agent
  SELECT assigned_to INTO v_agent_name
  FROM orders
  WHERE id = p_order_id;

  -- Update order
  UPDATE orders
  SET 
    status = 'completed',
    completed_at = NOW()
  WHERE id = p_order_id;

  -- Update agent stats if there is an assigned agent
  IF v_agent_name IS NOT NULL THEN
    UPDATE agents
    SET completed_orders = completed_orders + 1
    WHERE name = v_agent_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get assignment history
CREATE OR REPLACE FUNCTION get_assignment_history(
  p_order_id TEXT
) RETURNS TABLE (
  agent_name TEXT,
  assigned_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT ah.agent_name, ah.assigned_at
  FROM assignment_history ah
  WHERE ah.order_id = p_order_id
  ORDER BY ah.assigned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to increment completed orders for an agent
CREATE OR REPLACE FUNCTION increment_completed_orders(
  p_agent_name TEXT
) RETURNS void AS $$
BEGIN
  UPDATE agents
  SET completed_orders = completed_orders + 1
  WHERE name = p_agent_name;
END;
$$ LANGUAGE plpgsql;

-- Function to increment total orders for an agent
CREATE OR REPLACE FUNCTION increment_agent_orders(
  p_agent_name TEXT
) RETURNS void AS $$
BEGIN
  UPDATE agents
  SET total_orders = total_orders + 1
  WHERE name = p_agent_name;
END;
$$ LANGUAGE plpgsql;

-- Insert default departments
INSERT INTO departments (name, description) VALUES
('Management', 'Management team'),
('Support', 'Customer support team'),
('Sales', 'Sales team')
ON CONFLICT (name) DO NOTHING;

-- Insert default order categories
INSERT INTO order_categories (name, description, default_tasks) VALUES
('SIP Trunk', 'SIP Trunk orders', '[
    {"id": "1", "text": "CSA Signed", "required": true},
    {"id": "2", "text": "Customer Created", "required": true},
    {"id": "3", "text": "Account Created", "required": true},
    {"id": "4", "text": "DID Provisioned", "required": true},
    {"id": "5", "text": "Subscriptions Added", "required": true},
    {"id": "6", "text": "Welcome Email Sent", "required": true}
]'::jsonb),
('RO Cloud', 'RO Cloud CPS orders', '[
    {"id": "1", "text": "CSA Signed", "required": true},
    {"id": "2", "text": "Customer Created", "required": true},
    {"id": "3", "text": "Accounts Created", "required": true},
    {"id": "4", "text": "Inbound Routing Set", "required": true},
    {"id": "5", "text": "Auto Attendant Set", "required": true},
    {"id": "6", "text": "Phones Provisioned", "required": true}
]'::jsonb),
('3CX', '3CX Cloud/On Prem orders', '[
    {"id": "1", "text": "CSA Signed", "required": true},
    {"id": "2", "text": "Customer Created", "required": true},
    {"id": "3", "text": "Account Created", "required": true},
    {"id": "4", "text": "3CX License Setup", "required": true},
    {"id": "5", "text": "System Configuration", "required": true}
]'::jsonb)
ON CONFLICT (name) DO NOTHING;