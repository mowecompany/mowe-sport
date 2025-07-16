import { FC, useState, useEffect } from "react";
import { Switch } from "@heroui/switch";
import { Icon } from "@iconify/react";
import { useTheme } from "@heroui/use-theme";
import clsx from "clsx";

export interface ThemeSwitchProps {
  className?: string;
  size?: "sm" | "md" | "lg";
  color?: "default" | "primary" | "secondary" | "success" | "warning" | "danger";
}

export const ThemeSwitch: FC<ThemeSwitchProps> = ({
  className,
  size = "sm",
  color = "primary",
}) => {
  const [isMounted, setIsMounted] = useState(false);
  const { theme, setTheme } = useTheme();

  const isDarkMode = theme === "dark";

  const handleToggle = () => {
    setTheme(isDarkMode ? "light" : "dark");
  };

  useEffect(() => {
    setIsMounted(true);
  }, []);

  // Prevent Hydration Mismatch
  if (!isMounted) {
    return <div className="w-6 h-6" />;
  }

  return (
    <Switch
      isSelected={isDarkMode}
      onValueChange={handleToggle}
      size={size}
      color={color}
      className={clsx(
        "transition-opacity hover:opacity-80",
        className,
      )}
      startContent={<Icon icon="lucide:sun" />}
      endContent={<Icon icon="lucide:moon" />}
      aria-label={isDarkMode ? "Switch to light mode" : "Switch to dark mode"}
    />
  );
};
