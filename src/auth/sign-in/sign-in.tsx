import { useState } from "react";
import { Input } from "@heroui/input";
import { Button } from "@heroui/button";
import { Card, CardBody, CardHeader } from "@heroui/card";
import { EyeFilledIcon, EyeSlashFilledIcon } from "@heroui/shared-icons";
import { useNavigate } from "react-router-dom";
import { title } from "@/components/primitives";

export default function SignInPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isVisible, setIsVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  const toggleVisibility = () => setIsVisible(!isVisible);

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    // Simulate authentication process
    setTimeout(() => {
      setIsLoading(false);
      // Navigate to dashboard after successful login
      navigate("/dashboard");
    }, 1000);
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
              className="w-full mt-4 font-semibold"
              isDisabled={!email || !password}
            >
              {isLoading ? "Iniciando sesión..." : "Iniciar Sesión"}
            </Button>
          </form>
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