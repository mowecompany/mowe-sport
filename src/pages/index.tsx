import { Link } from "@heroui/link";
import { button as buttonStyles } from "@heroui/theme";

import { siteConfig } from "@/config/site";
import { title, subtitle } from "@/components/primitives";
import { GithubIcon } from "@/components/icons";
import { useAuth } from "@/hooks/useAuth";
import DefaultLayout from "@/layouts/default";

export default function IndexPage() {
  const { user: currentUser } = useAuth();
  const userName = currentUser 
    ? `${currentUser.first_name || ''} ${currentUser.last_name || ''}`.trim() || 'Usuario'
    : 'Usuario';

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
      </section>
    </DefaultLayout>
  );
}
