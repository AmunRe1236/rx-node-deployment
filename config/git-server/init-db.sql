-- 🎩 GENTLEMAN Git Server Database Initialization
-- ═══════════════════════════════════════════════════════════════

-- Create extensions for better performance
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Set timezone
SET timezone = 'UTC';

-- Create indexes for better performance (will be created by Gitea, but good to have)
-- These will be created automatically by Gitea during first run

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'GENTLEMAN Git Server Database initialized successfully';
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'User: %', current_user;
    RAISE NOTICE 'Timestamp: %', now();
END $$; 