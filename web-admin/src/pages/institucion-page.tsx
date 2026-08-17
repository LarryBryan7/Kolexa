import { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { FormField } from '@/components/form-field';
import { useToast } from '@/components/ui/toast';
import { useSchool, useUpdateSchool } from '@/hooks/use-school';

const schoolSchema = z.object({
  name: z.string().min(1, 'El nombre es obligatorio'),
  tradeName: z.string().optional().nullable(),
  ruc: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  email: z.string().email('Correo inválido').optional().nullable().or(z.literal('')),
  logoUrl: z.string().optional().nullable(),
  address: z.string().optional().nullable(),
});

type SchoolForm = z.infer<typeof schoolSchema>;

export function InstitucionPage() {
  const { data: school, isLoading, error, refetch } = useSchool();
  const updateSchool = useUpdateSchool();
  const { toast } = useToast();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<SchoolForm>({
    resolver: zodResolver(schoolSchema),
  });

  // Cargar los datos del colegio en el formulario cuando llegan
  useEffect(() => {
    if (school) {
      reset({
        name: school.name ?? '',
        tradeName: school.tradeName ?? '',
        ruc: school.ruc ?? '',
        phone: school.phone ?? '',
        email: school.email ?? '',
        logoUrl: school.logoUrl ?? '',
        address: school.address ?? '',
      });
    }
  }, [school, reset]);

  if (isLoading) return <LoadingState label="Cargando institución…" />;
  if (error) {
    return (
      <ErrorState
        title="No se pudo cargar la institución"
        message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
        onRetry={() => refetch()}
      />
    );
  }

  const onSubmit = async (values: SchoolForm) => {
    try {
      await updateSchool.mutateAsync(values);
      toast({ title: 'Institución actualizada', variant: 'success' });
    } catch (err) {
      toast({
        title: 'No se pudo actualizar',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Institución"
        description="Datos generales de tu institución educativa."
      />

      <Card>
        <CardHeader>
          <CardTitle>Información general</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <FormField label="Nombre" htmlFor="name" required error={errors.name?.message}>
                <Input id="name" placeholder="Nombre de la institución" {...register('name')} />
              </FormField>

              <FormField label="Nombre comercial" htmlFor="tradeName" error={errors.tradeName?.message}>
                <Input id="tradeName" placeholder="Nombre comercial" {...register('tradeName')} />
              </FormField>

              <FormField label="RUC" htmlFor="ruc" error={errors.ruc?.message}>
                <Input id="ruc" placeholder="RUC" {...register('ruc')} />
              </FormField>

              <FormField label="Teléfono" htmlFor="phone" error={errors.phone?.message}>
                <Input id="phone" placeholder="Teléfono" {...register('phone')} />
              </FormField>

              <FormField label="Correo" htmlFor="email" error={errors.email?.message}>
                <Input id="email" type="email" placeholder="correo@colegio.edu.pe" {...register('email')} />
              </FormField>

              <FormField label="URL del logo" htmlFor="logoUrl" error={errors.logoUrl?.message}>
                <Input id="logoUrl" placeholder="https://…" {...register('logoUrl')} />
              </FormField>
            </div>

            <FormField label="Dirección" htmlFor="address" error={errors.address?.message}>
              <Input id="address" placeholder="Dirección" {...register('address')} />
            </FormField>

            <div className="flex justify-end">
              <Button type="submit" disabled={!isDirty || updateSchool.isPending}>
                {updateSchool.isPending ? 'Guardando…' : 'Guardar cambios'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
