import { useAuth } from '@/contexts/auth-context';

export function Header() {
  const { user } = useAuth();
  const schoolName = user?.roles?.find((r) => r.schoolName)?.schoolName;

  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b bg-white px-6">
      <div>
        <p className="text-sm text-muted-foreground">Panel de administración</p>
        {schoolName && <p className="text-sm font-semibold text-foreground">{schoolName}</p>}
      </div>
      <div className="flex items-center gap-3">
        <span className="text-sm text-muted-foreground">
          {new Date().toLocaleDateString('es-PE', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          })}
        </span>
      </div>
    </header>
  );
}
