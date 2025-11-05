-- DBLift Demo - Encryption Support
-- Description: Add encryption support for sensitive data
-- Tags: security, encryption

-- API Keys table (encrypted values)
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL, -- Hashed API key
    key_prefix VARCHAR(10) NOT NULL, -- First few chars for identification
    scopes TEXT[], -- Array of permission scopes
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL,
    UNIQUE (user_id, key_name)
);

CREATE INDEX idx_api_keys_user ON api_keys(user_id);
CREATE INDEX idx_api_keys_active ON api_keys(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);

COMMENT ON TABLE api_keys IS 'API keys for programmatic access';

-- Sensitive data encryption metadata
CREATE TABLE encryption_keys (
    id SERIAL PRIMARY KEY,
    key_identifier VARCHAR(100) UNIQUE NOT NULL,
    algorithm VARCHAR(50) NOT NULL,
    key_version INTEGER NOT NULL,
    rotated_at TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_encryption_keys_active ON encryption_keys(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE encryption_keys IS 'Encryption key metadata for data protection';

