-- Add performance indexes for common queries

-- Index for availability table queries
CREATE INDEX IF NOT EXISTS idx_availability_owner_status ON availability(owner_id, status);
CREATE INDEX IF NOT EXISTS idx_availability_post_type_status ON availability(post_type, status);
CREATE INDEX IF NOT EXISTS idx_availability_created_at ON availability(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_availability_dog_id ON availability(dog_id);

-- Index for meetings table queries
CREATE INDEX IF NOT EXISTS idx_meetings_requester ON meetings(requester_id);
CREATE INDEX IF NOT EXISTS idx_meetings_recipient ON meetings(recipient_id);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);
CREATE INDEX IF NOT EXISTS idx_meetings_start_datetime ON meetings(start_datetime);
CREATE INDEX IF NOT EXISTS idx_meetings_availability_id ON meetings(availability_id);

-- Index for reviews table queries
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer ON reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed ON reviews(reviewed_id);
CREATE INDEX IF NOT EXISTS idx_reviews_meeting_id ON reviews(meeting_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC);

-- Index for dogs table queries
CREATE INDEX IF NOT EXISTS idx_dogs_owner_id ON dogs(owner_id);
CREATE INDEX IF NOT EXISTS idx_dogs_created_at ON dogs(created_at DESC);

-- Index for profiles table queries
CREATE INDEX IF NOT EXISTS idx_profiles_city ON profiles(city);
CREATE INDEX IF NOT EXISTS idx_profiles_neighborhood ON profiles(neighborhood);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Index for messages table queries
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Index for conversations table queries
CREATE INDEX IF NOT EXISTS idx_conversations_participant1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);

-- Composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_availability_owner_type_status ON availability(owner_id, post_type, status);
CREATE INDEX IF NOT EXISTS idx_meetings_user_status ON meetings(requester_id, recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_reviews_user_meeting ON reviews(reviewer_id, meeting_id);
