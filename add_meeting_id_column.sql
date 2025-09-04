-- Add meeting_id column to existing reviews table
-- This will fix the "Failed to fetch reviews" error

-- First, create the meetings table if it doesn't exist
CREATE TABLE IF NOT EXISTS meetings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  availability_id UUID REFERENCES availability(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  
  -- Meeting details
  title TEXT NOT NULL,
  description TEXT,
  meeting_place TEXT,
  
  -- Scheduling
  start_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
  end_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'scheduled', 'cancelled', 'completed')),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_meeting_times CHECK (end_datetime > start_datetime),
  CONSTRAINT different_participants CHECK (requester_id != recipient_id)
);

-- Enable RLS for meetings
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- Create policies for meetings
CREATE POLICY "Users can view meetings they are involved in" ON meetings
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can create meeting requests" ON meetings
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- Now add the meeting_id column to reviews table
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS meeting_id UUID;

-- Add foreign key constraint (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'reviews_meeting_id_fkey' 
        AND table_name = 'reviews'
    ) THEN
        ALTER TABLE reviews ADD CONSTRAINT reviews_meeting_id_fkey 
        FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_reviews_meeting_id ON reviews(meeting_id);

-- Create the required database functions
CREATE OR REPLACE FUNCTION get_user_average_rating(user_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  avg_rating DECIMAL;
BEGIN
  SELECT COALESCE(AVG(rating), 0) INTO avg_rating
  FROM reviews
  WHERE reviewee_id = user_id;
  
  RETURN ROUND(avg_rating, 2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_review_count(user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  review_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO review_count
  FROM reviews
  WHERE reviewee_id = user_id;
  
  RETURN review_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_pending_reviews_for_user(user_id UUID)
RETURNS TABLE (
  meeting_id UUID,
  meeting_title TEXT,
  other_participant_id UUID,
  other_participant_name TEXT,
  meeting_end_datetime TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id as meeting_id,
    m.title as meeting_title,
    CASE 
      WHEN m.requester_id = user_id THEN m.recipient_id
      ELSE m.requester_id
    END as other_participant_id,
    CASE 
      WHEN m.requester_id = user_id THEN p_recipient.name
      ELSE p_requester.name
    END as other_participant_name,
    m.end_datetime as meeting_end_datetime
  FROM meetings m
  LEFT JOIN profiles p_requester ON m.requester_id = p_requester.id
  LEFT JOIN profiles p_recipient ON m.recipient_id = p_recipient.id
  WHERE m.status = 'completed'
    AND (m.requester_id = user_id OR m.recipient_id = user_id)
    AND m.end_datetime < NOW() - INTERVAL '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM reviews r 
      WHERE r.meeting_id = m.id 
      AND r.reviewer_id = user_id
    );
END;
$$ LANGUAGE plpgsql;
