#!/bin/bash


DEPO_CSV="depo.csv"
KULLANICI_CSV="kullanici.csv"
LOG_CSV="log.csv"


ADMIN_PASS="0192023a7bbd73250516f069df18b500"




hata_kaydet() {
    local hata_no="$1"
    local hata_mesaj="$2"
    local kullanici="$3"
    local urun_bilgisi="$4"
    echo "$hata_no,$(date '+%Y-%m-%d %H:%M:%S'),$kullanici,$hata_mesaj,$urun_bilgisi" >> "$LOG_CSV"
}


dosya_kontrol() {
    # CSV dosyalarının varlığını kontrol et ve yoksa oluştur
    [ ! -f "$DEPO_CSV" ] && echo "urun_no,urun_adi,stok_miktari,birim_fiyati,kategori" > "$DEPO_CSV"
    [ ! -f "$KULLANICI_CSV" ] && echo "no,adi,soyadi,rol,parola,durum" > "$KULLANICI_CSV"
    [ ! -f "$LOG_CSV" ] && echo "hata_no,zaman,kullanici,hata_mesaj,urun_bilgisi" > "$LOG_CSV"

    # Varsayılan admin kullanıcısı yoksa ekle
    if ! grep -q "^1,admin,admin,yonetici,$ADMIN_PASS,aktif$" "$KULLANICI_CSV"; then
        echo "1,admin,admin,yonetici,$ADMIN_PASS,aktif" >> "$KULLANICI_CSV"
    fi
}

# Giriş yapma fonksiyonu
giris_yap() {
    local deneme=0
    while [ "$deneme" -lt 3 ]; do
        credentials=$(zenity --forms --title="Giriş" \
            --text="Kullanıcı bilgilerinizi giriniz" \
            --separator="|" \
            --add-entry="Kullanıcı Adı" \
            --add-password="Parola")

        if [ $? -ne 0 ]; then
            exit 0
        fi

        kullanici_adi=$(echo "$credentials" | cut -d'|' -f1)
        parola=$(echo "$credentials" | cut -d'|' -f2)
        parola_md5=$(echo -n "$parola" | md5sum | awk '{print $1}')

        # Kullanıcı kontrolü
        kullanici_kayit=$(grep "^.*,${kullanici_adi},.*$parola_md5,.*" "$KULLANICI_CSV")
        if [ -n "$kullanici_kayit" ]; then
            durum=$(echo "$kullanici_kayit" | cut -d',' -f6)
            if [ "$durum" = "aktif" ]; then
                AKTIF_KULLANICI=$(echo "$kullanici_kayit" | cut -d',' -f2)
                return 0
            else
                zenity --error --title="Hata" --text="Hesabınız kilitli. Yönetici ile iletişime geçin."
                hata_kaydet "1001" "Kilitli hesap girişi denemesi" "$kullanici_adi" "-"
                return 1
            fi
        fi

        ((deneme++))
        kalan_deneme=$((3 - deneme))
        zenity --error --title="Hata" --text="Hatalı kullanıcı adı veya parola! Kalan deneme: $kalan_deneme"
    done

    # 3 başarısız deneme sonrası hesabı kilitle
    sed -i "s/^\([^,]*\),${kullanici_adi},\([^,]*\),\(.*\)/\1,\2,\3,*,kilitli/" "$KULLANICI_CSV"
    hata_kaydet "1002" "Hesap kilitlendi - 3 başarısız deneme" "$kullanici_adi" "-"
    zenity --error --title="Hata" --text="Hesabınız kilitlendi. Yönetici ile iletişime geçin."
    return 1
}


yetki_kontrol() {
    local gerekli_rol="$1"
    kullanici_rol=$(grep "^.*,${AKTIF_KULLANICI},.*,.*,.*,.*" "$KULLANICI_CSV" | cut -d',' -f4)
    if [ "$gerekli_rol" = "yonetici" ] && [ "$kullanici_rol" != "yonetici" ]; then
        return 1
    fi
    return 0
}


urun_ekle() {
    if ! yetki_kontrol "yonetici"; then
        zenity --error --title="Hata" --text="Bu işlem için yetkiniz yok!"
        return 1
    fi

    form_data=$(zenity --forms --title="Ürün Ekle" \
        --text="Ürün bilgilerini giriniz" \
        --separator="|" \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-entry="Kategori")

    if [ $? -ne 0 ]; then
        return 1
    fi

    urun_adi=$(echo "$form_data" | cut -d'|' -f1)
    stok_miktari=$(echo "$form_data" | cut -d'|' -f2)
    birim_fiyati=$(echo "$form_data" | cut -d'|' -f3)
    kategori=$(echo "$form_data" | cut -d'|' -f4)

    # Veri doğrulama
    if ! [[ "$stok_miktari" =~ ^[0-9]+$ ]] || ! [[ "$birim_fiyati" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; then
        zenity --error --title="Hata" --text="Stok miktarı ve birim fiyatı sayısal olmalıdır!"
        hata_kaydet "2001" "Geçersiz sayısal değer" "$AKTIF_KULLANICI" "$urun_adi"
        return 1
    fi

    if [[ "$urun_adi" =~ [[:space:]] ]] || [[ "$kategori" =~ [[:space:]] ]]; then
        zenity --error --title="Hata" --text="Ürün adı ve kategori boşluk içermemelidir!"
        hata_kaydet "2002" "Geçersiz karakter" "$AKTIF_KULLANICI" "$urun_adi"
        return 1
    fi

  
    if grep -q "^.*,${urun_adi},.*" "$DEPO_CSV"; then
        zenity --error --title="Hata" --text="Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz."
        hata_kaydet "2003" "Tekrar eden ürün adı" "$AKTIF_KULLANICI" "$urun_adi"
        return 1
    fi

 
    urun_no=$(tail -n +2 "$DEPO_CSV" | cut -d',' -f1 | sort -n | tail -n1)
    urun_no=$((urun_no + 1))

    # Ürün ekleme işlemi
    (
        echo "10"
        sleep 0.3
        echo "# Ürün kaydediliyor..."
        sleep 0.3
        echo "50"
        sleep 0.3
        echo "$urun_no,$urun_adi,$stok_miktari,$birim_fiyati,$kategori" >> "$DEPO_CSV"
        sleep 0.3
        echo "90"
        sleep 0.3
        echo "# Tamamlandı!"
        sleep 0.3
        echo "100"
    ) | zenity --progress \
        --title="Ürün Ekleniyor" \
        --text="İşlem başlatılıyor..." \
        --percentage=0 \
        --auto-close

    zenity --info --title="Başarılı" --text="Ürün başarıyla eklendi!"
}


urun_listele() {
    if [ ! -f "$DEPO_CSV" ]; then
        zenity --error --title="Hata" --text="Ürün listesi bulunamadı!"
        return 1
    fi

    liste="No | Ürün Adı | Stok | Birim Fiyatı | Kategori\n"
    liste+="-----------------------------------------------\n"

    while IFS=, read -r no ad stok fiyat kat; do
        [ "$no" = "urun_no" ] && continue
        liste+="$no | $ad | $stok | $fiyat TL | $kat\n"
    done < "$DEPO_CSV"

    echo -e "$liste" | zenity --text-info \
        --title="Ürün Listesi" \
        --width=500 \
        --height=400
}


urun_guncelle() {
    if ! yetki_kontrol "yonetici"; then
        zenity --error --title="Hata" --text="Bu işlem için yetkiniz yok!"
        return 1
    fi

    urun_adi=$(zenity --entry \
        --title="Ürün Güncelle" \
        --text="Güncellenecek ürünün adını giriniz:")

    if [ $? -ne 0 ]; then
        return 1
    fi

    urun_kayit=$(grep "^.*,${urun_adi},.*" "$DEPO_CSV")
    if [ -z "$urun_kayit" ]; then
        zenity --error --title="Hata" --text="Ürün bulunamadı!"
        return 1
    fi

    eski_no=$(echo "$urun_kayit" | cut -d',' -f1)
    eski_stok=$(echo "$urun_kayit" | cut -d',' -f3)
    eski_fiyat=$(echo "$urun_kayit" | cut -d',' -f4)
    eski_kat=$(echo "$urun_kayit" | cut -d',' -f5)

    form_data=$(zenity --forms --title="Ürün Güncelle" \
        --text="Yeni bilgileri giriniz (Boş bırakılan alanlar değişmeyecektir)" \
        --separator="|" \
        --add-entry="Stok Miktarı [$eski_stok]" \
        --add-entry="Birim Fiyatı [$eski_fiyat]" \
        --add-entry="Kategori [$eski_kat]")

    if [ $? -ne 0 ]; then
        return 1
    fi

    yeni_stok=$(echo "$form_data" | cut -d'|' -f1)
    yeni_fiyat=$(echo "$form_data" | cut -d'|' -f2)
    yeni_kat=$(echo "$form_data" | cut -d'|' -f3)

    # Boş alanlar için eski değerleri kullan
    [ -z "$yeni_stok" ] && yeni_stok="$eski_stok"
    [ -z "$yeni_fiyat" ] && yeni_fiyat="$eski_fiyat"
    [ -z "$yeni_kat" ] && yeni_kat="$eski_kat"

    # Veri doğrulama
    if ! [[ "$yeni_stok" =~ ^[0-9]+$ ]] || ! [[ "$yeni_fiyat" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; then
        zenity --error --title="Hata" --text="Stok miktarı ve birim fiyatı sayısal olmalıdır!"
        hata_kaydet "3001" "Geçersiz sayısal değer" "$AKTIF_KULLANICI" "$urun_adi"
        return 1
    fi

    # Ürün güncelleme işlemi
    (
        echo "10"
        sleep 0.3
        echo "# Ürün güncelleniyor..."
        sleep 0.3
        echo "50"
        sleep 0.3
        sed -i "s/^${eski_no},${urun_adi},${eski_stok},${eski_fiyat},${eski_kat}/${eski_no},${urun_adi},${yeni_stok},${yeni_fiyat},${yeni_kat}/" "$DEPO_CSV"
        sleep 0.3
        echo "90"
        sleep 0.3
        echo "# Tamamlandı!"
        sleep 0.3
        echo "100"
    ) | zenity --progress \
        --title="Ürün Güncelleniyor" \
        --text="İşlem başlatılıyor..." \
        --percentage=0 \
        --auto-close

    zenity --info --title="Başarılı" --text="Ürün başarıyla güncellendi!"
}


urun_sil() {
    if ! yetki_kontrol "yonetici"; then
        zenity --error --title="Hata" --text="Bu işlem için yetkiniz yok!"
        return 1
    fi

    urun_adi=$(zenity --entry \
        --title="Ürün Sil" \
        --text="Silinecek ürünün adını giriniz:")

    if [ $? -ne 0 ]; then
        return 1
    fi

    if ! grep -q "^.*,${urun_adi},.*" "$DEPO_CSV"; then
        zenity --error --title="Hata" --text="Ürün bulunamadı!"
        return 1
    fi

    if ! zenity --question \
        --title="Onay" \
        --text="'$urun_adi' ürününü silmek istediğinizden emin misiniz?"; then
        return 1
    fi

    # Ürün silme işlemi
    (
        echo "10"
        sleep 0.3
        echo "# Ürün siliniyor..."
        sleep 0.3
        echo "50"
        sleep 0.3
        sed -i "/^.*,${urun_adi},.*/d" "$DEPO_CSV"
        sleep 0.3
        echo "90"
        sleep 0.3
        echo "# Tamamlandı!"
        sleep 0.3
        echo "100"
    ) | zenity --progress \
        --title="Ürün Siliniyor" \
        --text="İşlem başlatılıyor..." \
        --percentage=0 \
        --auto-close

    zenity --info --title="Başarılı" --text="Ürün başarıyla silindi!"
}

# Rapor alma fonksiyonu
rapor_al() {
    rapor_secim=$(zenity --list \
        --title="Rapor Al" \
        --text="Rapor türünü seçiniz:" \
        --radiolist \
        --column="Seç" \
        --column="Rapor" \
        TRUE "Stokta Azalan Ürünler" \
        FALSE "En Yüksek Stok Miktarına Sahip Ürünler")

    if [ $? -ne 0 ]; then
        return 1
    fi

    case "$rapor_secim" in
        "Stokta Azalan Ürünler")
            esik=$(zenity --entry \
                --title="Stok Eşiği" \
                --text="Minimum stok eşiğini giriniz:")
            [ $? -ne 0 ] && return 1

            if ! [[ "$esik" =~ ^[0-9]+$ ]]; then
                zenity --error --title="Hata" --text="Eşik değeri sayısal olmalıdır!"
                return 1
            fi

            rapor="Stok Miktarı $esik'in Altında Olan Ürünler:\n\n"
            rapor+="Ürün Adı | Stok | Birim Fiyatı | Kategori\n"
            rapor+="----------------------------------------\n"

            while IFS=, read -r no ad stok fiyat kat; do
                [ "$no" = "urun_no" ] && continue
                if [ "$stok" -lt "$esik" ]; then
                    rapor+="$ad | $stok | $fiyat TL | $kat\n"
                fi
            done < "$DEPO_CSV"
            ;;
        
        "En Yüksek Stok Miktarına Sahip Ürünler")
            esik=$(zenity --entry \
                --title="Stok Eşiği" \
                --text="Minimum stok eşiğini giriniz:")
            [ $? -ne 0 ] && return 1

            if ! [[ "$esik" =~ ^[0-9]+$ ]]; then
                zenity --error --title="Hata" --text="Eşik değeri sayısal olmalıdır!"
                return 1
            fi

            rapor="Stok Miktarı $esik'in Üzerinde Olan Ürünler:\n\n"
            rapor+="Ürün Adı | Stok | Birim Fiyatı | Kategori\n"
            rapor+="----------------------------------------\n"

            while IFS=, read -r no ad stok fiyat kat; do
                [ "$no" = "urun_no" ] && continue
                if [ "$stok" -gt "$esik" ]; then
                    rapor+="$ad | $stok | $fiyat TL | $kat\n"
                fi
            done < "$DEPO_CSV"
            ;;
    esac

    echo -e "$rapor" | zenity --text-info \
        --title="Rapor Sonuçları" \
        --width=500 \
        --height=400
}

# Kullanıcı yönetimi fonksiyonu
kullanici_yonetimi() {
    if ! yetki_kontrol "yonetici"; then
        zenity --error --title="Hata" --text="Bu işlem için yetkiniz yok!"
        return 1
    fi

    secim=$(zenity --list \
        --title="Kullanıcı Yönetimi" \
        --text="İşlem seçiniz:" \
        --column="İşlem" \
        "Yeni Kullanıcı Ekle" \
        "Kullanıcıları Listele" \
        "Kullanıcı Güncelle" \
        "Kullanıcı Sil")

    case "$secim" in
        "Yeni Kullanıcı Ekle")
            form_data=$(zenity --forms --title="Kullanıcı Ekle" \
                --text="Kullanıcı bilgilerini giriniz" \
                --separator="|" \
                --add-entry="Adı" \
                --add-entry="Soyadı" \
                --add-entry="Kullanıcı Adı" \
                --add-password="Parola" \
                --add-combo="Rol" \
                --combo-values="kullanici,yonetici")

            [ $? -ne 0 ] && return 1

            adi=$(echo "$form_data" | cut -d'|' -f1)
            soyadi=$(echo "$form_data" | cut -d'|' -f2)
            kul_adi=$(echo "$form_data" | cut -d'|' -f3)
            parola=$(echo "$form_data" | cut -d'|' -f4)
            rol=$(echo "$form_data" | cut -d'|' -f5)

            # Kullanıcı adı kontrolü
            if grep -q "^.*,${kul_adi},.*" "$KULLANICI_CSV"; then
                zenity --error --title="Hata" --text="Bu kullanıcı adı zaten mevcut!"
                hata_kaydet "4001" "Tekrar eden kullanıcı adı" "$AKTIF_KULLANICI" "$kul_adi"
                return 1
            fi

            parola_md5=$(echo -n "$parola" | md5sum | awk '{print $1}')

            # Kullanıcı no oluştur
            kul_no=$(tail -n +2 "$KULLANICI_CSV" | cut -d',' -f1 | sort -n | tail -n1)
            kul_no=$((kul_no + 1))

            echo "$kul_no,$adi,$soyadi,$rol,$parola_md5,aktif" >> "$KULLANICI_CSV"
            zenity --info --title="Başarılı" --text="Kullanıcı başarıyla eklendi!"
            ;;

        "Kullanıcıları Listele")
            liste="No | Adı | Soyadı | Rol | Durum\n"
            liste+="---------------------------------\n"

            while IFS=, read -r no ad soyad rol parola durum; do
                [ "$no" = "no" ] && continue
                liste+="$no | $ad | $soyad | $rol | $durum\n"
            done < "$KULLANICI_CSV"

            echo -e "$liste" | zenity --text-info \
                --title="Kullanıcı Listesi" \
                --width=500 \
                --height=400
            ;;

        "Kullanıcı Güncelle")
            kul_adi=$(zenity --entry \
                --title="Kullanıcı Güncelle" \
                --text="Güncellenecek kullanıcının kullanıcı adını giriniz:")

            [ $? -ne 0 ] && return 1

            kullanici_kayit=$(grep "^.*,${kul_adi},.*" "$KULLANICI_CSV")
            if [ -z "$kullanici_kayit" ]; then
                zenity --error --title="Hata" --text="Kullanıcı bulunamadı!"
                return 1
            fi

            kul_no=$(echo "$kullanici_kayit" | cut -d',' -f1)
            eski_ad=$(echo "$kullanici_kayit" | cut -d',' -f2)
            eski_soyad=$(echo "$kullanici_kayit" | cut -d',' -f3)
            eski_rol=$(echo "$kullanici_kayit" | cut -d',' -f4)
            eski_parola=$(echo "$kullanici_kayit" | cut -d',' -f5)
            durum=$(echo "$kullanici_kayit" | cut -d',' -f6)

            form_data=$(zenity --forms --title="Kullanıcı Güncelle" \
                --text="Yeni bilgileri giriniz (Boş bırakılan alanlar değişmeyecektir)" \
                --separator="|" \
                --add-entry="Yeni Adı [${eski_ad}]" \
                --add-entry="Yeni Soyadı [${eski_soyad}]" \
                --add-password="Yeni Parola (Boş bırakılırsa eski parola kullanılır)" \
                --add-combo="Yeni Rol" \
                --combo-values="kullanici,yonetici")

            [ $? -ne 0 ] && return 1

            yeni_ad=$(echo "$form_data" | cut -d'|' -f1)
            yeni_soyad=$(echo "$form_data" | cut -d'|' -f2)
            yeni_parola=$(echo "$form_data" | cut -d'|' -f3)
            yeni_rol=$(echo "$form_data" | cut -d'|' -f4)

            # Boş alanlar için eski değerleri kullan
            [ -z "$yeni_ad" ] && yeni_ad="$eski_ad"
            [ -z "$yeni_soyad" ] && yeni_soyad="$eski_soyad"
            [ -z "$yeni_rol" ] && yeni_rol="$eski_rol"

            if [ -n "$yeni_parola" ]; then
                yeni_parola_md5=$(echo -n "$yeni_parola" | md5sum | awk '{print $1}')
            else
                yeni_parola_md5="$eski_parola"
            fi

            # Kullanıcı güncelleme işlemi
            sed -i "s/^${kul_no},${kul_adi},${eski_soyad},${eski_rol},${eski_parola},${durum}/${kul_no},${yeni_ad},${yeni_soyad},${yeni_rol},${yeni_parola_md5},${durum}/" "$KULLANICI_CSV"

            zenity --info --title="Başarılı" --text="Kullanıcı başarıyla güncellendi!"
            ;;

        "Kullanıcı Sil")
            kul_adi=$(zenity --entry \
                --title="Kullanıcı Sil" \
                --text="Silinecek kullanıcının kullanıcı adını giriniz:")

            [ $? -ne 0 ] && return 1

            if ! grep -q "^.*,${kul_adi},.*" "$KULLANICI_CSV"; then
                zenity --error --title="Hata" --text="Kullanıcı bulunamadı!"
                return 1
            fi

            if ! zenity --question \
                --title="Onay" \
                --text="'$kul_adi' kullanıcısını silmek istediğinizden emin misiniz?"; then
                return 1
            fi

            sed -i "/^.*,${kul_adi},.*/d" "$KULLANICI_CSV"
            zenity --info --title="Başarılı" --text="Kullanıcı başarıyla silindi!"
            ;;
    esac
}

# Program yönetimi fonksiyonu
program_yonetimi() {
    if ! yetki_kontrol "yonetici"; then
        zenity --error --title="Hata" --text="Bu işlem için yetkiniz yok!"
        return 1
    fi

    secim=$(zenity --list \
        --title="Program Yönetimi" \
        --text="İşlem seçiniz:" \
        --column="İşlem" \
        "Diskteki Alanı Göster" \
        "Diske Yedekle" \
        "Hata Kayıtlarını Göster")

    case "$secim" in
        "Diskteki Alanı Göster")
            boyut=$(du -ch "$DEPO_CSV" "$KULLANICI_CSV" "$LOG_CSV" 2>/dev/null | grep total | awk '{print $1}')
            zenity --info \
                --title="Disk Kullanımı" \
                --text="Toplam kullanılan alan: $boyut"
            ;;

        "Diske Yedekle")
            tarih=$(date +%Y%m%d_%H%M%S)
            yedek_dizin="yedek_$tarih"

            mkdir -p "$yedek_dizin" && cp "$DEPO_CSV" "$KULLANICI_CSV" "$LOG_CSV" "$yedek_dizin/" 2>/dev/null

            if [ $? -eq 0 ]; then
                zenity --info \
                    --title="Yedekleme" \
                    --text="Dosyalar '$yedek_dizin' dizinine yedeklendi."
            else
                zenity --error --title="Hata" --text="Yedekleme sırasında bir hata oluştu!"
            fi
            ;;

        "Hata Kayıtlarını Göster")
            if [ ! -f "$LOG_CSV" ]; then
                zenity --error --title="Hata" --text="Hata kayıt dosyası bulunamadı!"
                return 1
            fi

            kayitlar="Hata Kayıtları:\n\n"
            kayitlar+="No | Zaman | Kullanıcı | Hata | Ürün\n"
            kayitlar+="----------------------------------------\n"

            while IFS=, read -r no zaman kul hata urun; do
                [ "$no" = "hata_no" ] && continue
                kayitlar+="$no | $zaman | $kul | $hata | $urun\n"
            done < "$LOG_CSV"

            echo -e "$kayitlar" | zenity --text-info \
                --title="Hata Kayıtları" \
                --width=700 \
                --height=500
            ;;
    esac
}

# Ana menü fonksiyonu
ana_menu() {
    while true; do
        menu_secim=$(zenity --list \
            --title="Envanter Yönetim Sistemi" \
            --text="Hoş geldiniz, $AKTIF_KULLANICI" \
            --column="İşlem" \
            "Ürün Ekle" \
            "Ürün Listele" \
            "Ürün Güncelle" \
            "Ürün Sil" \
            "Rapor Al" \
            "Kullanıcı Yönetimi" \
            "Program Yönetimi" \
            "Çıkış" \
            --width=800 \
            --height=500)

        case "$menu_secim" in
            "Ürün Ekle") urun_ekle ;;
            "Ürün Listele") urun_listele ;;
            "Ürün Güncelle") urun_guncelle ;;
            "Ürün Sil") urun_sil ;;
            "Rapor Al") rapor_al ;;
            "Kullanıcı Yönetimi") kullanici_yonetimi ;;
            "Program Yönetimi") program_yonetimi ;;
            "Çıkış"|"")
                if zenity --question \
                    --title="Çıkış" \
                    --text="Programdan çıkmak istediğinize emin misiniz?"; then
                    exit 0
                fi
                ;;
        esac
    done
}

# Ana program
AKTIF_KULLANICI=""

# Başlangıç kontrolleri
dosya_kontrol

# Giriş yap
if giris_yap; then
    # Ana menüyü başlat
    ana_menu
fi
