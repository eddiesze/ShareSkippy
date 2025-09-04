-- Step 3: Create database functions
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
