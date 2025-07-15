export type SiteConfig = typeof siteConfig;

export const siteConfig = {
  name: "Mowe Sport",
  description: "Tournament administration websites for different sports tournaments",
  navItems: [
    {
      label: "Dashboard",
      href: "/",
    },
    {
      label: "Main",
      href: "/docs",
    },
    {
      label: "Administration",
      href: "/pricing",
    }
  ],
  navMenuItems: [
    {
      label: "Profile",
      href: "/profile",
    },
    {
      label: "Dashboard",
      href: "/dashboard",
    },
    {
      label: "Calendar",
      href: "/calendar",
    },
    {
      label: "Settings",
      href: "/settings",
    }
  ],
  links: {
    github: "https://github.com/mowecompany",
  },
};
