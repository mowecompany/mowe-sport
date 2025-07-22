import { useState } from "react";
import { Input } from "@heroui/input";
import { Button } from "@heroui/button";
import { Card, CardBody, CardHeader } from "@heroui/card";
import { EyeFilledIcon, EyeSlashFilledIcon } from "@heroui/shared-icons";
import { useNavigate } from "react-router-dom";

import { title } from "@/components/primitives";
import { authService, type SignUpData } from "@/services/auth";
import { useInitialTheme } from "@/hooks/useInitialTheme";

export default function SignUpPage() {
  useInitialTheme();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [name, setName] = useState("");
  const [isVisible, setIsVisible] = useState(false);
  const [isConfirmVisible, setIsConfirmVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const navigate = useNavigate();

  const toggleVisibility = () => setIsVisible(!isVisible);
  const toggleConfirmVisibility = () => setIsConfirmVisible(!isConfirmVisible);

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Limpiar mensajes previos
    setError("");
    setSuccess("");
    
    // Validar que las contraseñas coincidan
    if (password !== confirmPassword) {
      setError("Las contraseñas no coinciden");
      return;
    }
    
    // Validar longitud de contraseña
    if (password.length < 6) {
      setError("La contraseña debe tener al menos 6 caracteres");
      return;
    }
    
    setIsLoading(true);
    
    try {
      const signUpData: SignUpData = {
        name,
        email,
        password
      };
      
      const response = await authService.signUp(signUpData);
      
      if (response.success) {
        setSuccess(response.message);
        // Esperar un momento para mostrar el mensaje de éxito
        setTimeout(() => {
          navigate("/");
        }, 2000);
      } else {
        setError(response.error || response.message);
      }
    } catch (error: any) {
      setError("Error inesperado. Por favor, intenta de nuevo.");
      console.error("Sign up error:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 px-4">
      <Card className="w-full max-w-md shadow-2xl">
        <CardHeader className="flex flex-col gap-3 pb-6">
          <div className="flex items-center justify-center">
            <img
              alt="MoweSport Logo"
              className="w-12 h-12"
              src="/favicon.png"
            />
          </div>
          <div className="text-center">
            <h1 className={title({ size: "sm" })}>Crear Cuenta</h1>
            <p className="text-default-500 text-sm mt-2">
              Únete a MoweSport y gestiona tus torneos
            </p>
          </div>
        </CardHeader>
        <CardBody className="pt-0 gap-4">
          {error && (
            <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-3 mb-4">
              <p className="text-red-600 dark:text-red-400 text-sm">{error}</p>
            </div>
          )}
          
          {success && (
            <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-3 mb-4">
              <p className="text-green-600 dark:text-green-400 text-sm">{success}</p>
            </div>
          )}
          
          <form className="flex flex-col gap-4" onSubmit={handleSignUp}>
            <Input
              isRequired
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
              label="Nombre completo"
              placeholder="Tu nombre completo"
              type="text"
              value={name}
              variant="bordered"
              onChange={(e) => setName(e.target.value)}
            />
            <Input
              isRequired
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
              label="Correo electrónico"
              placeholder="tu@email.com"
              type="email"
              value={email}
              variant="bordered"
              onChange={(e) => setEmail(e.target.value)}
            />
            <Input
              isRequired
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
              endContent={
                <button
                  className="focus:outline-none"
                  type="button"
                  onClick={toggleVisibility}
                >
                  {isVisible ? (
                    <EyeSlashFilledIcon className="text-2xl text-default-400 pointer-events-none" />
                  ) : (
                    <EyeFilledIcon className="text-2xl text-default-400 pointer-events-none" />
                  )}
                </button>
              }
              label="Contraseña"
              placeholder="Crea una contraseña"
              type={isVisible ? "text" : "password"}
              value={password}
              variant="bordered"
              onChange={(e) => setPassword(e.target.value)}
            />
            <Input
              isRequired
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
              endContent={
                <button
                  className="focus:outline-none"
                  type="button"
                  onClick={toggleConfirmVisibility}
                >
                  {isConfirmVisible ? (
                    <EyeSlashFilledIcon className="text-2xl text-default-400 pointer-events-none" />
                  ) : (
                    <EyeFilledIcon className="text-2xl text-default-400 pointer-events-none" />
                  )}
                </button>
              }
              label="Confirmar contraseña"
              placeholder="Confirma tu contraseña"
              type={isConfirmVisible ? "text" : "password"}
              value={confirmPassword}
              variant="bordered"
              onChange={(e) => setConfirmPassword(e.target.value)}
            />
            <Button
              className="w-full font-semibold"
              color="primary"
              isDisabled={!email || !password || !confirmPassword || !name}
              isLoading={isLoading}
              size="lg"
              type="submit"
            >
              {isLoading ? "Creando cuenta..." : "Crear Cuenta"}
            </Button>
          </form>
          <div className="text-center mt-6">
            <p className="text-sm text-default-500">
              ¿Ya tienes una cuenta?{" "}
              <button
                onClick={() => navigate("/")}
                className="text-primary hover:underline font-medium"
              >
                Inicia sesión aquí
              </button>
            </p>
          </div>
        </CardBody>
      </Card>
    </div>
  );
};
