import { useState } from 'react';
import { Popover, PopoverTrigger, PopoverContent } from '@heroui/popover';
import { Avatar } from '@heroui/avatar';
import { Button } from '@heroui/button';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { 
  UserIcon, 
  Cog6ToothIcon, 
  ArrowRightOnRectangleIcon 
} from '@heroicons/react/24/outline';

export const UserProfilePopover = () => {
  const [isOpen, setIsOpen] = useState(false);
  const navigate = useNavigate();
  const { user: currentUser, signOut } = useAuth();

  const handleProfileClick = () => {
    setIsOpen(false);
    navigate('/profile');
  };

  const handleSettingsClick = () => {
    setIsOpen(false);
    navigate('/settings');
  };

  const handleLogout = () => {
    setIsOpen(false);
    signOut();
    navigate('/', { replace: true });
  };

  if (!currentUser) {
    return null;
  }

  const userInitials = `${currentUser.first_name?.charAt(0) || ''}${currentUser.last_name?.charAt(0) || ''}`.toUpperCase();
  const fullName = `${currentUser.first_name || ''} ${currentUser.last_name || ''}`.trim();

  return (
    <Popover 
      isOpen={isOpen} 
      onOpenChange={setIsOpen}
      placement="bottom-end"
      offset={10}
    >
      <PopoverTrigger>
        <Avatar
          isBordered
          color="primary"
          size="sm"
          src={currentUser.photo_url || undefined}
          name={userInitials}
          className="transition-transform cursor-pointer hover:scale-105"
          showFallback
        />
      </PopoverTrigger>
      <PopoverContent className="p-0 w-64">
        <div className="px-4 py-3 border-b border-divider">
          <div className="flex items-center gap-3">
            <Avatar
              size="md"
              src={currentUser.photo_url || undefined}
              name={userInitials}
              showFallback
            />
            <div className="flex flex-col">
              <p className="text-sm font-semibold text-foreground">
                {fullName || 'Usuario'}
              </p>
              <p className="text-xs text-default-500">
                {currentUser.email}
              </p>
              <p className="text-xs text-primary capitalize">
                {currentUser.primary_role?.replace('_', ' ') || 'Usuario'}
              </p>
            </div>
          </div>
        </div>
        
        <div className="py-2">
          <Button
            variant="light"
            className="w-full justify-start px-4 py-2 h-auto"
            startContent={<UserIcon className="w-4 h-4" />}
            onClick={handleProfileClick}
          >
            <span className="text-sm">Mi Perfil</span>
          </Button>
          
          <Button
            variant="light"
            className="w-full justify-start px-4 py-2 h-auto"
            startContent={<Cog6ToothIcon className="w-4 h-4" />}
            onClick={handleSettingsClick}
          >
            <span className="text-sm">Configuración</span>
          </Button>
        </div>
        
        <div className="border-t border-divider my-1" />
        
        <div className="py-2">
          <Button
            variant="light"
            color="danger"
            className="w-full justify-start px-4 py-2 h-auto"
            startContent={<ArrowRightOnRectangleIcon className="w-4 h-4" />}
            onClick={handleLogout}
          >
            <span className="text-sm">Cerrar Sesión</span>
          </Button>
        </div>
      </PopoverContent>
    </Popover>
  );
};