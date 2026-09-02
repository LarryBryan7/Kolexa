// ============================================================
// cached_avatar.dart — Cache real para fotos de perfil/avatares
// ============================================================
// Los avatares (hijo, contacto, participante de un chat) vienen del
// backend como URLs FIRMADAS de Supabase Storage: el path del archivo es
// estable, pero el token/expiry en el query string cambia cada vez que
// el backend la vuelve a firmar (getHomeData, /parent/home, getContacts,
// etc.) — incluso si la foto en sí no cambió.
//
// `Image.network`/`NetworkImage` cachean en memoria usando la URL
// COMPLETA como clave, así que cada resign se ve como una imagen nueva y
// se vuelve a descargar — la app tiene `cached_network_image` como
// dependencia (cache en disco, no solo memoria) pero casi no se usaba.
// Estas dos funciones lo aplican con una `cacheKey` basada solo en el
// path (sin el query string), para que el mismo archivo se reconozca
// como cacheado sin importar cuántas veces se haya vuelto a firmar.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

// Para usar como `backgroundImage` de un CircleAvatar (o cualquier lugar
// que pida un ImageProvider en vez de un widget).
ImageProvider cachedAvatarProvider(String url) =>
    CachedNetworkImageProvider(url, cacheKey: _stableCacheKey(url));

// Para usar como widget de imagen directo (en vez de Image.network),
// cuando hace falta placeholder/errorWidget propios.
Widget cachedAvatarImage(
  String url, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, String)? placeholder,
  required Widget Function(BuildContext, String, Object) errorWidget,
}) {
  return CachedNetworkImage(
    imageUrl: url,
    cacheKey: _stableCacheKey(url),
    width: width,
    height: height,
    fit: fit,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}

String _stableCacheKey(String url) {
  final uri = Uri.tryParse(url);
  // Si no se puede parsear (no debería pasar), se usa la URL completa —
  // peor que el fix pero nunca rompe.
  return uri?.path.isNotEmpty == true ? uri!.path : url;
}
