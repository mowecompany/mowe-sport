import { useMemo } from 'react';
import { UserRole } from '@/services/types';

export interface RoleInfo {
  label: string;
  color: 'danger' | 'warning' | 'secondary' | 'primary' | 'success' | 'default';
  description: string;
}

export interface UserCapabilities {
  canManageUsers: boolean;
  canManageSystem: boolean;
  canViewAnalytics: boolean;
  canExportData: boolean;
  canDeleteAccount: boolean;
  label: string;
}

export interface AccountStatusInfo {
  label: string;
  color: 'success' | 'danger' | 'warning' | 'default';
  description: string;
}

export const useUserRole = (role?: UserRole) => {
  const roleInfo = useMemo((): RoleInfo => {
    const roleMap: Record<UserRole, RoleInfo> = {
      'super_admin': { 
        label: 'Super Administrador', 
        color: 'danger', 
        description: 'Acceso total al sistema' 
      },
      'city_admin': { 
        label: 'Administrador de Ciudad', 
        color: 'warning', 
        description: 'Gestión de ciudad y deportes' 
      },
      'tournament_admin': { 
        label: 'Administrador de Torneo', 
        color: 'secondary', 
        description: 'Gestión de torneos' 
      },
      'owner': { 
        label: 'Propietario', 
        color: 'primary', 
        description: 'Gestión de equipos' 
      },
      'coach': { 
        label: 'Entrenador', 
        color: 'success', 
        description: 'Entrenamiento y tácticas' 
      },
      'referee': { 
        label: 'Árbitro', 
        color: 'default', 
        description: 'Arbitraje de partidos' 
      },
      'player': { 
        label: 'Jugador', 
        color: 'success', 
        description: 'Participación en equipos' 
      },
      'client': { 
        label: 'Cliente', 
        color: 'default', 
        description: 'Visualización de contenido' 
      }
    };
    
    return roleMap[role || 'client'] || { 
      label: 'Usuario', 
      color: 'default', 
      description: 'Usuario del sistema' 
    };
  }, [role]);

  const capabilities = useMemo((): UserCapabilities => {
    const capabilityMap: Record<UserRole, UserCapabilities> = {
      'super_admin': {
        canManageUsers: true,
        canManageSystem: true,
        canViewAnalytics: true,
        canExportData: true,
        canDeleteAccount: false, // Super admin accounts shouldn't be deletable
        label: 'Super Administrador'
      },
      'city_admin': {
        canManageUsers: true,
        canManageSystem: false,
        canViewAnalytics: true,
        canExportData: true,
        canDeleteAccount: false,
        label: 'Administrador de Ciudad'
      },
      'tournament_admin': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: true,
        canExportData: true,
        canDeleteAccount: true,
        label: 'Administrador de Torneo'
      },
      'owner': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: false,
        canExportData: true,
        canDeleteAccount: true,
        label: 'Propietario'
      },
      'coach': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: false,
        canExportData: false,
        canDeleteAccount: true,
        label: 'Entrenador'
      },
      'referee': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: false,
        canExportData: false,
        canDeleteAccount: true,
        label: 'Árbitro'
      },
      'player': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: false,
        canExportData: false,
        canDeleteAccount: true,
        label: 'Jugador'
      },
      'client': {
        canManageUsers: false,
        canManageSystem: false,
        canViewAnalytics: false,
        canExportData: false,
        canDeleteAccount: true,
        label: 'Cliente'
      }
    };

    return capabilityMap[role || 'client'] || capabilityMap.client;
  }, [role]);

  return {
    roleInfo,
    capabilities
  };
};

export const useAccountStatus = (status?: string) => {
  const accountStatusInfo = useMemo((): AccountStatusInfo => {
    const statusMap: Record<string, AccountStatusInfo> = {
      'active': { 
        label: 'Activa', 
        color: 'success', 
        description: 'Cuenta completamente funcional' 
      },
      'suspended': { 
        label: 'Suspendida', 
        color: 'danger', 
        description: 'Cuenta temporalmente suspendida' 
      },
      'payment_pending': { 
        label: 'Pago Pendiente', 
        color: 'warning', 
        description: 'Requiere actualización de pago' 
      },
      'disabled': { 
        label: 'Deshabilitada', 
        color: 'default', 
        description: 'Cuenta deshabilitada por administrador' 
      }
    };

    return statusMap[status || 'active'] || { 
      label: 'Desconocido', 
      color: 'default', 
      description: 'Estado no definido' 
    };
  }, [status]);

  return accountStatusInfo;
};