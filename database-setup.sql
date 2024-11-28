-- Drop existing tables to ensure clean slate
DROP TABLE IF EXISTS activity_log CASCADE;
DROP TABLE IF EXISTS assignment_history CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS agents CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS order_categories CASCADE;

-- Create departments table
CREATE TABLE departments (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create agents table
CREATE TABLE agents (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  extension TEXT,
  department_id INTEGER REFERENCES departments(id) ON DELETE SET NULL,
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

-- Create orders table
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category_id INTEGER REFERENCES order_categories(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('unassigned', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  details JSONB DEFAULT '{}'::jsonb,
  tasks JSONB DEFAULT '[]'::jsonb,
  assigned_to INTEGER REFERENCES agents(id) ON DELETE SET NULL,
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

-- Create assignment_history table
CREATE TABLE assignment_history (
  id SERIAL PRIMARY KEY,
  order_id TEXT REFERENCES orders(id) ON DELETE CASCADE,
  agent_id INTEGER REFERENCES agents(id) ON DELETE SET NULL,
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
  performed_by INTEGER REFERENCES agents(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for better performance
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_assigned_to ON orders(assigned_to);
CREATE INDEX idx_orders_category_id ON orders(category_id);
CREATE INDEX idx_orders_customer_name ON orders(customer_name);
CREATE INDEX idx_agents_department_id ON agents(department_id);
CREATE INDEX idx_assignment_history_order_id ON assignment_history(order_id);
CREATE INDEX idx_assignment_history_agent_id ON assignment_history(agent_id);
CREATE INDEX idx_activity_log_entity ON activity_log(entity_type, entity_id);
CREATE INDEX idx_activity_log_performed_by ON activity_log(performed_by);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

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
    p_performed_by INTEGER
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
]'::jsonb);

-- Insert default departments
INSERT INTO departments (name, description) VALUES
('Management', 'Management team'),
('Support', 'Customer support team'),
('Sales', 'Sales team');

-- Grant necessary permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO postgres;