import 'package:flutter/material.dart';
import '../../../../core/services/rapor_ocr_servisi.dart';
import '../../../toprak_analizi/domain/rapor_okuyucu.dart';
import '../../domain/sulama.dart';

/// "Sulu / Kuru" seçimi; sulu seçilince sulama yöntemi ve su kaynağı da sorulur.
/// [deger] null ise ikisi de seçili değildir (belirtilmedi).
class SuluSecici extends StatelessWidget {
  final bool? deger;
  final ValueChanged<bool> degisti;
  final SulamaYontemi? yontem;
  final ValueChanged<SulamaYontemi>? yontemDegisti;
  final SuKaynagi? kaynak;
  final ValueChanged<SuKaynagi>? kaynakDegisti;

  /// Sulama suyunun tuzluluğu (dS/m). Boş bırakılırsa null bildirilir.
  final double? suEc;
  final ValueChanged<double?>? suEcDegisti;

  const SuluSecici({
    super.key,
    required this.deger,
    required this.degisti,
    this.yontem,
    this.yontemDegisti,
    this.kaynak,
    this.kaynakDegisti,
    this.suEc,
    this.suEcDegisti,
  });

  static String _yaz(double v) {
    var s = v.toStringAsFixed(2);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s.replaceAll('.', ',');
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.water_drop_rounded, size: 18),
              label: const Text('Sulu (sulama var)'),
              selected: deger == true,
              selectedColor: Colors.lightBlue[300],
              onSelected: (_) => degisti(true),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.wb_sunny_rounded, size: 18),
              label: const Text('Kuru (yalnız yağmur)'),
              selected: deger == false,
              selectedColor: Colors.amber[300],
              onSelected: (_) => degisti(false),
            ),
          ],
        ),
        if (deger == true && yontemDegisti != null) ...[
          const SizedBox(height: 10),
          const Text('Sulama yöntemi:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final y in SulamaYontemi.values)
                ChoiceChip(
                  avatar: Icon(y.ikon, size: 18),
                  label: Text(y.ad),
                  selected: yontem == y,
                  selectedColor: Colors.lightBlue[200],
                  onSelected: (_) => yontemDegisti!(y),
                ),
            ],
          ),
        ],
        if (deger == true && kaynakDegisti != null) ...[
          const SizedBox(height: 10),
          const Text('Su kaynağı:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in SuKaynagi.values)
                ChoiceChip(
                  label: Text(k.ad),
                  selected: kaynak == k,
                  selectedColor: Colors.lightBlue[200],
                  onSelected: (_) => kaynakDegisti!(k),
                ),
            ],
          ),
        ],
        if (deger == true && suEcDegisti != null) ...[
          const SizedBox(height: 12),
          _SuEcAlani(ilk: suEc, degisti: suEcDegisti!),
        ],
      ],
    );
  }
}


/// EC girişi: µS/cm yazılırsa dS/m karşılığını ve su sınıfını anında gösterir.
class _SuEcAlani extends StatefulWidget {
  final double? ilk;
  final ValueChanged<double?> degisti;
  const _SuEcAlani({required this.ilk, required this.degisti});

  @override
  State<_SuEcAlani> createState() => _SuEcAlaniState();
}

class _SuEcAlaniState extends State<_SuEcAlani> {
  late double? _deger = widget.ilk;
  late final _c = TextEditingController(text: widget.ilk == null ? '' : SuluSecici._yaz(widget.ilk!));
  bool _okundu = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _yaz(String s, {bool okundu = false}) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    setState(() {
      _okundu = okundu;
      _deger = v == null || v < 0 ? null : suEcDuzelt(v);
    });
    widget.degisti(_deger);
  }

  Future<void> _fotograftanOku() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sonuc = await RaporOcrServisi.raporOku(context);
      if (sonuc == null || !mounted) return;
      final ec = sonuc[RaporAlani.ec];
      if (ec == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Fotoğrafta EC değeri bulunamadı; elle girin.')));
        return;
      }
      _c.text = SuluSecici._yaz(ec);
      _yaz(_c.text, okundu: true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Rapor okunamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ham = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    final cevrildi = ham != null && ham > 20;
    final ipucu = _deger == null
        ? 'Raporda µS/cm yazıyorsa olduğu gibi girin (ör. 850).'
        : '${_okundu ? '📷 Fotoğraftan okundu, kontrol edin • ' : ''}'
            '${cevrildi ? '= ${SuluSecici._yaz(_deger!)} dS/m • ' : ''}${SuTuzSinifi.icin(_deger!).ad}';
    return TextField(
      controller: _c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Suyun tuzluluğu (EC) — su analizi varsa',
        suffixText: cevrildi ? 'µS/cm' : 'dS/m',
        suffixIcon: RaporOcrServisi.destekleniyor
            ? IconButton(
                tooltip: 'Su analizi fotoğrafından oku',
                onPressed: _fotograftanOku,
                icon: const Icon(Icons.document_scanner_rounded),
              )
            : null,
        helperText: ipucu,
        helperStyle: _okundu ? const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: _yaz,
    );
  }
}