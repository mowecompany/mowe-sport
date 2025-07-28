import React from 'react';
import { Icon } from '@iconify/react';
import { Progress } from '@heroui/progress';

interface FormValidationProgressProps {
  validationState: {
    errors: { [key: string]: string };
    touched: { [key: string]: boolean };
    isValid: boolean;
  };
  requiredFields: string[];
  formData: { [key: string]: any };
}

export const FormValidationProgress: React.FC<FormValidationProgressProps> = ({
  validationState,
  requiredFields,
  formData
}) => {
  const getValidationProgress = () => {
    let validFields = 0;
    let totalFields = requiredFields.length;

    requiredFields.forEach(field => {
      const hasValue = formData[field] && formData[field].toString().trim() !== '';
      const hasError = validationState.errors[field];
      
      if (hasValue && !hasError) {
        validFields++;
      }
    });

    return {
      percentage: totalFields > 0 ? (validFields / totalFields) * 100 : 0,
      validFields,
      totalFields
    };
  };

  const { percentage, validFields, totalFields } = getValidationProgress();

  const getProgressColor = () => {
    if (percentage === 100) return 'success';
    if (percentage >= 70) return 'warning';
    return 'danger';
  };

  const getProgressIcon = () => {
    if (percentage === 100) return 'mdi:check-circle';
    if (percentage >= 70) return 'mdi:progress-check';
    return 'mdi:progress-clock';
  };

  return (
    <div className="bg-gray-50 p-3 rounded-lg space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Icon 
            icon={getProgressIcon()} 
            className={`w-4 h-4 ${
              percentage === 100 ? 'text-green-500' : 
              percentage >= 70 ? 'text-yellow-500' : 
              'text-red-500'
            }`} 
          />
          <span className="text-sm font-medium">
            Progreso de validación
          </span>
        </div>
        <span className="text-xs text-gray-600">
          {validFields}/{totalFields} campos válidos
        </span>
      </div>
      
      <Progress
        value={percentage}
        color={getProgressColor()}
        size="sm"
        className="w-full"
      />
      
      {percentage < 100 && (
        <div className="text-xs text-gray-600">
          {percentage === 0 ? 'Complete los campos requeridos' :
           percentage < 50 ? 'Faltan varios campos por completar' :
           percentage < 100 ? 'Casi listo, revise los campos restantes' :
           'Formulario completo y válido'}
        </div>
      )}
    </div>
  );
};