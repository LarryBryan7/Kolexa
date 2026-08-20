import { useState } from 'react';
import { useNavigate, useLocation, Navigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useAuth } from '@/contexts/auth-context';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { FormField } from '@/components/form-field';
import { useToast } from '@/components/ui/toast';
import { KolexaLogo } from '@/components/kolexa-logo';

const loginSchema = z.object({
  email: z.string().email('Ingresa un correo válido'),
  password: z.string().min(6, 'La contraseña debe tener al menos 6 caracteres'),
});

type LoginForm = z.infer<typeof loginSchema>;

export function LoginPage() {
  const { login, logout, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { toast } = useToast();
  const [submitting, setSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const onSubmit = async (values: LoginForm) => {
    setSubmitting(true);
    try {
      const user = await login(values.email, values.password);
      const hasAdminRole = user.roles?.some((r) => r.role === 'school_admin');
      if (!hasAdminRole) {
        // Hallazgo IM-9: login() ya guardó el token y marcó
        // isAuthenticated=true — sin este logout(), el usuario quedaba con
        // sesión completa y navegación libre por todo el layout admin
        // (aunque cada llamada real a datos recibiera 403 del backend).
        // logout() limpia token+user y deja el estado no autenticado.
        logout();
        toast({
          title: 'Acceso restringido',
          description: 'Esta cuenta no tiene permisos de administrador de institución.',
          variant: 'error',
        });
        return;
      }
      const from = (location.state as { from?: string } | null)?.from ?? '/';
      navigate(from, { replace: true });
    } catch (err) {
      toast({
        title: 'No se pudo iniciar sesión',
        description: err instanceof Error ? err.message : 'Verifica tus credenciales.',
        variant: 'error',
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center px-4" style={{ backgroundColor: '#F7F6F3' }}>
      <div className="w-full max-w-md">
        <div className="mb-8 flex flex-col items-center text-center">
          <div
            className="mb-6 flex h-[72px] w-[72px] items-center justify-center rounded-full bg-brand"
            aria-hidden="true"
          >
            <KolexaLogo className="h-9 w-9 text-brand-icon" />
          </div>
          <h1 className="text-[28px] font-bold text-foreground">Kolexa Admin</h1>
          <p className="mt-1 text-[15px] text-muted-foreground">
            Ingresa a tu panel de gestión
          </p>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
          <FormField label="Correo electrónico" htmlFor="email" required error={errors.email?.message}>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              placeholder="admin@colegio.edu.pe"
              className="h-11"
              {...register('email')}
            />
          </FormField>

          <FormField
            label="Contraseña"
            htmlFor="password"
            required
            error={errors.password?.message}
          >
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              placeholder="••••••••"
              className="h-11"
              {...register('password')}
            />
          </FormField>

          <Button type="submit" className="h-12 w-full text-[15px]" disabled={submitting}>
            {submitting ? 'Ingresando…' : 'Ingresar'}
          </Button>

          <div className="pt-1 text-center">
            <button
              type="button"
              className="text-sm text-muted-foreground hover:text-brand hover:underline"
            >
              ¿Olvidaste tu contraseña?
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
