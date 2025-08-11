import { useState, useCallback, useRef } from 'react';

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  loading: boolean;
}

interface UseCacheOptions {
  ttl?: number; // Time to live in milliseconds
  key: string;
}

export function useDataCache<T>(options: UseCacheOptions) {
  const { ttl = 5 * 60 * 1000, key } = options; // Default 5 minutes TTL
  const [cache, setCache] = useState<CacheEntry<T> | null>(null);
  const loadingRef = useRef(false);

  const isExpired = useCallback(() => {
    if (!cache) return true;
    return Date.now() - cache.timestamp > ttl;
  }, [cache, ttl]);

  const isLoading = useCallback(() => {
    return loadingRef.current || (cache?.loading ?? false);
  }, [cache]);

  const getData = useCallback(() => {
    return cache?.data;
  }, [cache]);

  const setData = useCallback((data: T) => {
    setCache({
      data,
      timestamp: Date.now(),
      loading: false
    });
    loadingRef.current = false;
  }, []);

  const setLoading = useCallback((loading: boolean) => {
    loadingRef.current = loading;
    setCache(prev => prev ? { ...prev, loading } : null);
  }, []);

  const shouldFetch = useCallback((force = false) => {
    if (force) return true;
    if (isLoading()) return false;
    if (!cache) return true;
    return isExpired();
  }, [cache, isExpired, isLoading]);

  const invalidate = useCallback(() => {
    setCache(null);
    loadingRef.current = false;
  }, []);

  return {
    data: getData(),
    isLoading: isLoading(),
    isExpired: isExpired(),
    shouldFetch,
    setData,
    setLoading,
    invalidate
  };
}