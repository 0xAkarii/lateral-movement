-- ====================================================================
-- Customer database - the crown jewel data
-- ====================================================================

USE customers;

CREATE TABLE IF NOT EXISTS customers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    credit_card_last4 VARCHAR(4),
    ssn_hash VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customers (full_name, email, phone, address, credit_card_last4, ssn_hash) VALUES
('Budi Santoso', 'budi@example.com', '081234567890', 'Jl. Merdeka 1, Jakarta', '4521', 'a3f5d8e9b2c1...'),
('Sari Dewi', 'sari@example.com', '081298765432', 'Jl. Sudirman 100, Bandung', '8732', 'b2e4f7a1c5d3...'),
('Ahmad Rizal', 'ahmad@example.com', '081255544433', 'Jl. Diponegoro 50, Surabaya', '1209', 'c1d3e5f8a9b2...'),
('Siti Nurhaliza', 'siti@example.com', '081222111000', 'Jl. Gatot Subroto 25, Medan', '5544', 'd5a7c9e2f4b6...'),
('John Doe', 'john@example.com', '081200001111', 'Jl. Thamrin 10, Jakarta', '9876', 'e8b0d3f6a9c1...');

CREATE TABLE IF NOT EXISTS api_keys (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    api_key VARCHAR(64) NOT NULL,
    description VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO api_keys (user_id, api_key, description) VALUES
(1, 'ak_live_4eC39HqLyjWDarjtT1zdp7dc', 'Production payment API'),
(1, 'sk_live_BQokikJOvBiI2HlWgH4olfQ2', 'Stripe secret key'),
(2, 'AKIA1234567890ABCDEF', 'AWS access key'),
(3, 'ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'GitHub personal token');

-- Flag table
CREATE TABLE IF NOT EXISTS internal_flags (
    flag_name VARCHAR(50) PRIMARY KEY,
    flag_value VARCHAR(200) NOT NULL
);

INSERT INTO internal_flags VALUES
('crown_jewel', 'CYBR{n3tw0rk_tr4v3rs4l_succ3ssful_ev1ct1on_n33d3d}'),
('admin_secret', 'CYBR{db_dump_4ch13v3d}');
