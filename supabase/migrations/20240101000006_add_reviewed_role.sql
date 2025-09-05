-- Add reviewed_role column to reviews table
-- This column tracks the role of the person being reviewed

-- Add the reviewed_role column
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewed_role TEXT;

-- Make it NOT NULL with a default value for existing records
UPDATE reviews SET reviewed_role = 'unknown' WHERE reviewed_role IS NULL;
ALTER TABLE reviews ALTER COLUMN reviewed_role SET NOT NULL;

-- Add constraint to ensure valid values
ALTER TABLE reviews ADD CONSTRAINT reviews_reviewed_role_check 
CHECK (reviewed_role IN ('requester', 'recipient'));

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_role ON reviews(reviewed_role);
