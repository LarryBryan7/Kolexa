import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  School,
  DoorOpen,
  BookOpen,
  Users,
  GraduationCap,
  Contact,
  Upload,
  LogOut,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/auth-context';
import { Button } from '@/components/ui/button';
import { KolexaLogo } from '@/components/kolexa-logo';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/institucion', label: 'Institución', icon: School, end: false },
  { to: '/aulas', label: 'Aulas', icon: DoorOpen, end: false },
  { to: '/cursos', label: 'Cursos', icon: BookOpen, end: false },
  { to: '/usuarios', label: 'Usuarios', icon: Users, end: false },
  { to: '/alumnos', label: 'Alumnos', icon: GraduationCap, end: false },
  { to: '/padres', label: 'Padres', icon: Contact, end: false },
  { to: '/importar', label: 'Importar', icon: Upload, end: false },
];

export function Sidebar() {
  const { user, logout } = useAuth();

  return (
    <aside className="flex h-full w-60 flex-col border-r bg-white">
      {/* Logo */}
      <div className="flex h-16 items-center gap-3 border-b px-5">
        <div className="kolexa-logo" aria-hidden="true">
          <KolexaLogo className="h-5 w-5" />
        </div>
        <div>
          <p className="text-base font-bold leading-tight text-foreground">KOLEXA</p>
          <p className="text-xs text-muted-foreground">Admin</p>
        </div>
      </div>

      {/* Navegación */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Navegación principal">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-brand-soft text-brand-dark'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground',
              )
            }
          >
            <item.icon className="h-4 w-4 shrink-0" aria-hidden="true" />
            {item.label}
          </NavLink>
        ))}
      </nav>

      {/* Usuario + logout */}
      <div className="border-t p-3">
        <div className="mb-2 flex items-center gap-3 px-2">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand text-sm font-semibold text-white">
            {user?.firstName?.[0]?.toUpperCase() ?? 'A'}
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-foreground">
              {user?.firstName} {user?.lastName}
            </p>
            <p className="truncate text-xs text-muted-foreground">{user?.email}</p>
          </div>
        </div>
        <Button variant="ghost" className="w-full justify-start text-muted-foreground" onClick={logout}>
          <LogOut className="h-4 w-4" aria-hidden="true" />
          Cerrar sesión
        </Button>
      </div>
    </aside>
  );
}
