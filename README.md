# Zenity Envanter Sistemi

![Proje Başlığı](./screenshots/project_title.png)

Zenity Envanter Sistemi, *Zenity* kullanarak geliştirilen basit ve etkili bir envanter yönetim aracıdır. Kullanıcı dostu grafik arayüzü sayesinde, ürün ekleme, güncelleme, silme ve raporlama işlemlerini kolayca gerçekleştirmenizi sağlar. Ayrıca, kullanıcı yönetimi ve program yönetimi özellikleri ile sisteminizi daha güvenli ve işlevsel hale getirir.

## İçindekiler

- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
  - [Giriş](#giriş)
  - [Yönetici Menüsü](#yönetici-menüsü)
  - [Kullanıcı Menüsü](#kullanıcı-menüsü)
- [Raporlar](#raporlar)
- [Program Yönetimi](#program-yönetimi)
- [Hata Kayıtları](#hata-kayıtları)
- [Katkıda Bulunanlar](#katkıda-bulunanlar)
- [Lisans](#lisans)
- [Kaynakça](#kaynakça)
- [Video Demo](#video-demo)
- [Değerlendirme Soruları](#değerlendirme-soruları)

## Özellikler

- *Ürün Yönetimi:*
  - Yeni ürün ekleme, listeleme, güncelleme ve silme işlemleri.
  - Ürün adı ve kategori doğrulama.
  - Eşsiz ürün isimleri zorunluluğu.

- *Kullanıcı Yönetimi:*
  - Yeni kullanıcı ekleme, listeleme, güncelleme ve silme işlemleri.
  - Yönetici hesabının kilitlenmesi ve kilit açma yetkisi.

- *Raporlama:*
  - Stokta azalan ürünler raporu.
  - En yüksek stok miktarına sahip ürünler raporu.

- *Program Yönetimi:*
  - Diskteki alanı gösterme.
  - Verileri diske yedekleme.
  - Hata kayıtlarını görüntüleme.

- *Güvenlik:*
  - Şifreler MD5 ile hashlenmiştir.
  - 3 hatalı giriş sonrası hesap kilitleme.

## Gereksinimler

- *İşletim Sistemi:* Linux (Ubuntu önerilir)
- *Zenity:* Grafik arayüz oluşturmak için gerekli. Yüklü değilse aşağıdaki komutla yükleyebilirsiniz:
  bash
  sudo apt-get update
  sudo apt-get install zenity
  
- *Bash:* Bash betiği olarak yazılmıştır, genellikle Linux dağıtımlarında varsayılan olarak bulunur.

## Kurulum

Zenity Envanter Sistemi'ni kendi bilgisayarınızda çalıştırmak için aşağıdaki adımları takip edebilirsiniz:

### Adımlar

1. *Repoyu Klonlayın:*
   bash
   git clone https://github.com/musrates/Zenity_Envanter_sistemi.git
   cd Zenity_Envanter_sistemi
   

2. *Betik Dosyasını Yapılandırın:*
   - envanter_yonetimi.sh dosyasının çalıştırılabilir olduğundan emin olun:
     bash
     chmod +x envanter_yonetimi.sh
     

3. *İlk Kurulum:*
   - Betiği ilk kez çalıştırdığınızda, gerekli CSV dosyaları (depo.csv, kullanici.csv, log.csv) otomatik olarak oluşturulacaktır.
   - Varsayılan yönetici hesabı:
     - *Kullanıcı Adı:* admin
     - *Parola:* admin123

## Kullanım

### Giriş

Programı başlatmak için terminalde aşağıdaki komutu çalıştırın:

bash
./envanter_yonetimi.sh


Giriş ekranında kullanıcı adı ve parolanızı girin. İlk kez giriş yapıyorsanız, varsayılan yönetici hesabını kullanabilirsiniz.

![Giriş Ekranı](./screenshots/login.png)

### Yönetici Menüsü

Yönetici olarak giriş yaptıktan sonra aşağıdaki işlemleri gerçekleştirebilirsiniz:

1. *Ürün Ekle:*
   - Yeni ürün bilgilerini girerek envantere ekleyin.
   
   ![Ürün Ekle](./screenshots/add_product.png)

2. *Ürünleri Listele:*
   - Tüm ürünleri görüntüleyin.
   
   ![Ürün Listele](./screenshots/list_products.png)

3. *Ürün Güncelle:*
   - Seçtiğiniz bir ürünün stok miktarını, fiyatını veya kategorisini güncelleyin.
   
   ![Ürün Güncelle](./screenshots/update_product.png)

4. *Ürün Sil:*
   - Seçtiğiniz bir ürünü envanterden silin.
   
   ![Ürün Sil](./screenshots/delete_product.png)

5. *Rapor Al:*
   - *Stokta Azalan Ürünler:* Belirlediğiniz eşik değerin altında stokta olan ürünleri listeler.
   - *En Yüksek Stok Miktarına Sahip Ürünler:* Belirlediğiniz eşik değerin üzerinde stokta olan ürünleri listeler.
   
   ![Rapor Al](./screenshots/report_menu.png)

6. *Kullanıcı Yönetimi:*
   - Yeni kullanıcı ekleme, mevcut kullanıcıları listeleme, güncelleme ve silme işlemleri yapın.
   
   ![Kullanıcı Yönetimi](./screenshots/user_management.png)

7. *Program Yönetimi:*
   - Disk alanını kontrol edin, verileri yedekleyin veya hata kayıtlarını görüntüleyin.
   
   ![Program Yönetimi](./screenshots/program_management.png)

8. *Hesap Kilidini Aç:*
   - Kilitli kullanıcı hesaplarını yöneticinin açmasını sağlayın.
   
   ![Hesap Kilidini Aç](./screenshots/unlock_user.png)

9. *Çıkış:*
   - Programdan çıkış yapın.

### Kullanıcı Menüsü

Normal kullanıcı olarak giriş yaptığınızda aşağıdaki işlemleri gerçekleştirebilirsiniz:

1. *Ürünleri Listele:*
   - Tüm ürünleri görüntüleyin.

2. *Rapor Al:*
   - *Stokta Azalan Ürünler*
   - *En Yüksek Stok Miktarına Sahip Ürünler*

3. *Çıkış:*
   - Programdan çıkış yapın.

![Kullanıcı Menüsü](./screenshots/user_menu.png)

## Raporlar

### Stokta Azalan Ürünler

Belirlediğiniz eşik değerin altında stokta olan ürünleri listeler.

![Stokta Azalan Ürünler](./screenshots/report_low_stock.png)

### En Yüksek Stok Miktarına Sahip Ürünler

Belirlediğiniz eşik değerin üzerinde stokta olan ürünleri listeler.

![En Yüksek Stok](./screenshots/report_high_stock.png)

## Program Yönetimi

### Disk Alanını Göster

Programın çalıştığı dizindeki disk kullanımını gösterir.

![Disk Alanı](./screenshots/disk_space.png)

### Diske Yedekle

Envanter ve kullanıcı verilerini seçtiğiniz bir klasöre yedekler.

![Yedekleme](./screenshots/backup.png)

### Hata Kayıtlarını Görüntüleme

log.csv dosyasındaki tüm hata kayıtlarını listeler.

![Hata Kayıtları](./screenshots/error_logs.png)

## Hata Kayıtları

Tüm hatalar log.csv dosyasına kaydedilir ve yönetici tarafından görüntülenebilir. Hata kayıtları, hata numarası, zaman bilgisi, kullanıcı bilgisi ve ilgili ürün bilgisi içerir.

![Hata Kaydı](./screenshots/log_entry.png)

## Katkıda Bulunanlar

Bu projeye katkıda bulunmak isterseniz, lütfen aşağıdaki adımları takip edin:

1. *Fork* yapın.
2. *Branch* oluşturun (git checkout -b feature/Özellik).
3. *Commit* yapın (git commit -m 'Yeni özellik eklendi').
4. *Push* yapın (git push origin feature/Özellik).
5. *Pull Request* açın.

## Lisans

Bu proje [MIT Lisansı](./LICENSE) altında lisanslanmıştır. Daha fazla bilgi için [LICENSE](./LICENSE) dosyasını inceleyebilirsiniz.

## Kaynakça

- [Zenity Manual](https://help.gnome.org/users/zenity/3.32/)
- [Zenity Forms Example](https://help.gnome.org/users/zenity/stable/forms.html.en)
- [Zenity ile Kabuk Programlama (Türkçe)](https://wiki.ubuntu-tr.net/index.php?title=Zenity_ile_kabuk_programlama)
- [Zenity Create GUI Dialog Boxes in Bash Scripts](https://ostechnix.com/zenity-create-gui-dialog-boxes-in-bash-scripts/)
- [Zenity Examples](https://funprojects.blog/tag/zenity/)

## Video Demo

Kullanımını detaylı olarak gösteren 3-4 dakikalık bir video hazırladım. Aşağıdaki bağlantıdan izleyebilirsiniz:

[![Video Demo](./screenshots/video_thumbnail.png)](https://www.youtube.com/watch?v=videolink)

Video kısa bir süre için geçici bir bağlantıdır. Lütfen videoyu YouTube veya başka bir video platformuna yükleyip, bağlantıyı buraya ekleyin.

---

### Notlar

- *Şifre Güvenliği:* Şifreler MD5 ile hashlenmiştir. Daha güvenli bir hashing yöntemi tercih edilebilir (örn. SHA-256).
- *CSV Dosya Yapıları:*
  - *depo.csv:* id,Ürün Adı,Stok Miktarı,Birim Fiyatı,Kategori
  - *kullanici.csv:* Kullanıcı Adı,Ad Soyad,Rol,Parola(Kodlanmış),Kilitli Mi,Başarısız Giriş Sayısı
  - *log.csv:* Tarih,Hata Kodu,Kullanıcı,Hata Mesajı,İlgili Ürün
- *Güvenlik:* Yönetici hesabının kilitlenmesi ve yeniden açılması mümkündür. İlk girişte varsayılan yönetici hesabını kullanabilirsiniz.

---

Bu proje, Zenity kullanarak basit ve etkili bir envanter yönetim sistemi sunmaktadır. Herhangi bir sorunla karşılaşırsanız veya öneriniz olursa, lütfen [Issues](https://github.com/musrates/Zenity_Envanter_sistemi/issues) sekmesinden bana ulaşın.
