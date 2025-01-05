# Envanter Yönetim Sistemi

Bu proje, bir depo envanter yönetim sistemidir. Kullanıcıların ürün ekleme, listeleme, güncelleme ve silme gibi işlemleri gerçekleştirmesini sağlar. Ayrıca stok raporları oluşturmak için işlevler sunar. **Zenity** arayüzünü kullanarak kullanıcı dostu bir deneyim sunar.

## Özellikler

- **Dosya Yönetimi**: Gerekli CSV dosyalarını otomatik oluşturur ve güvenlik ayarlarını uygular.
- **Kullanıcı Yönetimi**: Yönetici ve kullanıcı rollerini destekler.
- **Ürün İşlemleri**:
  - Ürün ekleme
  - Ürün listeleme
  - Ürün güncelleme
  - Ürün silme
- **Raporlama**:
  - Stokta azalan ürünler
  - En yüksek stok miktarına sahip ürünler
- **Güvenlik**:
  - Dosya kilitleme mekanizması
  - Maksimum giriş denemesi sınırı
  - Şifreler MD5 hash ile saklanır

## Gereksinimler

- **Linux** veya **Unix** tabanlı bir işletim sistemi
- **Bash Shell**
- **Zenity** (Grafiksel arayüz için)

Zenity'i kurmak için aşağıdaki komutu kullanabilirsiniz:

```bash
sudo apt-get install zenity  # Debian/Ubuntu tabanlı sistemler için

