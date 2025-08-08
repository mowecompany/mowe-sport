import React from 'react';
import { useAuth } from '@/hooks/useAuth';
import { usePermissions } from './ProtectedPage';
import type { UserRole } from '@/services/types';

interface NavigationItem {
  label: string;
  href: string;
  icon: string;
  allowedRoles: UserRole[];
  description?: string;
}

// Definir todas las rutas disponibles con sus permisos
export const NAVIGATION_ITEMS: NavigationItem[] = [
  // Dashboard - Todos los roles autenticados
  {
    label: 'Dashboard',
    href: '/dashboard',
    icon: 'mdi:view-dashboard',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Panel principal'
  },
  
  // Administración - Solo Super Admin
  {
    label: 'Administradores',
    href: '/administration/admins',
    icon: 'mdi:shield-account',
    allowedRoles: ['super_admin'],
    description: 'Gestión de administradores'
  },
  {
    label: 'Super Admin',
    href: '/administration/super_admin',
    icon: 'mdi:crown',
    allowedRoles: ['super_admin'],
    description: 'Configuración global del sistema'
  },
  
  // Gestión de usuarios - Super Admin y City Admin
  {
    label: 'Usuarios',
    href: '/administration/users',
    icon: 'mdi:account-group',
    allowedRoles: ['super_admin', 'city_admin', 'owner'],
    description: 'Gestión de usuarios del sistema'
  },
  
  // Jugadores - City Admin, Owner
  {
    label: 'Jugadores',
    href: '/administration/players',
    icon: 'mdi:account-multiple',
    allowedRoles: ['super_admin', 'city_admin', 'owner', 'coach'],
    description: 'Gestión de jugadores'
  },
  
  // Árbitros - Super Admin, City Admin
  {
    label: 'Árbitros',
    href: '/administration/referees',
    icon: 'mdi:whistle',
    allowedRoles: ['super_admin', 'city_admin'],
    description: 'Gestión de árbitros'
  },
  
  // Sección Principal - Accesible según rol
  {
    label: 'Torneos',
    href: '/main/tournaments',
    icon: 'mdi:trophy',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Gestión y visualización de torneos'
  },
  {
    label: 'Equipos',
    href: '/main/teams',
    icon: 'mdi:account-group',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client'],
    description: 'Gestión y visualización de equipos'
  },
  {
    label: 'Partidos',
    href: '/main/matches',
    icon: 'mdi:soccer',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Gestión y visualización de partidos'
  },
  {
    label: 'Estadísticas',
    href: '/main/statistics',
    icon: 'mdi:chart-bar',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client'],
    description: 'Estadísticas y métricas'
  },
  {
    label: 'Deportes',
    href: '/main/sports',
    icon: 'mdi:basketball',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Gestión de deportes'
  },
  {
    label: 'Calendario',
    href: '/main/calendar',
    icon: 'mdi:calendar',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Calendario de eventos'
  },
  
  // Configuración - Acceso limitado
  {
    label: 'Perfil',
    href: '/profile',
    icon: 'mdi:account',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    description: 'Configuración del perfil'
  },
  {
    label: 'Configuración',
    href: '/settings',
    icon: 'mdi:cog',
    allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner'],
    description: 'Configuración del sistema'
  }
];

// Hook para obtener elementos de navegación filtrados por rol
export const useRoleBasedNavigation = () => {
  const { canAccessMultiple } = usePermissions();

  const getFilteredNavigation = (): NavigationItem[] => {
    return NAVIGATION_ITEMS.filter(item => 
      canAccessMultiple(item.allowedRoles)
    );
  };

  const getNavigationBySection = () => {
    const filteredItems = getFilteredNavigation();
    
    return {
      dashboard: filteredItems.filter(item => item.href === '/dashboard'),
      administration: filteredItems.filter(item => item.href.startsWith('/administration')),
      main: filteredItems.filter(item => item.href.startsWith('/main')),
      settings: filteredItems.filter(item => 
        item.href === '/profile' || item.href === '/settings'
      )
    };
  };

  return {
    getAllowedNavigation: getFilteredNavigation,
    getNavigationBySection,
    canAccessRoute: (href: string) => {
      const item = NAVIGATION_ITEMS.find(nav => nav.href === href);
      return item ? canAccessMultiple(item.allowedRoles) : false;
    }
  };
};

// Componente para mostrar elementos de navegación
interface RoleBasedNavigationProps {
  section?: 'all' | 'administration' | 'main' | 'settings';
  className?: string;
}

export const RoleBasedNavigation: React.FC<RoleBasedNavigationProps> = ({
  section = 'all',
  className = ''
}) => {
  const { getNavigationBySection, getAllowedNavigation } = useRoleBasedNavigation();

  const getItemsToShow = () => {
    if (section === 'all') {
      return getAllowedNavigation();
    }
    
    const sections = getNavigationBySection();
    return sections[section] || [];
  };

  const items = getItemsToShow();

  if (items.length === 0) {
    return null;
  }

  return (
    <nav className={className}>
      {items.map((item) => (
        <a
          key={item.href}
          href={item.href}
          className="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors"
          title={item.description}
        >
          <i className={`${item.icon} text-lg`} />
          <span>{item.label}</span>
        </a>
      ))}
    </nav>
  );
};