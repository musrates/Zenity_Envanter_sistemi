# Envanter Yönetim Sistemi

Bu proje, bir depo envanter yönetim sistemidir. Kullanıcıların ürün ekleme, listeleme, güncelleme ve silme gibi temel envanter işlemlerini yapmasını sağlar. Ayrıca stok raporları oluşturmak için çeşitli işlevler sunar. Grafiksel arayüz desteği **Zenity** aracılığıyla sağlanmaktadır.

## Özellikler

- **Dosya Yönetimi**: Gerekli CSV dosyaları otomatik olarak oluşturulur ve izinleri düzenlenir.
- **Kullanıcı Yönetimi**:
  - Yönetici ve standart kullanıcı rolleri
  - Maksimum giriş denemesi sınırı
  - MD5 ile şifreleme
- **Ürün Yönetimi**:
  - Yeni ürün ekleme
  - Ürün listeleme
  - Ürün güncelleme
  - Ürün silme
- **Raporlama**:
  - Stokta azalan ürünler
  - En yüksek stok miktarına sahip ürünler

## Gereksinimler

Bu scripti çalıştırmak için şu gereksinimler karşılanmalıdır:

- **Linux** veya **Unix** tabanlı bir işletim sistemi
- **Bash Shell**
- **Zenity** (Grafiksel arayüz için gerekli bir aracı)

Zenity'yi kurmak için aşağıdaki komutu kullanabilirsiniz:

```bash
sudo apt-get install zenity
```

## Kurulum

1. Proje dosyalarını bilgisayarınıza indirin.
2. `envanter_yonetimi.sh` dosyasına çalıştırma izni verin:

   ```bash
   chmod +x envanter_yonetimi.sh
   ```

3. Script'i aşağıdaki gibi çalıştırın:

   ```bash
   ./envanter_yonetimi.sh
   ```

## Kullanım

1. Giriş yapın. Varsayılan yönetici bilgileriniz:
   - Kullanıcı Adı: `admin`
   - Şifre: `admin`
2. Ana menüyü kullanarak çeşitli işlemleri yürütebilirsiniz.

### Ana Menü Seçenekleri

- **Ürün Ekle**: Yeni bir ürün ekler.
- **Ürün Listele**: Tüm depodaki ürünleri listeler.
- **Ürün Güncelle**: Mevcut bir ürünün bilgilerini günceller.
- **Ürün Sil**: Depodan bir ürünün kaydını siler.
- **Rapor Al**: Stok raporları almanızı sağlar.

## Dosyalar

- `depo.csv`: Ürün bilgilerinin saklandığı dosya.
- `kullanici.csv`: Kullanıcı bilgilerinin saklandığı dosya.
- `log.csv`: Sistem loglarının kaydedildiği dosya.
- `kategori.csv`: Ürün kategorilerinin saklandığı dosya.

## Sorun Giderme

- **Zenity eksikse**: `sudo apt-get install zenity` komutuyla Zenity'yi kurun.
- **Dosyalar eksikse**: Script, ilk çalıştırıldığında gerekli dosyaları otomatik olarak oluşturur.
- **Giriş yapamıyorsanız**: Kullanıcı bilgilerinin doğruluğunu kontrol edin veya sistem yöneticisi ile iletişime geçin.

## Lisans

Bu proje, [MIT Lisansı](LICENSE) ile lisanslanmıştır.

