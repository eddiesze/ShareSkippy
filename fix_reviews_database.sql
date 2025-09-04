-- Fix Reviews Database Schema
-- This script will create the missing tables and functions for the reviews system

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

-- Create indexes for meetings table
CREATE INDEX IF NOT EXISTS idx_meetings_requester_id ON meetings(requester_id);
CREATE INDEX IF NOT EXISTS idx_meetings_recipient_id ON meetings(recipient_id);
CREATE INDEX IF NOT EXISTS idx_meetings_availability_id ON meetings(availability_id);
CREATE INDEX IF NOT EXISTS idx_meetings_conversation_id ON meetings(conversation_id);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);
CREATE INDEX IF NOT EXISTS idx_meetings_start_datetime ON meetings(start_datetime);
CREATE INDEX IF NOT EXISTS idx_meetings_end_datetime ON meetings(end_datetime);

-- Enable RLS for meetings table
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- Create policies for meetings table
DROP POLICY IF EXISTS "Users can view meetings they are involved in" ON meetings;
DROP POLICY IF EXISTS "Users can create meeting requests" ON meetings;
DROP POLICY IF EXISTS "Users can update meetings they are involved in" ON meetings;
DROP POLICY IF EXISTS "Users can delete meetings they created" ON meetings;

CREATE POLICY "Users can view meetings they are involved in" ON meetings
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can create meeting requests" ON meetings
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update meetings they are involved in" ON meetings
  FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can delete meetings they created" ON meetings
  FOR DELETE USING (auth.uid() = requester_id);

-- Now fix the reviews table
-- First, drop the old reviews table if it exists (this will delete any existing data)
DROP TABLE IF EXISTS reviews CASCADE;

-- Create the new reviews table with meeting_id
CREATE TABLE reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE NOT NULL,
  reviewer_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  reviewee_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Review details
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT NOT NULL CHECK (length(trim(comment)) >= 5),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_meeting_reviewer UNIQUE (meeting_id, reviewer_id),
  CONSTRAINT different_reviewer_reviewee CHECK (reviewer_id != reviewee_id)
);

-- Create indexes for reviews table
CREATE INDEX IF NOT EXISTS idx_reviews_meeting_id ON reviews(meeting_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee_id ON reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);

-- Enable RLS for reviews table
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Create policies for reviews table
DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Users can create reviews for their meetings" ON reviews;
DROP POLICY IF EXISTS "Users can update their own reviews" ON reviews;
DROP POLICY IF EXISTS "Users can delete their own reviews" ON reviews;

CREATE POLICY "Anyone can view reviews" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can create reviews for their meetings" ON reviews
  FOR INSERT WITH CHECK (
    auth.uid() = reviewer_id AND
    EXISTS (
      SELECT 1 FROM meetings 
      WHERE id = meeting_id 
      AND (requester_id = auth.uid() OR recipient_id = auth.uid())
      AND status = 'completed'
    )
  );

CREATE POLICY "Users can update their own reviews" ON reviews
  FOR UPDATE USING (auth.uid() = reviewer_id);

CREATE POLICY "Users can delete their own reviews" ON reviews
  FOR DELETE USING (auth.uid() = reviewer_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for reviews updated_at
DROP TRIGGER IF EXISTS on_reviews_update ON reviews;
CREATE TRIGGER on_reviews_update
  BEFORE UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_reviews_updated_at();

-- Create function to get user's average rating
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

-- Create function to get user's review count
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

-- Create function to check if user has pending reviews
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

-- Create function to handle meeting status updates
CREATE OR REPLACE FUNCTION handle_meeting_status_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the updated_at timestamp
  NEW.updated_at = NOW();
  
  -- If status is being changed to 'scheduled', ensure it was previously 'accepted'
  IF NEW.status = 'scheduled' AND OLD.status != 'accepted' THEN
    RAISE EXCEPTION 'Meeting can only be scheduled if it was previously accepted';
  END IF;
  
  -- If status is being changed to 'completed', ensure it was previously 'scheduled'
  IF NEW.status = 'completed' AND OLD.status != 'scheduled' THEN
    RAISE EXCEPTION 'Meeting can only be completed if it was previously scheduled';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for meeting status updates
DROP TRIGGER IF EXISTS on_meeting_status_update ON meetings;
CREATE TRIGGER on_meeting_status_update
  BEFORE UPDATE ON meetings
  FOR EACH ROW EXECUTE FUNCTION handle_meeting_status_update();

-- Create a function to automatically mark meetings as completed
CREATE OR REPLACE FUNCTION mark_completed_meetings()
RETURNS void AS $$
BEGIN
  UPDATE meetings 
  SET status = 'completed', updated_at = NOW()
  WHERE status = 'scheduled' 
    AND end_datetime < NOW();
END;
$$ LANGUAGE plpgsql;
