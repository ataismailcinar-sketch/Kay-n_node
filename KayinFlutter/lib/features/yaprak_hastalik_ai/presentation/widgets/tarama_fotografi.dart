import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/sunucu_adresi.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/hastalik_tarama_entity.dart';

/// Taramanın küçük fotoğrafı: cihazda varsa dosyadan, yoksa (başka cihazda çekilmiş)
/// sunucudan; ikisi de yoksa aciliyet simgesi.
class TaramaFotografi extends StatelessWidget {
  final HastalikTaramaEntity tarama;
  final double boyut;

  const TaramaFotografi({super.key, required this.tarama, this.boyut = 52});

  @override
  Widget build(BuildContext context) {
    final kritik = tarama.aciliyetSeviyesi == 'Kritik';
    final renk = kritik ? Colors.red : Colors.green;

    final simge = CircleAvatar(
      radius: boyut / 2,
      backgroundColor: renk.withValues(alpha: 0.2),
      child: Icon(kritik ? Icons.warning_rounded : Icons.verified_rounded, color: renk),
    );

    Widget? resim;
    final yerel = tarama.fotografYerelYolu;
    if (yerel.isNotEmpty && File(yerel).existsSync()) {
      resim = Image.file(File(yerel), fit: BoxFit.cover, cacheWidth: (boyut * 3).round());
    } else if (tarama.fotografSunucuda && ApiClient().token != null) {
      resim = Image.network(
        '${SunucuAdresi.api}/hastaliktarama/${tarama.id}/fotograf',
        headers: {'Authorization': 'Bearer ${ApiClient().token}'},
        fit: BoxFit.cover,
        cacheWidth: (boyut * 3).round(),
        errorBuilder: (_, __, ___) => simge, // çevrimdışı → simge
      );
    }
    if (resim == null) return simge;

    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: resim,
    );
  }
}
