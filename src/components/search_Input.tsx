import { Input } from "@heroui/input";
import { SearchIcon } from "@/components/icons";

const searchInput = (
    <Input
      aria-label="Search"
      classNames={{
        inputWrapper:
          "bg-white/50 dark:bg-black/50 backdrop-blur-xl border border-white/20 dark:border-white/10",
        input: "text-sm",
      }}
      labelPlacement="outside"
      placeholder="Search..."
      startContent={
        <SearchIcon className="text-base text-default-400 pointer-events-none flex-shrink-0" />
      }
      type="search"
    />
);