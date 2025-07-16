import { useState } from "react";
import { Kbd } from "@heroui/kbd";
import { Link } from "@heroui/link";
import { Input } from "@heroui/input";
import {
  Navbar as HeroUINavbar,
  NavbarBrand,
  NavbarContent,
  NavbarItem,
  NavbarMenuToggle,
  NavbarMenu,
  NavbarMenuItem,
} from "@heroui/navbar";
import { link as linkStyles } from "@heroui/theme";
import clsx from "clsx";

import { siteConfig } from "@/config/site";
import { ThemeSwitch } from "@/components/theme-switch";
import { NavbarDropdown } from "@/components/navbar-dropdown";
import { GithubIcon, SearchIcon } from "@/components/icons";

export const Navbar = () => {
  const [hoveredItem, setHoveredItem] = useState<string | null>(null);

  const handleMouseEnter = (label: string) => {
    setHoveredItem(label);
  };

  const handleMouseLeave = () => {
    setHoveredItem(null);
  };

  const searchInput = (
    <Input
      aria-label="Search"
      classNames={{
        inputWrapper:
          "bg-white/50 dark:bg-black/50 backdrop-blur-xl border border-white/20 dark:border-white/10",
        input: "text-sm",
      }}
      endContent={
        <Kbd className="hidden lg:inline-block" keys={["command"]}>
          K
        </Kbd>
      }
      labelPlacement="outside"
      placeholder="Search..."
      startContent={
        <SearchIcon className="text-base text-default-400 pointer-events-none flex-shrink-0" />
      }
      type="search"
    />
  );

  return (
    <HeroUINavbar
      className="backdrop-blur-xl bg-white/50 dark:bg-black/50 border-b border-white/20 dark:border-white/10 z-[1000]"
      isBlurred={false}
      maxWidth="xl"
      position="sticky"
    >
      <NavbarContent className="basis-1/5 sm:basis-full" justify="start">
        <NavbarBrand className="gap-3 max-w-fit">
          <div className="flex items-center gap-2">
            <div className="w-12 h-12 rounded-lg flex items-center justify-center">
              <img alt="icon" src="/favicon.png" />
            </div>
          </div>
        </NavbarBrand>
        <div className="hidden lg:flex gap-4 justify-start ml-2 ">
          {siteConfig.navItems.map((item) => (
            <NavbarItem
              key={item.label}
              className="relative"
              onMouseEnter={() => handleMouseEnter(item.label)}
              onMouseLeave={handleMouseLeave}
            >
              <div className="cursor-pointer px-3 py-2 rounded-lg transition-all duration-200 hover:bg-black/5 dark:hover:bg-white/5">
                <span
                  className={clsx(
                    linkStyles({ color: "foreground" }),
                    "data-[active=true]:text-primary data-[active=true]:font-medium text-sm font-medium",
                    hoveredItem === item.label && "text-primary",
                  )}
                >
                  {item.label}
                </span>
              </div>
              {item.items && (
                <NavbarDropdown
                  isOpen={hoveredItem === item.label}
                  items={item.items}
                />
              )}
            </NavbarItem>
          ))}
        </div>
      </NavbarContent>

      <NavbarContent
        className="hidden sm:flex basis-1/5 sm:basis-full"
        justify="end"
      >
        <NavbarItem className="hidden sm:flex gap-2">
          <Link isExternal href={siteConfig.links.github} title="GitHub">
            <GithubIcon className="text-default-500" />
          </Link>
          <ThemeSwitch />
        </NavbarItem>
        <NavbarItem className="hidden lg:flex">{searchInput}</NavbarItem>
        <NavbarItem className="hidden md:flex" />
      </NavbarContent>

      <NavbarContent className="sm:hidden basis-1 pl-4" justify="end">
        <Link isExternal href={siteConfig.links.github}>
          <GithubIcon className="text-default-500" />
        </Link>
        <ThemeSwitch />
        <NavbarMenuToggle />
      </NavbarContent>

      <NavbarMenu className="backdrop-blur-xl bg-white/95 dark:bg-black/95 border-none pt-6">
        <div className="px-4 mb-4">{searchInput}</div>
        <div className="mx-4 mt-2 flex flex-col gap-2">
          {/* Main section */}
          {siteConfig.navItems
            .filter((item) => item.items)
            .map((section, sectionIndex) => (
              <div key={`section-${sectionIndex}`} className="mb-4">
                <h3 className="text-default-500 text-sm font-medium mb-2 px-2">
                  {section.label}
                </h3>
                <div className="flex flex-col gap-1">
                  {section.items?.map((item, index) => (
                    <NavbarMenuItem key={`${item.label}-${index}`}>
                      <Link
                        className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 transition-all duration-200"
                        color={"foreground"}
                        href={item.href}
                        size="lg"
                      >
                        {item.icon && (
                          <span className="text-default-500 flex-shrink-0">
                            {item.icon}
                          </span>
                        )}
                        <span>{item.label}</span>
                      </Link>
                    </NavbarMenuItem>
                  ))}
                </div>
              </div>
            ))}

          {/* Other menu items */}
          <div className="mt-4">
            <h3 className="text-default-500 text-sm font-medium mb-2 px-2">
              Account
            </h3>
            <div className="flex flex-col gap-1">
              {siteConfig.navMenuItems.map((item, index) => (
                <NavbarMenuItem key={`${item.label}-${index}`}>
                  <Link
                    className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 transition-all duration-200"
                    color={
                      index === 2
                        ? "primary"
                        : index === siteConfig.navMenuItems.length - 1
                          ? "danger"
                          : "foreground"
                    }
                    href={item.href}
                    size="lg"
                  >
                    {item.label}
                  </Link>
                </NavbarMenuItem>
              ))}
            </div>
          </div>
        </div>
      </NavbarMenu>
    </HeroUINavbar>
  );
};
