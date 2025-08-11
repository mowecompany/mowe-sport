import React, { useRef, useEffect } from 'react';

interface SingleLoadWrapperProps {
  children: React.ReactNode;
  onLoad: () => void;
  dependencies?: any[];
}

export const SingleLoadWrapper: React.FC<SingleLoadWrapperProps> = ({ 
  children, 
  onLoad, 
  dependencies = [] 
}) => {
  const hasLoadedRef = useRef(false);
  const mountedRef = useRef(false);

  useEffect(() => {
    if (mountedRef.current) return;
    mountedRef.current = true;

    if (!hasLoadedRef.current) {
      hasLoadedRef.current = true;
      onLoad();
    }
  }, []);

  // Reset on dependency changes
  useEffect(() => {
    if (dependencies.length > 0) {
      hasLoadedRef.current = false;
    }
  }, dependencies);

  return <>{children}</>;
};