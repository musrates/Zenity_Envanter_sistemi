#!/bin/bash
# Gerekli dosyaların kontrolü ve ilk ayarlar
# Gerekli dosyaların kontrolü ve ilk ayarlar
check_files() {
    local files=("depo.csv" "kullanici.csv" "log.csv")
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            touch "$file"
            if [ "$file" == "kullanici.csv" ]; then
                # Admin kullanıcısını ekle (username, ad soyad, rol, parola, kilitli_mi, başarısız_giriş)
                echo "admin,Admin Admin,yonetici,$(echo -n "admin123" | md5sum | cut -d' ' -f1),0,0" > "$file"
            fi
        fi
    done
    chmod 644 *.csv
}


# Hata kaydı oluşturma
log_error() {
    local error_no=$1
    local error_msg=$2
    local user=$3
    local product=$4
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$error_no,$user,$error_msg,$product" >> log.csv
}

# İlerleme çubuğu gösterimi
show_progress() {
    local message=$1
    (
        echo "0"
        sleep 0.5
        echo "25"
        sleep 0.5
        echo "50"
        sleep 0.5
        echo "75"
        sleep 0.5
        echo "100"
    ) | zenity --progress \
        --title="İşlem Durumu" \
        --text="$message" \
        --percentage=0 \
        --auto-close \
        --width=300
}

# Kullanıcı girişi
login() {
    local credentials
    credentials=$(zenity --forms --title="Giriş" \
        --text="Kullanıcı Girişi" \
        --add-entry="Kullanıcı Adı" \
        --add-password="Parola" \
        --width=300)

    if [ -z "$credentials" ]; then
        exit 0
    fi

    local username=$(echo "$credentials" | cut -d'|' -f1)
    local password=$(echo "$credentials" | cut -d'|' -f2)
    local md5pass=$(echo -n "$password" | md5sum | cut -d' ' -f1)

    # Kullanıcı bilgilerini al
    local user_info
    user_info=$(grep "^$username," kullanici.csv)

    if [ -n "$user_info" ]; then
        local stored_pass=$(echo "$user_info" | cut -d',' -f4)
        local role=$(echo "$user_info" | cut -d',' -f3)
        local locked=$(echo "$user_info" | cut -d',' -f5)
        local failed_attempts=$(echo "$user_info" | cut -d',' -f6)

        if [ "$locked" -eq 1 ]; then
            zenity --error --text="Hesabınız kilitlenmiştir. Yönetici ile iletişime geçiniz." --width=300
            log_error "1002" "Kilitli hesaba giriş denemesi" "$username" "-"
            return 1
        fi

        if [ "$md5pass" = "$stored_pass" ]; then
            # Başarılı giriş, başarısız giriş sayısını sıfırla
            sed -i "/^$username,/c\\$username,$(echo "$user_info" | cut -d',' -f2),$role,$stored_pass,0,0" kullanici.csv
            export CURRENT_USER="$username"
            export USER_ROLE="$role"
            return 0
        else
            # Başarısız giriş, sayıyı artır
            local new_failed=$((failed_attempts + 1))
            if [ "$new_failed" -ge 3 ]; then
                # Hesabı kilitle
                sed -i "/^$username,/c\\$username,$(echo "$user_info" | cut -d',' -f2),$role,$stored_pass,1,0" kullanici.csv
                zenity --error --text="3 kez hatalı giriş yapıldı. Hesabınız kilitlendi." --width=300
                log_error "1003" "Hesap kilitlenmesi" "$username" "-"
            else
                # Başarısız giriş sayısını güncelle
                sed -i "/^$username,/c\\$username,$(echo "$user_info" | cut -d',' -f2),$role,$stored_pass,$locked,$new_failed" kullanici.csv
                zenity --error --text="Hatalı kullanıcı adı veya parola!" --width=200
                log_error "1001" "Hatalı giriş denemesi" "$username" "-"
            fi
            return 1
        fi
    else
        zenity --error --text="Hatalı kullanıcı adı veya parola!" --width=200
        log_error "1001" "Hatalı giriş denemesi" "$username" "-"
        return 1
    fi
}

# Yeni ürün numarası oluşturma
get_new_product_id() {
    if [ ! -s depo.csv ]; then
        echo "1"
        return
    fi
    local last_id=$(tail -n 1 depo.csv | cut -d',' -f1)
    echo $((last_id + 1))
}

# Ürün ekleme
add_product() {
    local product_info
    product_info=$(zenity --forms --title="Ürün Ekle" \
        --text="Ürün Bilgileri" \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-entry="Kategori" \
        --width=300)

    if [ -z "$product_info" ]; then
        return
    fi

    local name=$(echo "$product_info" | cut -d'|' -f1)
    local stock=$(echo "$product_info" | cut -d'|' -f2)
    local price=$(echo "$product_info" | cut -d'|' -f3)
    local category=$(echo "$product_info" | cut -d'|' -f4)

    # Boşluk kontrolü
    if [[ "$name" =~ [[:space:]] ]] || [[ "$category" =~ [[:space:]] ]]; then
        zenity --error --text="Ürün adı ve kategori boşluk içeremez!" --width=300
        log_error "2001" "Ürün adı veya kategori boşluk içeriyor" "$CURRENT_USER" "$name"
        return
    fi

    # Sayısal değer kontrolü
    if ! [[ "$stock" =~ ^[0-9]+$ ]] || ! [[ "$price" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        zenity --error --text="Stok miktarı ve fiyat pozitif sayı olmalıdır!" --width=300
        log_error "2002" "Geçersiz stok veya fiyat değeri" "$CURRENT_USER" "$name"
        return
    fi

    # Ürün adı kontrolü
    if grep -q "^[^,]*,$name," depo.csv 2>/dev/null; then
        zenity --error \
            --text="Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz." \
            --width=300
        log_error "2003" "Aynı isimde ürün mevcut" "$CURRENT_USER" "$name"
        return
    fi

    local id=$(get_new_product_id)
    echo "$id,$name,$stock,$price,$category" >> depo.csv

    show_progress "Ürün ekleniyor..."
    zenity --info --text="Ürün başarıyla eklendi." --width=300
}

# Ürünleri listeleme
list_products() {
    if [ ! -s depo.csv ]; then
        zenity --info --text="Henüz ürün bulunmamaktadır." --width=300
        return
    fi

    local header="No\tÜrün Adı\tStok\tFiyat\tKategori"
    local content=$(awk -F',' 'BEGIN {OFS="\t"} {print $1, $2, $3, $4, $5}' depo.csv)

    echo -e "$header\n$content" | \
        zenity --text-info \
        --title="Ürün Listesi" \
        --width=700 --height=500
}

# Ürün güncelleme
update_product() {
    # Önce tüm ürünleri listeleyelim ve seçim yaptıralım
    if [ ! -s depo.csv ]; then
        zenity --error --text="Güncellenecek ürün bulunmamaktadır." --width=300
        return
    fi

    local product_list=$(awk -F',' '{print $2}' depo.csv)
    local product_name=$(echo "$product_list" | zenity --list \
        --title="Ürün Güncelle" \
        --text="Güncellenecek ürünü seçiniz:" \
        --column="Ürün Adı" \
        --width=300 --height=400)

    if [ -z "$product_name" ]; then
        return
    fi

    local product_line=$(grep "^.*,${product_name}," depo.csv)
    local product_id=$(echo "$product_line" | cut -d',' -f1)
    local current_stock=$(echo "$product_line" | cut -d',' -f3)
    local current_price=$(echo "$product_line" | cut -d',' -f4)
    local current_category=$(echo "$product_line" | cut -d',' -f5)

    local update_info=$(zenity --forms --title="Ürün Güncelle" \
        --text="Yeni Değerleri Giriniz (Boş bırakmak için bırakınız)" \
        --add-entry="Yeni Stok Miktarı [$current_stock]" \
        --add-entry="Yeni Birim Fiyatı [$current_price]" \
        --add-entry="Yeni Kategori [$current_category]" \
        --width=300)

    if [ -z "$update_info" ]; then
        return
    fi

    local new_stock=$(echo "$update_info" | cut -d'|' -f1)
    local new_price=$(echo "$update_info" | cut -d'|' -f2)
    local new_category=$(echo "$update_info" | cut -d'|' -f3)

    # Boş bırakılan değerleri mevcut değerlerle değiştir
    new_stock=${new_stock:-$current_stock}
    new_price=${new_price:-$current_price}
    new_category=${new_category:-$current_category}

    # Sayısal değer kontrolü
    if ! [[ "$new_stock" =~ ^[0-9]+$ ]] || ! [[ "$new_price" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        zenity --error --text="Stok miktarı ve fiyat pozitif sayı olmalıdır!" --width=300
        log_error "2005" "Geçersiz güncelleme değerleri" "$CURRENT_USER" "$product_name"
        return
    fi

    # Boşluk kontrolü
    if [[ "$new_category" =~ [[:space:]] ]]; then
        zenity --error --text="Kategori boşluk içeremez!" --width=300
        log_error "2006" "Kategori boşluk içeriyor" "$CURRENT_USER" "$product_name"
        return
    fi

    # Ürün satırını güncelle
    sed -i "/^$product_id,${product_name},/c\\$product_id,$product_name,$new_stock,$new_price,$new_category" depo.csv

    show_progress "Ürün güncelleniyor..."
    zenity --info --text="Ürün başarıyla güncellendi." --width=300
}

# Ürün silme
delete_product() {
    # Önce tüm ürünleri listeleyelim ve seçim yaptıralım
    if [ ! -s depo.csv ]; then
        zenity --error --text="Silinecek ürün bulunmamaktadır." --width=300
        return
    fi

    local product_list=$(awk -F',' '{print $2}' depo.csv)
    local product_name=$(echo "$product_list" | zenity --list \
        --title="Ürün Sil" \
        --text="Silinecek ürünü seçiniz:" \
        --column="Ürün Adı" \
        --width=300 --height=400)

    if [ -z "$product_name" ]; then
        return
    fi

    if ! zenity --question \
        --text="'$product_name' ürününü silmek istediğinize emin misiniz?" \
        --width=300; then
        return
    fi

    local product_id=$(grep "^.*,${product_name}," depo.csv | cut -d',' -f1)
    sed -i "/^$product_id,${product_name},/d" depo.csv

    show_progress "Ürün siliniyor..."
    zenity --info --text="Ürün başarıyla silindi." --width=300
}

# Yeni kullanıcı numarası oluşturma
get_new_user_id() {
    if [ ! -s kullanici.csv ]; then
        echo "1"
        return
    fi
    local last_id=$(tail -n 1 kullanici.csv | cut -d',' -f1)
    echo $((last_id + 1))
}

# Kullanıcı ekleme
add_user() {
    local user_info
    user_info=$(zenity --forms --title="Kullanıcı Ekle" \
        --text="Kullanıcı Bilgileri" \
        --add-entry="Ad" \
        --add-entry="Soyad" \
        --add-entry="Kullanıcı Adı" \
        --add-password="Parola" \
        --add-list="Rol" \
        --column="Rol" "kullanici" "yonetici" \
        --width=300)

    if [ -z "$user_info" ]; then
        return
    fi

    local name=$(echo "$user_info" | cut -d'|' -f1)
    local surname=$(echo "$user_info" | cut -d'|' -f2)
    local username=$(echo "$user_info" | cut -d'|' -f3)
    local password=$(echo "$user_info" | cut -d'|' -f4)
    local role=$(echo "$user_info" | cut -d'|' -f5)

    # Kullanıcı adı kontrolü
    if grep -q "^$username," kullanici.csv; then
        zenity --error --text="Bu kullanıcı adı zaten kullanımda!" --width=300
        log_error "3001" "Kullanıcı adı mevcut" "$CURRENT_USER" "$username"
        return
    fi

    local id=$(get_new_user_id)
    local md5pass=$(echo -n "$password" | md5sum | cut -d' ' -f1)

    echo "$username,$name $surname,$role,$md5pass,0,0" >> kullanici.csv

    show_progress "Kullanıcı ekleniyor..."
    zenity --info --text="Kullanıcı başarıyla eklendi." --width=300
}

# Kullanıcıları listeleme
list_users() {
    if [ ! -s kullanici.csv ]; then
        zenity --info --text="Henüz kullanıcı bulunmamaktadır." --width=300
        return
    fi

    local header="Kullanıcı Adı\tAd Soyad\tRol\tKilitli Mi"
    local content=$(awk -F',' 'BEGIN {OFS="\t"} {locked = ($6 == 1) ? "Evet" : "Hayır"; print $1, $2, $3, locked}' kullanici.csv)

    echo -e "$header\n$content" | \
        zenity --text-info \
        --title="Kullanıcı Listesi" \
        --width=700 --height=500
}

# Kullanıcı güncelleme
update_user() {
    local username=$(zenity --entry \
        --title="Kullanıcı Güncelle" \
        --text="Güncellenecek kullanıcının adını giriniz:" \
        --width=300)

    if [ -z "$username" ]; then
        return
    fi

    if [ "$username" == "admin" ]; then
        zenity --error --text="Admin kullanıcısı güncellenemez!" --width=300
        return
    fi

    local user_line=$(grep "^$username," kullanici.csv)

    if [ -z "$user_line" ]; then
        zenity --error --text="Kullanıcı bulunamadı!" --width=300
        log_error "3002" "Güncellenecek kullanıcı bulunamadı" "$CURRENT_USER" "$username"
        return
    fi

    local update_info=$(zenity --forms --title="Kullanıcı Güncelle" \
        --text="Yeni Bilgileri Giriniz (Boş bırakmak için bırakınız)" \
        --add-entry="Yeni Ad" \
        --add-entry="Yeni Soyad" \
        --add-password="Yeni Parola (boş bırakılabilir)" \
        --add-list="Yeni Rol" \
        --column="Rol" "kullanici" "yonetici" \
        --width=300)

    if [ -z "$update_info" ]; then
        return
    fi

    local new_name=$(echo "$update_info" | cut -d'|' -f1)
    local new_surname=$(echo "$update_info" | cut -d'|' -f2)
    local new_password=$(echo "$update_info" | cut -d'|' -f3)
    local new_role=$(echo "$update_info" | cut -d'|' -f4)

    # Boş bırakılan değerleri mevcut değerlerle değiştir
    new_name=${new_name:-$(echo "$user_line" | cut -d',' -f2 | awk '{print $1}')}
    new_surname=${new_surname:-$(echo "$user_line" | cut -d',' -f2 | awk '{print $2}')}
    new_role=${new_role:-$(echo "$user_line" | cut -d',' -f3)}
    local md5pass=$(echo -n "$new_password" | md5sum | cut -d' ' -f1)
    if [ -z "$new_password" ]; then
        md5pass=$(echo "$user_line" | cut -d',' -f5)
    fi

    # Kullanıcı satırını güncelle
    sed -i "/^$username,/c\\$username,$new_name $new_surname,$new_role,$md5pass,$(echo "$user_line" | cut -d',' -f6),$(echo "$user_line" | cut -d',' -f7)" kullanici.csv

    show_progress "Kullanıcı güncelleniyor..."
    zenity --info --text="Kullanıcı başarıyla güncellendi." --width=300
}

# Kullanıcı silme
delete_user() {
    local username=$(zenity --entry \
        --title="Kullanıcı Sil" \
        --text="Silinecek kullanıcının adını giriniz:" \
        --width=300)

    if [ -z "$username" ]; then
        return
    fi

    if [ "$username" == "admin" ]; then
        zenity --error --text="Admin kullanıcısı silinemez!" --width=300
        return
    fi

    if ! grep -q "^$username," kullanici.csv; then
        zenity --error --text="Kullanıcı bulunamadı!" --width=300
        log_error "3003" "Silinecek kullanıcı bulunamadı" "$CURRENT_USER" "$username"
        return
    fi

    if ! zenity --question \
        --text="'$username' kullanıcısını silmek istediğinize emin misiniz?" \
        --width=300; then
        return
    fi

    sed -i "/^$username,/d" kullanici.csv

    show_progress "Kullanıcı siliniyor..."
    zenity --info --text="Kullanıcı başarıyla silindi." --width=300
}

# Rapor Alma - Stokta Azalan Ürünler
report_low_stock() {
    local threshold=$(zenity --entry \
        --title="Stokta Azalan Ürünler" \
        --text="Eşik değeri giriniz:" \
        --width=300)

    if ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
        zenity --error --text="Eşik değeri pozitif bir sayı olmalıdır!" --width=300
        log_error "4001" "Geçersiz eşik değeri raporlama" "$CURRENT_USER" "-"
        return
    fi

    local low_stock=$(awk -F',' -v thresh="$threshold" '$3 < thresh {print $1"\t"$2"\t"$3"\t"$4"\t"$5}' depo.csv)

    if [ -z "$low_stock" ]; then
        zenity --info --text="Belirtilen eşik değerinin altında stokta ürün bulunmamaktadır." --width=300
        return
    fi

    local header="No\tÜrün Adı\tStok\tFiyat\tKategori"
    echo -e "$header\n$low_stock" | \
        zenity --text-info \
        --title="Stokta Azalan Ürünler" \
        --width=700 --height=500
}

# Rapor Alma - En Yüksek Stok Miktarına Sahip Ürünler
report_high_stock() {
    local threshold=$(zenity --entry \
        --title="En Yüksek Stok Miktarına Sahip Ürünler" \
        --text="Eşik değeri giriniz:" \
        --width=300)

    if ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
        zenity --error --text="Eşik değeri pozitif bir sayı olmalıdır!" --width=300
        log_error "4002" "Geçersiz eşik değeri raporlama" "$CURRENT_USER" "-"
        return
    fi

    local high_stock=$(awk -F',' -v thresh="$threshold" '$3 >= thresh {print $1"\t"$2"\t"$3"\t"$4"\t"$5}' depo.csv)

    if [ -z "$high_stock" ]; then
        zenity --info --text="Belirtilen eşik değerinin üzerinde stokta ürün bulunmamaktadır." --width=300
        return
    fi

    local header="No\tÜrün Adı\tStok\tFiyat\tKategori"
    echo -e "$header\n$high_stock" | \
        zenity --text-info \
        --title="En Yüksek Stok Miktarına Sahip Ürünler" \
        --width=700 --height=500
}

# Rapor Alma Menüsü
report_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="Rapor Alma" \
            --column="İşlemler" \
            "Stokta Azalan Ürünler" \
            "En Yüksek Stok Miktarına Sahip Ürünler" \
            "Geri" \
            --width=400 --height=300)

        case $choice in
            "Stokta Azalan Ürünler")
                report_low_stock
                ;;
            "En Yüksek Stok Miktarına Sahip Ürünler")
                report_high_stock
                ;;
            "Geri"|"")
                break
                ;;
        esac
    done
}

# Program Yönetimi - Diskteki Alanı Göster
show_disk_space() {
    local disk_usage=$(df -h . | awk 'NR==2 {print "Toplam Alan: "$2"\nKullanılan: "$3"\nBoş Alan: "$4}')
    echo -e "$disk_usage" | zenity --text-info --title="Disk Alanı Bilgisi" --width=400 --height=300
}

# Program Yönetimi - Diske Yedekle
backup_files() {
    local backup_dir=$(zenity --file-selection --directory --title="Yedekleme Klasörünü Seçiniz" --width=300)
    if [ -z "$backup_dir" ]; then
        return
    fi

    show_progress "Yedekleme yapılıyor..."
    cp depo.csv "$backup_dir"/depo_backup.csv
    cp kullanici.csv "$backup_dir"/kullanici_backup.csv

    zenity --info --text="Yedekleme başarılı!" --width=300
}

# Program Yönetimi - Hata Kayıtlarını Görüntüleme
view_error_logs() {
    if [ ! -s log.csv ]; then
        zenity --info --text="Henüz hata kaydı bulunmamaktadır." --width=300
        return
    fi

    local header="Tarih\tHata Kodu\tKullanıcı\tHata Mesajı\tİlgili Ürün"
    local content=$(awk -F',' 'BEGIN {OFS="\t"} {print $1, $2, $3, $4, $5}' log.csv)

    echo -e "$header\n$content" | \
        zenity --text-info \
        --title="Hata Kayıtları" \
        --width=800 --height=500
}

# Program Yönetimi Menüsü
program_management_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="Program Yönetimi" \
            --column="İşlemler" \
            "Disk Alanını Göster" \
            "Diske Yedekle" \
            "Hata Kayıtlarını Görüntüle" \
            "Geri" \
            --width=400 --height=300)

        case $choice in
            "Disk Alanını Göster")
                show_disk_space
                ;;
            "Diske Yedekle")
                backup_files
                ;;
            "Hata Kayıtlarını Görüntüle")
                view_error_logs
                ;;
            "Geri"|"")
                break
                ;;
        esac
    done
}

# Rapor ve Program Yönetimi Fonksiyonlarını Ana Menüye Ekleme
admin_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="Yönetici Menüsü" \
            --column="İşlemler" \
            "Ürün Ekle" \
            "Ürünleri Listele" \
            "Ürün Güncelle" \
            "Ürün Sil" \
            "Rapor Al" \
            "Kullanıcı Ekle" \
            "Kullanıcıları Listele" \
            "Kullanıcı Güncelle" \
            "Kullanıcı Sil" \
            "Program Yönetimi" \
            "Hata Kayıtlarını Görüntüle" \
            "Çıkış" \
            --width=400 --height=500)

        case $choice in
            "Ürün Ekle")
                add_product
                ;;
            "Ürünleri Listele")
                list_products
                ;;
            "Ürün Güncelle")
                update_product
                ;;
            "Ürün Sil")
                delete_product
                ;;
            "Rapor Al")
                report_menu
                ;;
            "Kullanıcı Ekle")
                add_user
                ;;
            "Kullanıcıları Listele")
                list_users
                ;;
            "Kullanıcı Güncelle")
                update_user
                ;;
            "Kullanıcı Sil")
                delete_user
                ;;
            "Program Yönetimi")
                program_management_menu
                ;;
            "Hata Kayıtlarını Görüntüle")
                view_error_logs
                ;;
            "Çıkış"|"")
                if zenity --question --text="Çıkmak istediğinize emin misiniz?" --width=300; then
                    exit 0
                fi
                ;;
        esac
    done
}

# Kullanıcı menüsü (Sadece ürün listeleme ve rapor alma)
user_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="Kullanıcı Menüsü" \
            --column="İşlemler" \
            "Ürünleri Listele" \
            "Rapor Al" \
            "Çıkış" \
            --width=300 --height=300)

        case $choice in
            "Ürünleri Listele")
                list_products
                ;;
            "Rapor Al")
                report_menu
                ;;
            "Çıkış"|"")
                if zenity --question --text="Çıkmak istediğinize emin misiniz?" --width=300; then
                    exit 0
                fi
                ;;
        esac
    done
}

# Hesap Kilidini Açma (Yönetici için)
unlock_user() {
    local username=$(zenity --entry \
        --title="Hesap Kilidini Aç" \
        --text="Kilidi açılacak kullanıcının adını giriniz:" \
        --width=300)

    if [ -z "$username" ]; then
        return
    fi

    if ! grep -q "^$username," kullanici.csv; then
        zenity --error --text="Kullanıcı bulunamadı!" --width=300
        log_error "5001" "Hesap kilidi açılmaya çalışılan kullanıcı bulunamadı" "$CURRENT_USER" "$username"
        return
    fi

    local user_line=$(grep "^$username," kullanici.csv)
    local locked=$(echo "$user_line" | cut -d',' -f6)

    if [ "$locked" -eq 0 ]; then
        zenity --info --text="Bu kullanıcının hesabı zaten açıktır." --width=300
        return
    fi

    sed -i "/^$username,/c\\$username,$(echo "$user_line" | cut -d',' -f2),$(echo "$user_line" | cut -d',' -f3),$(echo "$user_line" | cut -d',' -f4),$(echo "$user_line" | cut -d',' -f5),0,0" kullanici.csv

    zenity --info --text="Kullanıcının hesabı başarıyla açıldı." --width=300
    log_error "5002" "Hesap kilidi açıldı" "$CURRENT_USER" "$username"
}

# Yönetici menüsüne Hesap Kilidini Aç fonksiyonunu ekleme
admin_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="Yönetici Menüsü" \
            --column="İşlemler" \
            "Ürün Ekle" \
            "Ürünleri Listele" \
            "Ürün Güncelle" \
            "Ürün Sil" \
            "Rapor Al" \
            "Kullanıcı Ekle" \
            "Kullanıcıları Listele" \
            "Kullanıcı Güncelle" \
            "Kullanıcı Sil" \
            "Program Yönetimi" \
            "Hata Kayıtlarını Görüntüle" \
            "Hesap Kilidini Aç" \
            "Çıkış" \
            --width=400 --height=550)

        case $choice in
            "Ürün Ekle")
                add_product
                ;;
            "Ürünleri Listele")
                list_products
                ;;
            "Ürün Güncelle")
                update_product
                ;;
            "Ürün Sil")
                delete_product
                ;;
            "Rapor Al")
                report_menu
                ;;
            "Kullanıcı Ekle")
                add_user
                ;;
            "Kullanıcıları Listele")
                list_users
                ;;
            "Kullanıcı Güncelle")
                update_user
                ;;
            "Kullanıcı Sil")
                delete_user
                ;;
            "Program Yönetimi")
                program_management_menu
                ;;
            "Hata Kayıtlarını Görüntüle")
                view_error_logs
                ;;
            "Hesap Kilidini Aç")
                unlock_user
                ;;
            "Çıkış"|"")
                if zenity --question --text="Çıkmak istediğinize emin misiniz?" --width=300; then
                    exit 0
                fi
                ;;
        esac
    done
}

# Ana program
main() {
    check_files

    while true; do
        if login; then
            if [ "$USER_ROLE" == "yonetici" ]; then
                admin_menu
            else
                user_menu
            fi
        fi
    done
}

# Programı başlat
main
