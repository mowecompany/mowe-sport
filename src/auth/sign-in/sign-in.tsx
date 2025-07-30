import { useState, useEffect } from "react";
import { Input } from "@heroui/input";
import { Button } from "@heroui/button";
import { Card, CardBody, CardHeader } from "@heroui/card";
import { EyeFilledIcon, EyeSlashFilledIcon } from "@heroui/shared-icons";
import { useNavigate } from "react-router-dom";
import { title } from "@/components/primitives";
import { authService } from "@/services/auth";
import { useAuth } from "@/hooks/useAuth";
import { useInitialTheme } from "@/hooks/useInitialTheme";

export default function SignInPage() {
  useInitialTheme();
  const [email, setEmail] = useState("admin@mowesport.com"); // Pre-filled for testing
  const [password, setPassword] = useState("123456"); // Corregir contraseña de prueba
  const [isVisible, setIsVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();

  // Si ya está autenticado, redirigir al dashboard
  useEffect(() => {
    if (isAuthenticated) {
      navigate("/dashboard", { replace: true });
    }
  }, [isAuthenticated, navigate]);

  const toggleVisibility = () => setIsVisible(!isVisible);

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError("");

    console.log("Attempting login with:", email); // Debug log

    try {
      const result = await authService.signIn(email, password);
      console.log("Login result:", result); // Debug log

      if (result.success) {
        console.log("Login successful, navigating to dashboard"); // Debug log
        // Forzar navegación inmediata sin esperar al useEffect
        setTimeout(() => {
          navigate("/dashboard", { replace: true });
        }, 100);
      } else {
        setError(result.error || result.message);
      }
    } catch (err) {
      console.error("Login error:", err); // Debug log
      setError("Error al iniciar sesión. Por favor, intenta de nuevo.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 px-4">
      <Card className="w-full max-w-md shadow-2xl">
        <CardHeader className="flex flex-col gap-3 pb-6">
          <div className="flex items-center justify-center">
            <img alt="MoweSport Logo" src="/favicon.png" className="w-12 h-12" />
          </div>
          <div className="text-center">
            <h1 className={title({ size: "sm" })}>Bienvenido</h1>
            <p className="text-default-500 text-sm mt-2">
              Inicia sesión en tu cuenta de MoweSport
            </p>
          </div>
        </CardHeader>
        <CardBody className="pt-0 gap-4">
          <form onSubmit={handleSignIn} className="flex flex-col gap-4">
            <Input
              type="email"
              label="Correo electrónico"
              placeholder="tu@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              isRequired
              variant="bordered"
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
            />
            <Input
              label="Contraseña"
              placeholder="Ingresa tu contraseña"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              isRequired
              variant="bordered"
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
              type={isVisible ? "text" : "password"}
              classNames={{
                input: "text-sm",
                inputWrapper: "border-default-200 hover:border-default-400"
              }}
            />

            {error && (
              <div className="bg-danger-50 border border-danger-200 text-danger-600 px-4 py-3 rounded-lg text-sm">
                {error}
              </div>
            )}

            <p className="text-sm text-default-500">
              <button
                onClick={() => navigate("")}
                // /auth/forgot-password
                className="text-primary hover:underline font-medium"
              >
                ¿Olvidastes tu constraseña?
              </button>
            </p>

            <Button
              type="submit"
              color="primary"
              size="lg"
              isLoading={isLoading}
              className="w-full font-semibold"
              isDisabled={!email || !password}
            >
              {isLoading ? "Iniciando sesión..." : "Iniciar Sesión"}
            </Button>
          </form>

          {/* Test credentials info */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mt-4">
            <div className="text-xs text-blue-800">
              <p className="font-medium mb-1">Credenciales de prueba (Super Admin):</p>
              <p>Email: admin@mowesport.com</p>
              <p>Contraseña: 123456</p>
            </div>
          </div>
          <div className="text-center mt-6">
            <p className="text-sm text-default-500">
              ¿No tienes una cuenta?{" "}
              <button
                onClick={() => navigate("/auth/sign-up")}
                className="text-primary hover:underline font-medium"
              >
                Regístrate aquí
              </button>
            </p>
          </div>
        </CardBody>
      </Card>
    </div>
  );
}