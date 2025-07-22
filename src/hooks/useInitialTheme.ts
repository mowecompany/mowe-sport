import { useEffect } from 'react';
import { useTheme } from '@heroui/use-theme';

export const useInitialTheme = () => {
  const { setTheme } = useTheme();

  useEffect(() => {
    // Obtener el tema del localStorage o usar el tema del sistema
    const savedTheme = localStorage.getItem('theme');
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    
    // Usar el tema guardado o el del sistema
    setTheme(savedTheme || systemTheme);
  }, [setTheme]);
};
