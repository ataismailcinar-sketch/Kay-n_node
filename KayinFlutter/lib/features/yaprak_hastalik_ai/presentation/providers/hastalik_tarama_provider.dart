import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/fotograf_meta_temizleyici.dart';
import '../../data/models/hastalik_tarama_model.dart';
import '../../domain/entities/hastalik_tarama_entity.dart';
import '../../domain/usecases/tflite_leaf_analyzer_usecase.dart';
import '../../domain/zirai_recete_engine.dart';

final tfliteAnalyzerProvider = Provider((_) => TfliteLeafAnalyzerUseCase());

/// Ekranda "model yüklü / değil" rozetini göstermek için.
final yaprakModelHazirProvider = FutureProvider<bool>((ref) => ref.read(tfliteAnalyzerProvider).modelHazirMi());

final hastalikTaramaListeProvider = AsyncNotifierProvider<HastalikTaramaListeNotifier, List<HastalikTaramaEntity>>(
    HastalikTaramaListeNotifier.new);

class HastalikTaramaListeNotifier extends AsyncNotifier<List<HastalikTaramaEntity>> {
  @override
  Future<List<HastalikTaramaEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      DatabaseHelper.tableHastalikTarama,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'tarama_tarihi DESC',
      limit: 50,
    );
    return rows.map<HastalikTaramaEntity>(HastalikTaramaModel.fromRow).toList();
  }

  Future<String?> _parselUrunu(String? parselId) async {
    if (parselId == null) return null;
    final db = await DatabaseHelper().database;
    final pRows = await db.query(
      DatabaseHelper.tableParseller,
      columns: ['ekilmis_urun'],
      where: 'id = ?',
      whereArgs: [parselId],
    );
    return pRows.isEmpty ? null : pRows.first['ekilmis_urun'] as String?;
  }

  /// Fotoğrafı modelle analiz eder. Yalnızca güvenilir bir teşhis varsa kaydeder;
  /// belirsiz / model yok durumlarında `kayit` null döner ve ekran kullanıcıya sorar.
  Future<({LeafAnalysisResult sonuc, HastalikTaramaEntity? kayit, String? parselUrunu})> fotoAnalizEt(
      String fotoYolu, {String? parselId}) async {
    final urun = await _parselUrunu(parselId);
    final sonuc = await ref.read(tfliteAnalyzerProvider).analyzeImage(fotoYolu, ekilmisUrun: urun);
    if (!sonuc.kaydedilebilir) {
      return (sonuc: sonuc, kayit: null, parselUrunu: urun);
    }
    final kayit = await _kaydet(
      fotoYolu: fotoYolu,
      parselId: parselId,
      teshisAdi: sonuc.teshisAdi!,
      guvenYuzdesi: sonuc.guvenYuzdesi,
      aciliyet: sonuc.aciliyetSeviyesi,
      olasiliklarJson: sonuc.olasiliklarJson,
      modelVersionu: sonuc.modelVersionu,
    );
    return (sonuc: sonuc, kayit: kayit, parselUrunu: urun);
  }

  /// Kullanıcının listeden seçtiği teşhisi kaydeder (model kullanılmadı).
  Future<HastalikTaramaEntity> manuelKaydet({
    required String fotoYolu,
    String? parselId,
    required ZiraiRecete recete,
  }) {
    final saglikli = recete.hastalikAdi.contains('Sağlıklı');
    return _kaydet(
      fotoYolu: fotoYolu,
      parselId: parselId,
      teshisAdi: recete.hastalikAdi,
      guvenYuzdesi: 0,
      aciliyet: TfliteLeafAnalyzerUseCase.aciliyetHesapla(saglikli: saglikli, recete: recete),
      olasiliklarJson: '[]',
      modelVersionu: HastalikTaramaEntity.manuelModelVersiyonu,
    );
  }

  Future<HastalikTaramaEntity> _kaydet({
    required String fotoYolu,
    String? parselId,
    required String teshisAdi,
    required double guvenYuzdesi,
    required String aciliyet,
    required String olasiliklarJson,
    required String modelVersionu,
  }) async {
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    final entity = HastalikTaramaEntity(
      id: id,
      parselId: parselId,
      taramaTarihi: now,
      teshisAdi: teshisAdi,
      guvenYuzdesi: guvenYuzdesi,
      tumSinifOlasiliklariJson: olasiliklarJson,
      fotografYerelYolu: await _kaliciKopya(fotoYolu, id),
      modelVersionu: modelVersionu,
      aciliyetSeviyesi: aciliyet,
      cevrimdisiAnalizYapildi: true,
      createdAtUtc: now,
      lastModifiedUtc: now,
      isSynced: false, // Save to SQLite with IsSynced=0 for background push
    );

    await DatabaseHelper().upsert(
      DatabaseHelper.tableHastalikTarama,
      HastalikTaramaModel.toRow(entity),
    );

    ref.invalidateSelf();
    return entity;
  }

  /// image_picker fotoğrafı önbellek klasörüne koyar; işletim sistemi orayı temizleyebilir.
  /// Geçmişte göstermek ve sunucuya yüklemek için uygulamanın kalıcı klasörüne kopyalanır.
  /// Kopyalanırken konum (GPS), telefon modeli gibi EXIF bilgileri silinir: fotoğraf sunucuya gidiyor.
  /// Kopyalanamazsa (ör. yer yok) özgün yol kullanılır.
  static Future<String> _kaliciKopya(String kaynak, String taramaId) async {
    try {
      final klasor = Directory(p.join((await getApplicationSupportDirectory()).path, 'tarama_fotograflari'));
      await klasor.create(recursive: true);
      final uzanti = p.extension(kaynak).isEmpty ? '.jpg' : p.extension(kaynak);
      final hedef = File(p.join(klasor.path, '$taramaId$uzanti'));
      await hedef.writeAsBytes(fotografMetaTemizle(await File(kaynak).readAsBytes()), flush: true);
      return hedef.path;
    } catch (_) {
      return kaynak;
    }
  }
}
