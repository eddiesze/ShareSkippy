'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';

export const QueryProvider = ({ children }) => {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        // Cache data for 5 minutes by default
        staleTime: 5 * 60 * 1000,
        // Keep data in cache for 10 minutes
        gcTime: 10 * 60 * 1000,
        // Retry failed requests 2 times
        retry: 2,
        // Don't refetch on window focus by default
        refetchOnWindowFocus: false,
        // Don't refetch on reconnect by default
        refetchOnReconnect: false,
      },
      mutations: {
        // Retry failed mutations once
        retry: 1,
      },
    },
  }));

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};
