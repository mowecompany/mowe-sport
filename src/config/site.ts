import React from "react";

import {
  DashboardIcon,
  SportsIcon,
  TeamsIcon,
  AdminIcon,
  PlayersIcon,
  UsersIcon,
} from "@/components/icons";

import type { UserRole } from "@/services/types";

export interface NavItem {
  label: string;
  href: string;
  description?: string;
  icon?: React.ReactNode;
  items?: NavItem[];
  allowedRoles?: UserRole[];
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
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
        },
        {
          label: "Sports",
          href: "/main/sports",
          icon: React.createElement(SportsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
        },
        {
          label: "Tournaments",
          href: "/main/tournaments",
          icon: React.createElement(SportsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
        },
        {
          label: "Teams",
          href: "/main/teams",
          icon: React.createElement(TeamsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client'],
        },
        {
          label: "Calendar",
          href: "/main/calendar",
          icon: React.createElement(TeamsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
        },
        {
          label: "Matches",
          href: "/main/matches",
          icon: React.createElement(TeamsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
        },
        {
          label: "Statistics",
          href: "/main/statistics",
          icon: React.createElement(TeamsIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client'],
        },
      ],
    },
    {
      label: "Administration",
      href: "#",
      items: [
        {
          label: "Super Admin",
          href: "/administration/super_admin",
          icon: React.createElement(AdminIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin'],
        },
        {
          label: "Admin",
          href: "/administration/admins",
          icon: React.createElement(AdminIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin'],
        },
        {
          label: "Players",
          href: "/administration/players",
          icon: React.createElement(PlayersIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'owner', 'coach'],
        },
        {
          label: "Referees",
          href: "/administration/referees",
          icon: React.createElement(PlayersIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin'],
        },
        {
          label: "Users",
          href: "/administration/users",
          icon: React.createElement(UsersIcon, { className: "w-4 h-4" }),
          allowedRoles: ['super_admin', 'city_admin', 'owner'],
        },
      ],
    },
  ],
  navMenuItems: [
    {
      label: "Profile",
      href: "/profile",
      allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client'],
    },
    {
      label: "Settings",
      href: "/settings",
      allowedRoles: ['super_admin', 'city_admin', 'tournament_admin', 'owner'],
    },
  ],
  links: {
    github: "https://github.com/mowecompany",
  },
};
