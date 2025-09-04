-- Step 1: Create meetings table
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_meetings_requester_id ON meetings(requester_id);
CREATE INDEX IF NOT EXISTS idx_meetings_recipient_id ON meetings(recipient_id);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);

-- Enable RLS
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view meetings they are involved in" ON meetings
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can create meeting requests" ON meetings
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update meetings they are involved in" ON meetings
  FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = recipient_id);
