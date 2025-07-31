import React from 'react';
import { Icon } from '@iconify/react';
import { Popover, PopoverTrigger, PopoverContent } from '@heroui/popover';
import { Button } from '@heroui/button';

interface ValidationHelpProps {
  type: 'email' | 'phone' | 'identification' | 'url';
  country?: string;
}

const validationHelp = {
  email: {
    title: 'Formato de Email',
    rules: [
      'Debe contener @ y un dominio válido',
      'Ejemplo: usuario@ejemplo.com',
      'Se verificará que no esté registrado'
    ]
  },
  phone: {
    title: 'Formato de Teléfono',
    rules: [
      'Incluir código de país (+57 para Colombia)',
      'Ejemplo: +57 300 123 4567',
      'Formatos internacionales aceptados'
    ]
  },
  identification: {
    title: 'Formato de Identificación',
    rules: [
      'Colombia: Cédula de 6-10 dígitos',
      'Pasaporte: AA123456',
      'Solo letras, números, guiones y puntos'
    ]
  },
  url: {
    title: 'Formato de URL',
    rules: [
      'Debe incluir http:// o https://',
      'Ejemplo: https://ejemplo.com/foto.jpg',
      'Formatos de imagen recomendados: jpg, png, webp'
    ]
  }
};

export const ValidationHelp: React.FC<ValidationHelpProps> = ({ type, country: _country = 'CO' }) => {
  const help = validationHelp[type];
  
  if (!help) return null;

  return (
    <Popover placement="top">
      <PopoverTrigger>
        <Button
          isIconOnly
          variant="light"
          size="sm"
          className="min-w-unit-6 w-6 h-6"
        >
          <Icon icon="mdi:help-circle-outline" className="w-4 h-4 text-gray-400" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="p-3 max-w-xs">
        <div className="space-y-2">
          <h4 className="font-medium text-sm">{help.title}</h4>
          <ul className="text-xs text-gray-600 space-y-1">
            {help.rules.map((rule, index) => (
              <li key={index} className="flex items-start gap-1">
                <Icon icon="mdi:check" className="w-3 h-3 text-green-500 mt-0.5 flex-shrink-0" />
                <span>{rule}</span>
              </li>
            ))}
          </ul>
        </div>
      </PopoverContent>
    </Popover>
  );
};