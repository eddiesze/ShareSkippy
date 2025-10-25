-- This migration explicitly grants all base table permissions to the 'authenticated' role,
-- overriding the blanket REVOKE commands and allowing the application to function.
-- Row Level Security (RLS) policies below will handle the fine-grained restrictions.

-- 1. EXPLICITLY GRANT BASE PERMISSIONS (REQUIRED TO FIX 42501 ERROR)
-- Grant ALL basic DML permissions to the 'authenticated' role for core application tables.
-- The existing RLS policies in 20240101000000_initial_schema.sql will restrict access to rows.
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.dogs TO authenticated;
GRANT ALL ON public.availability TO authenticated;
GRANT ALL ON public.messages TO authenticated;
GRANT ALL ON public.conversations TO authenticated;

-- Restore base SELECT permission for utility/logging tables that caused errors
GRANT SELECT ON public.user_activity TO authenticated;
GRANT SELECT ON public.reviews TO authenticated;
GRANT SELECT ON public.reviews_pending TO authenticated;
GRANT SELECT ON public.meetings TO authenticated;


-- 2. RESTORE/CREATE RLS POLICIES FOR PUBLIC READS (Community Features)

-- PROFILES RLS Fix: Allows any logged-in user to view all profiles (for community/matchmaking)
DROP POLICY IF EXISTS "Allow authenticated users to read all profiles" ON profiles;
CREATE POLICY "Allow authenticated users to read all profiles" ON profiles
  FOR SELECT TO authenticated USING (TRUE);

-- DOGS RLS Fix: Allows any logged-in user to view all dog profiles (needed for public profile view)
DROP POLICY IF EXISTS "Allow authenticated users to read all dogs" ON dogs;
CREATE POLICY "Allow authenticated users to read all dogs" ON dogs
  FOR SELECT TO authenticated USING (TRUE);

-- AVAILABILITY RLS Fix: Allows viewing of all active posts
DROP POLICY IF EXISTS "Allow authenticated users to read active availability" ON availability;
CREATE POLICY "Allow authenticated users to read active availability" ON availability
  FOR SELECT TO authenticated USING (status = 'active');

-- REVIEWS RLS Fix: Allows reading all active reviews (needed for public profile/UserReviews component)
DROP POLICY IF EXISTS "Allow authenticated users to read all active reviews" ON reviews;
CREATE POLICY "Allow authenticated users to read all active reviews" ON reviews
  FOR SELECT TO authenticated USING (status = 'active');

-- USER_ACTIVITY RLS Fix: Ensure users can only see their own activity (default security)
DROP POLICY IF EXISTS "Users can view their own activity" ON user_activity;
CREATE POLICY "Users can view their own activity" ON user_activity
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- DANGER: Explicitly grant base table permissions to the 'authenticated' role.
-- This bypasses the base permission denial caused by previous blanket REVOKE statements.

-- Grant ALL DML permissions (SELECT, INSERT, UPDATE, DELETE) to the 'authenticated' role for the meetings table.
GRANT ALL ON public.meetings TO authenticated;

-- Ensure RLS is correctly defined for meetings.
-- Users should only be able to SELECT/UPDATE/DELETE meetings they are a participant in.

-- 1. RLS Policy: SELECT (View)
-- Allows viewing of a meeting if the current user is either the requester or the recipient.
DROP POLICY IF EXISTS "Users can view their own meetings" ON meetings;
CREATE POLICY "Users can view their own meetings" ON meetings
  FOR SELECT TO authenticated USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- 2. RLS Policy: UPDATE (Update Status/Time)
-- Allows a user to update a meeting only if they are a participant.
DROP POLICY IF EXISTS "Users can update their own meetings" ON meetings;
CREATE POLICY "Users can update their own meetings" ON meetings
  FOR UPDATE TO authenticated USING (auth.uid() = requester_id OR auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- 3. RLS Policy: INSERT (Create new meeting)
-- Allows a user to create a meeting if they are either the requester or the recipient (usually the requester).
DROP POLICY IF EXISTS "Users can create meetings" ON meetings;
CREATE POLICY "Users can create meetings" ON meetings
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- 4. RLS Policy: DELETE
DROP POLICY IF EXISTS "Users can delete their own meetings" ON meetings;
CREATE POLICY "Users can delete their own meetings" ON meetings
  FOR DELETE TO authenticated USING (auth.uid() = requester_id OR auth.uid() = recipient_id);