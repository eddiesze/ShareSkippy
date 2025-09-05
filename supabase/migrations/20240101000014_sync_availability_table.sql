-- Migration: Sync availability table with current Supabase schema
-- Add missing fields to match the actual database structure

-- Add missing time and scheduling fields
ALTER TABLE availability ADD COLUMN IF NOT EXISTS start_time time without time zone;
ALTER TABLE availability ADD COLUMN IF NOT EXISTS end_time time without time zone;
ALTER TABLE availability ADD COLUMN IF NOT EXISTS duration_minutes integer;
ALTER TABLE availability ADD COLUMN IF NOT EXISTS is_recurring boolean DEFAULT false;
ALTER TABLE availability ADD COLUMN IF NOT EXISTS recurring_days TEXT[];

-- Add flexibility level field
ALTER TABLE availability ADD COLUMN IF NOT EXISTS flexibility_level text;
ALTER TABLE availability ADD CONSTRAINT availability_flexibility_level_check 
CHECK (flexibility_level = ANY (ARRAY['strict'::text, 'moderate'::text, 'flexible'::text]));

-- Add separate pick up/drop off fields (in addition to existing can_pick_up_drop_off)
ALTER TABLE availability ADD COLUMN IF NOT EXISTS can_drop_off boolean DEFAULT false;
ALTER TABLE availability ADD COLUMN IF NOT EXISTS can_pick_up boolean DEFAULT false;

-- Update existing can_pick_up_drop_off to populate the new fields
UPDATE availability 
SET can_drop_off = can_pick_up_drop_off, 
    can_pick_up = can_pick_up_drop_off 
WHERE can_pick_up_drop_off = true;

-- Add comments to describe the new columns
COMMENT ON COLUMN availability.start_time IS 'Start time for availability window';
COMMENT ON COLUMN availability.end_time IS 'End time for availability window';
COMMENT ON COLUMN availability.duration_minutes IS 'Duration of the availability in minutes';
COMMENT ON COLUMN availability.is_recurring IS 'Whether this availability repeats';
COMMENT ON COLUMN availability.recurring_days IS 'Array of days when availability recurs';
COMMENT ON COLUMN availability.flexibility_level IS 'How flexible the scheduling is (strict, moderate, flexible)';
COMMENT ON COLUMN availability.can_drop_off IS 'Whether the user can drop off the dog';
COMMENT ON COLUMN availability.can_pick_up IS 'Whether the user can pick up the dog';

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_availability_start_time ON availability(start_time);
CREATE INDEX IF NOT EXISTS idx_availability_end_time ON availability(end_time);
CREATE INDEX IF NOT EXISTS idx_availability_flexibility_level ON availability(flexibility_level);
CREATE INDEX IF NOT EXISTS idx_availability_is_recurring ON availability(is_recurring);

-- Verify the migration
SELECT 
    'Availability table sync completed successfully' as status,
    COUNT(*) as total_posts,
    COUNT(CASE WHEN start_time IS NOT NULL THEN 1 END) as posts_with_start_time,
    COUNT(CASE WHEN end_time IS NOT NULL THEN 1 END) as posts_with_end_time,
    COUNT(CASE WHEN is_recurring = true THEN 1 END) as recurring_posts,
    COUNT(CASE WHEN can_drop_off = true THEN 1 END) as posts_with_drop_off,
    COUNT(CASE WHEN can_pick_up = true THEN 1 END) as posts_with_pick_up
FROM availability;
