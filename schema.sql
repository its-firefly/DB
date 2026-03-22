-- Database schema for Contingent Worker Management System
-- SQLite 3 compatibility

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS vendors (
    vendor_id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_name TEXT NOT NULL UNIQUE,
    vendor_spoc TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sows (
    sow_id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER REFERENCES vendors(vendor_id),
    sow_number TEXT NOT NULL UNIQUE,
    sow_name TEXT,
    sow_type TEXT,
    sow_location TEXT DEFAULT 'MMGBSI_LLP',
    vendor_signatory TEXT,
    start_date DATE,
    end_date DATE,
    estimated_cost REAL,
    ariba_spoc TEXT,
    leader TEXT,
    sow_status TEXT DEFAULT 'Active',
    approved_hc INTEGER,
    actual_hc INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS change_orders (
    co_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sow_id INTEGER REFERENCES sows(sow_id),
    co_number TEXT NOT NULL,
    start_date DATE,
    end_date DATE,
    exp_hours REAL,
    po_number TEXT,
    estimated_cost REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sow_id, co_number)
);

CREATE TABLE IF NOT EXISTS workers (
    worker_id INTEGER PRIMARY KEY AUTOINCREMENT,
    resource_name TEXT NOT NULL,
    gender TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS resource_managers (
    rm_id INTEGER PRIMARY KEY AUTOINCREMENT,
    rm_name TEXT NOT NULL,
    rm_email TEXT UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cost_centers (
    cc_id INTEGER PRIMARY KEY AUTOINCREMENT,
    cc_number TEXT NOT NULL UNIQUE,
    cc_name TEXT,
    department TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assignments (
    assignment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    worker_id INTEGER REFERENCES workers(worker_id),
    sow_id INTEGER REFERENCES sows(sow_id),
    co_id INTEGER REFERENCES change_orders(co_id),
    cc_id INTEGER REFERENCES cost_centers(cc_id),
    rm_id INTEGER REFERENCES resource_managers(rm_id),
    otid TEXT,
    employment_type TEXT,
    organisation TEXT,
    billability TEXT,
    hire_date DATE,
    role TEXT,
    rate_per_hour REAL,
    tier_rate REAL,
    est_workday_end DATE,
    last_working_date DATE,
    c2h_status TEXT,
    onboarding_status TEXT,
    bgv_status TEXT,
    worker_status TEXT DEFAULT 'Active',
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT,
    role TEXT DEFAULT 'admin',
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Triggers for updated_at
CREATE TRIGGER IF NOT EXISTS Update_vendors_updated_at AFTER UPDATE ON vendors FOR EACH ROW BEGIN UPDATE vendors SET updated_at = CURRENT_TIMESTAMP WHERE vendor_id = OLD.vendor_id; END;
CREATE TRIGGER IF NOT EXISTS Update_sows_updated_at AFTER UPDATE ON sows FOR EACH ROW BEGIN UPDATE sows SET updated_at = CURRENT_TIMESTAMP WHERE sow_id = OLD.sow_id; END;
CREATE TRIGGER IF NOT EXISTS Update_change_orders_updated_at AFTER UPDATE ON change_orders FOR EACH ROW BEGIN UPDATE change_orders SET updated_at = CURRENT_TIMESTAMP WHERE co_id = OLD.co_id; END;
CREATE TRIGGER IF NOT EXISTS Update_workers_updated_at AFTER UPDATE ON workers FOR EACH ROW BEGIN UPDATE workers SET updated_at = CURRENT_TIMESTAMP WHERE worker_id = OLD.worker_id; END;
CREATE TRIGGER IF NOT EXISTS Update_resource_managers_updated_at AFTER UPDATE ON resource_managers FOR EACH ROW BEGIN UPDATE resource_managers SET updated_at = CURRENT_TIMESTAMP WHERE rm_id = OLD.rm_id; END;
CREATE TRIGGER IF NOT EXISTS Update_cost_centers_updated_at AFTER UPDATE ON cost_centers FOR EACH ROW BEGIN UPDATE cost_centers SET updated_at = CURRENT_TIMESTAMP WHERE cc_id = OLD.cc_id; END;
CREATE TRIGGER IF NOT EXISTS Update_assignments_updated_at AFTER UPDATE ON assignments FOR EACH ROW BEGIN UPDATE assignments SET updated_at = CURRENT_TIMESTAMP WHERE assignment_id = OLD.assignment_id; END;
CREATE TRIGGER IF NOT EXISTS Update_users_updated_at AFTER UPDATE ON users FOR EACH ROW BEGIN UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE user_id = OLD.user_id; END;
