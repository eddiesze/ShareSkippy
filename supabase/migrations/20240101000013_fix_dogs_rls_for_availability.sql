-- Fix RLS policies for dogs table to allow viewing dogs in active availability posts
-- This allows users to see dog information when viewing availability posts from other users

-- ============================================
-- FIX DOGS TABLE RLS POLICIES
-- ============================================

-- Drop the existing restrictive policy
DROP POLICY IF EXISTS "Users can view their own dogs" ON dogs;

-- Create a new policy that allows users to view their own dogs
CREATE POLICY "Users can view their own dogs" ON dogs
  FOR SELECT USING (auth.uid() = owner_id);

-- Add a policy to allow viewing dogs that are associated with active availability posts
-- This allows authenticated users to view dog information for dogs in active availability posts
CREATE POLICY "Users can view dogs in active availability posts" ON dogs
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND 
    EXISTS (
      SELECT 1 FROM availability 
      WHERE (availability.dog_id = dogs.id OR dogs.id = ANY(availability.dog_ids))
      AND availability.status = 'active'
    )
  );

-- ============================================
-- VERIFY THE POLICIES
-- ============================================

-- Check that the policies were created successfully
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'dogs' 
ORDER BY policyname;
