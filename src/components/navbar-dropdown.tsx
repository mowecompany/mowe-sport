import React from "react";
import { Link } from "@heroui/link";
import { motion, AnimatePresence } from "framer-motion";
import { link as linkStyles } from "@heroui/theme";
import clsx from "clsx";

interface NavDropdownItem {
  label: string;
  href: string;
  icon?: React.ReactNode;
}

interface NavDropdownProps {
  items: NavDropdownItem[];
  isOpen: boolean;
}

export const NavbarDropdown: React.FC<NavDropdownProps> = ({
  items,
  isOpen,
}) => {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          animate={{ opacity: 1, y: 0, scale: 1 }}
          className="absolute top-full left-0 mt-2 z-50 min-w-[220px] overflow-hidden"
          exit={{ opacity: 0, y: -10, scale: 0.95 }}
          initial={{ opacity: 0, y: -10, scale: 0.95 }}
          transition={{
            duration: 0.2,
            ease: [0.16, 1, 0.3, 1],
          }}
        >
          {/* Contenedor principal con efecto glass/blur */}
          <div className="backdrop-blur-xl bg-white/50 dark:bg-black/50 border border-white/20 dark:border-white/10 rounded-xl shadow-2xl p-1">
            <ul className="flex flex-col gap-0.5">
              {items.map((item, index) => (
                <motion.li
                  key={`${item.label}-${index}`}
                  animate={{ opacity: 1, x: 0 }}
                  initial={{ opacity: 0, x: -10 }}
                  transition={{
                    duration: 0.2,
                    delay: index * 0.05,
                    ease: [0.16, 1, 0.3, 1],
                  }}
                >
                  <Link
                    className={clsx(
                      linkStyles({ color: "foreground" }),
                      "flex items-center gap-3 w-full px-3 py-2.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 transition-all duration-200 text-sm font-medium",
                    )}
                    href={item.href}
                  >
                    {item.icon && (
                      <span className="text-default-500 flex-shrink-0">
                        {item.icon}
                      </span>
                    )}
                    <span>{item.label}</span>
                  </Link>
                </motion.li>
              ))}
            </ul>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};
