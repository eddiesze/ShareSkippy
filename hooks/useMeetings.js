import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useUser } from '@/contexts/UserContext';

// Fetch meetings
export const useMeetings = () => {
  const { user } = useUser();
  
  return useQuery({
    queryKey: ['meetings', user?.id],
    queryFn: async () => {
      if (!user) return { meetings: [] };
      
      // First, update any meetings that should be marked as completed
      await fetch('/api/meetings/update-status', { method: 'POST' });
      
      // Then fetch the updated meetings
      const response = await fetch('/api/meetings');
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to fetch meetings');
      }
      
      return data;
    },
    enabled: !!user,
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
};

// Update meeting status
export const useUpdateMeetingStatus = () => {
  const queryClient = useQueryClient();
  const { user } = useUser();
  
  return useMutation({
    mutationFn: async ({ meetingId, status, message }) => {
      const response = await fetch(`/api/meetings/${meetingId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status, message }),
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        console.error('Meeting update failed:', data);
        throw new Error(data.error || 'Failed to update meeting status');
      }
      
      return data;
    },
    onSuccess: () => {
      // Invalidate and refetch meetings
      queryClient.invalidateQueries({ queryKey: ['meetings', user?.id] });
    },
  });
};
