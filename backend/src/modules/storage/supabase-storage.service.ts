import { Injectable, Logger } from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import * as crypto from 'crypto';

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

  // Devuelve el storagePath del objeto subido (NO una URL pública/firmada).
  // El bucket es privado: la URL servible se genera aparte, al leer, con
  // getSignedUrls(). Guardar el path (no la URL) es lo que permite firmar
  // con una vigencia distinta cada vez que se lee.
  async uploadPhoto(file: Express.Multer.File, storagePath: string): Promise<string | null> {
    // Fallback a disco local si Supabase no está configurado
    if (!this.supabase) {
      await this._uploadToDisk(file, storagePath);
      return storagePath;
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

      return storagePath;
    } catch (err) {
      this.logger.error(`Excepción subiendo a Supabase Storage: ${(err as Error).message}`);
      return null;
    }
  }

  async uploadPhotos(files: Express.Multer.File[], prefix: string): Promise<string[]> {
    const paths: string[] = [];
    for (const file of files) {
      const ext = (file.originalname.split('.').pop() ?? 'jpg').toLowerCase();
      const filename = `${crypto.randomBytes(16).toString('hex')}.${ext}`;
      const path = await this.uploadPhoto(file, `${prefix}/${filename}`);
      if (path) paths.push(path);
    }
    return paths;
  }

  // Convierte storagePaths guardados en URLs firmadas de lectura, de vigencia
  // corta. Firma en lote (una sola llamada) en vez de una por foto.
  async getSignedUrls(paths: string[], expiresInSeconds = 3600): Promise<string[]> {
    if (paths.length === 0) return [];

    // Fallback disco local: no hay bucket que firmar, se sirve directo
    // por la ruta estática /uploads/ que ya expone el servidor.
    if (!this.supabase) {
      return paths.map((p) => `${this.baseUrl}/uploads/${p}`);
    }

    const { data, error } = await this.supabase.storage
      .from(this.bucket)
      .createSignedUrls(paths, expiresInSeconds);

    if (error) {
      this.logger.error(`Error firmando URLs de Supabase Storage: ${error.message}`);
      return [];
    }

    return data.map((d) => d.signedUrl ?? '').filter((url) => url !== '');
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
