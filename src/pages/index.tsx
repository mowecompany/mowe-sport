import { Link } from "@heroui/link";
import { button as buttonStyles } from "@heroui/theme";
import { Chip } from "@heroui/chip";

import { siteConfig } from "@/config/site";
import { title, subtitle } from "@/components/primitives";
import { GithubIcon } from "@/components/icons";
import { useAuth } from "@/hooks/useAuth";
import { RoleBasedDashboard } from "@/components/RoleBasedDashboard";
import DefaultLayout from "@/layouts/default";

export default function IndexPage() {
  const { user: currentUser, isLoading } = useAuth();

  if (isLoading) {
    return (
      <DefaultLayout>
        <section className="flex flex-col items-center justify-center gap-4 py-8 md:py-10">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </section>
      </DefaultLayout>
    );
  }

  const userName = currentUser
    ? `${currentUser.first_name || ''} ${currentUser.last_name || ''}`.trim() || 'Usuario'
    : 'Usuario';

  const userRole = currentUser?.primary_role
    ? currentUser.primary_role.replace('_', ' ').toUpperCase()
    : 'USUARIO';

  return (
    <DefaultLayout>
      <section className="flex flex-col items-center justify-center gap-4 py-8 md:py-10">
        <div className="inline-block max-w-xl text-center justify-center">
          <span className={title()}>The best&nbsp;</span>
          <span className={title({ color: "violet" })}>dashboard&nbsp;</span>
          <span className={title()}>
            to manage the tournaments of different sports and categories.
          </span>
          <div className={subtitle({ class: "mt-4" })}>
            Hello {userName} 🫡
          </div>
          <div className="flex items-center gap-2 mt-2">
            <Chip color="primary" variant="flat" size="sm">
              {userRole}
            </Chip>
            {currentUser?.account_status && (
              <Chip
                color={currentUser.account_status === 'active' ? 'success' : 'warning'}
                variant="flat"
                size="sm"
              >
                {currentUser.account_status.toUpperCase()}
              </Chip>
            )}
          </div>
        </div>
        <div className="flex gap-3">
          <Link
            isExternal
            className={buttonStyles({ variant: "bordered", radius: "full" })}
            href={siteConfig.links.github}
          >
            <GithubIcon size={20} />
            GitHub
          </Link>
        </div>

        {/* Role-based dashboard */}
        <RoleBasedDashboard />
      </section>
    </DefaultLayout>
  );
}
