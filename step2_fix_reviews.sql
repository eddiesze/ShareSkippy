-- Step 2: Fix reviews table
-- First, let's see what the current reviews table looks like
-- If it doesn't have meeting_id, we need to add it

-- Check if meeting_id column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'reviews' AND column_name = 'meeting_id'
    ) THEN
        -- Add meeting_id column
        ALTER TABLE reviews ADD COLUMN meeting_id UUID;
        
        -- Add foreign key constraint
        ALTER TABLE reviews ADD CONSTRAINT reviews_meeting_id_fkey 
        FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE;
        
        -- Make it NOT NULL (but we'll need to handle existing data)
        -- For now, let's make it nullable and handle it in the application
    END IF;
END $$;

-- Create indexes for reviews
CREATE INDEX IF NOT EXISTS idx_reviews_meeting_id ON reviews(meeting_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee_id ON reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);

-- Enable RLS if not already enabled
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Update policies
DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Users can create reviews" ON reviews;

CREATE POLICY "Anyone can view reviews" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can create reviews" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);
