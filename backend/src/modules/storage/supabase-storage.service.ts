import { Injectable, Logger } from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseStorageService {
  private readonly logger = new Logger(SupabaseStorageService.name);
  private readonly supabase: SupabaseClient;
  private readonly bucket: string;
  private readonly baseUrl = process.env.BASE_URL ?? 'http://localhost:3000';

  constructor() {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_KEY;
    this.bucket = process.env.SUPABASE_STORAGE_BUCKET ?? 'attendance';

    if (url && key) {
      this.supabase = createClient(url, key, {
        auth: { persistSession: false },
      });
      this.logger.log(`Supabase Storage inicializado (bucket: ${this.bucket})`);
    } else {
      // Fallback: si no hay credenciales de Supabase, se degrada a disco local
      // para no romper el desarrollo local sin Supabase configurado.
      this.supabase = null as unknown as SupabaseClient;
      this.logger.warn(
        'SUPABASE_URL / SUPABASE_SERVICE_KEY no configurados. Usando fallback a disco local (uploads/).',
      );
    }
  }

  get isEnabled(): boolean {
    return true;
  }

  async uploadPhoto(file: Express.Multer.File, storagePath: string): Promise<string | null> {
    // Fallback a disco local si Supabase no está configurado
    if (!this.supabase) {
      return this._uploadToDisk(file, storagePath);
    }

    try {
      const { error } = await this.supabase.storage
        .from(this.bucket)
        .upload(storagePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (error) {
        this.logger.error(`Error subiendo a Supabase Storage: ${error.message}`);
        return null;
      }

      // Devuelve la URL pública del objeto
      const { data } = this.supabase.storage.from(this.bucket).getPublicUrl(storagePath);
      return data.publicUrl;
    } catch (err) {
      this.logger.error(`Excepción subiendo a Supabase Storage: ${(err as Error).message}`);
      return null;
    }
  }

  async uploadPhotos(files: Express.Multer.File[], prefix: string): Promise<string[]> {
    const urls: string[] = [];
    for (const file of files) {
      const ext = (file.originalname.split('.').pop() ?? 'jpg').toLowerCase();
      const filename = `${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`;
      const url = await this.uploadPhoto(file, `${prefix}/${filename}`);
      if (url) urls.push(url);
    }
    return urls;
  }

  // ── Fallback a disco local (solo desarrollo sin Supabase) ──────────────
  private async _uploadToDisk(file: Express.Multer.File, storagePath: string): Promise<string> {
    const fs = await import('fs');
    const path = await import('path');
    const uploadsDir = path.join(process.cwd(), 'uploads');
    const dest = path.join(uploadsDir, storagePath);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, file.buffer);
    return `${this.baseUrl}/uploads/${storagePath}`;
  }
}
