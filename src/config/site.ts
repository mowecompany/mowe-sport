import React from "react";

import {
  DashboardIcon,
  SportsIcon,
  TeamsIcon,
  AdminIcon,
  PlayersIcon,
  UsersIcon,
} from "@/components/icons";

export interface NavItem {
  label: string;
  href: string;
  description?: string;
  icon?: React.ReactNode;
  items?: NavItem[];
}

export interface SiteConfig {
  name: string;
  description: string;
  navItems: NavItem[];
  navMenuItems: NavItem[];
  links: {
    github: string;
  };
}

export const siteConfig: SiteConfig = {
  name: "Mowe Sport",
  description:
    "Tournament administration websites for different sports tournaments",
  navItems: [
    {
      label: "Main",
      href: "#",
      items: [
        {
          label: "Dashboard",
          href: "/dashboard",
          icon: React.createElement(DashboardIcon, { className: "w-4 h-4" }),
        },
        {
          label: "Sports",
          href: "/main/sports",
          icon: React.createElement(SportsIcon, { className: "w-4 h-4" }),
        },
        {
          label: "Teams",
          href: "/main/teams",
          icon: React.createElement(TeamsIcon, { className: "w-4 h-4" }),
        },
      ],
    },
    {
      label: "Administration",
      href: "#",
      items: [
        {
          label: "Admin",
          href: "/administration/admins",
          icon: React.createElement(AdminIcon, { className: "w-4 h-4" }),
        },
        {
          label: "Players",
          href: "/administration/players",
          icon: React.createElement(PlayersIcon, { className: "w-4 h-4" }),
        },
        {
          label: "Users",
          href: "/administration/users",
          icon: React.createElement(UsersIcon, { className: "w-4 h-4" }),
        },
      ],
    },
  ],
  navMenuItems: [
    {
      label: "Profile",
      href: "/profile",
    },
    {
      label: "Settings",
      href: "/settings",
    },
  ],
  links: {
    github: "https://github.com/mowecompany",
  },
};
