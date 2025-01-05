#!/bin/bash

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Sabit değişkenler
readonly DEPO_CSV="depo.csv"
readonly KULLANICI_CSV="kullanici.csv"
readonly LOG_CSV="log.csv"
readonly YEDEK_DIZINI="yedekler"
readonly KATEGORI_CSV="kategori.csv"
readonly MAX_LOGIN_ATTEMPTS=3
readonly STOK_ESIK=10
readonly YUKSEK_STOK_ESIK=100

# Genel değişkenler
declare CURRENT_USER=""
declare CURRENT_ROLE=""

# Yardımcı fonksiyonlar
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_kayit "9999" "${CURRENT_USER:-anonim}" "Program beklenmedik şekilde sonlandı (Kod: $exit_code)"
    fi
    exit $exit_code
}

trap cleanup EXIT
trap 'exit 1' INT TERM

# Dosya kilitleme
lock_file() {
    local lockfile=$1.lock
    if ! mkdir "$lockfile" 2>/dev/null; then
        echo "Dosya kilidi alınamadı: $1" >&2
        return 1
    fi
}

unlock_file() {
    local lockfile=$1.lock
    rmdir "$lockfile" 2>/dev/null || true
}

# Progress bar gösterimi
show_progress() {
    local message=$1
    (
    echo "10"; sleep 0.5
    echo "30"; sleep 0.5
    echo "50"; sleep 0.5
    echo "70"; sleep 0.5
    echo "100"; sleep 0.5
    ) | zenity --progress \
        --title="İşlem Sürüyor" \
        --text="$message" \
        --percentage=0 \
        --auto-close \
        --width=300
}

# Dosya kontrolü
dosya_kontrol() {
    local default_files=(
        "$DEPO_CSV:600"
        "$KULLANICI_CSV:600"
        "$LOG_CSV:600"
        "$KATEGORI_CSV:600"
    )

    for file_info in "${default_files[@]}"; do
        local file="${file_info%%:*}"
        local perms="${file_info##*:}"
        
        if [ ! -f "$file" ]; then
            touch "$file"
            chmod "$perms" "$file"
            
            case "$file" in
                "$KULLANICI_CSV")
                    echo "1,admin,admin,yonetici,$(echo -n "admin" | md5sum | cut -d' ' -f1),0" > "$file"
                    ;;
                "$KATEGORI_CSV")
                    {
                        echo "1,Elektronik"
                        echo "2,Gıda"
                        echo "3,Kırtasiye"
                        echo "4,Ev Eşyaları"
                        echo "5,Giysi"
                    } > "$file"
                    ;;
                "$DEPO_CSV")
                    echo "UrunNo,UrunAdi,StokMiktari,BirimFiyat,Kategori" > "$file"
                    ;;
            esac
        fi
    done

    mkdir -p "$YEDEK_DIZINI"
    chmod 700 "$YEDEK_DIZINI"
}

# Log kaydı
log_kayit() {
    local hata_no=$1
    local kullanici=$2
    local mesaj=$3
    local zaman=$(date '+%Y-%m-%d %H:%M:%S')
    
    lock_file "$LOG_CSV"
    printf "%s,%s,%s,%s\n" "$hata_no" "$zaman" "$kullanici" "$mesaj" >> "$LOG_CSV"
    unlock_file "$LOG_CSV"
}

# Kullanıcı girişi
giris_kontrol() {
    local username password md5_pass user_info

    username=$(zenity --entry \
        --title="Giriş" \
        --text="Kullanıcı Adı:" \
        --width=300)
    
    if [ -z "$username" ]; then exit 0; fi

    password=$(zenity --password \
        --title="Giriş" \
        --text="Şifre:" \
        --width=300)
    
    if [ -z "$password" ]; then exit 0; fi

    if [[ "$username" =~ [,\'\"] || "$password" =~ [,\'\"] ]]; then
        zenity --error \
            --text="Geçersiz karakterler içeriyor!" \
            --width=300
        return 1
    fi

    md5_pass=$(echo -n "$password" | md5sum | cut -d' ' -f1)
    
    lock_file "$KULLANICI_CSV"
    user_info=$(grep "^[^,]*,$username," "$KULLANICI_CSV")
    
    if [ -n "$user_info" ]; then
        local id user_name user_surname role stored_pass attempts
        IFS=',' read -r id user_name user_surname role stored_pass attempts <<< "$user_info"
        
        if [ "$attempts" -ge $MAX_LOGIN_ATTEMPTS ]; then
            unlock_file "$KULLANICI_CSV"
            zenity --error \
                --text="Hesabınız kilitlenmiştir. Yönetici ile iletişime geçin." \
                --width=300
            log_kayit "1001" "$username" "Kilitli hesaba giriş denemesi"
            return 1
        fi

        if [ "$stored_pass" == "$md5_pass" ]; then
            sed -i "s/^$id,$username,$user_surname,$role,$stored_pass,[0-9]*/$id,$username,$user_surname,$role,$stored_pass,0/" "$KULLANICI_CSV"
            unlock_file "$KULLANICI_CSV"
            export CURRENT_USER="$username"
            export CURRENT_ROLE="$role"
            return 0
        else
            local new_attempts=$((attempts + 1))
            sed -i "s/^$id,$username,$user_surname,$role,$stored_pass,[0-9]*/$id,$username,$user_surname,$role,$stored_pass,$new_attempts/" "$KULLANICI_CSV"
            unlock_file "$KULLANICI_CSV"
            
            if [ "$new_attempts" -ge $MAX_LOGIN_ATTEMPTS ]; then
                zenity --error \
                    --text="Hesabınız kilitlenmiştir. Yönetici ile iletişime geçin." \
                    --width=300
                log_kayit "1002" "$username" "Hesap kilitlendi"
            else
                zenity --warning \
                    --text="Hatalı şifre! Kalan deneme hakkı: $((MAX_LOGIN_ATTEMPTS-new_attempts))" \
                    --width=300
                log_kayit "1003" "$username" "Hatalı şifre denemesi"
            fi
            return 1
        fi
    else
        unlock_file "$KULLANICI_CSV"
        zenity --error \
            --text="Kullanıcı bulunamadı!" \
            --width=300
        log_kayit "1004" "$username" "Kullanıcı bulunamadı"
        return 1
    fi
}

# Yetki kontrolü
yetki_kontrol() {
    if [ "$CURRENT_ROLE" != "yonetici" ]; then
        zenity --error \
            --text="Bu işlem için yetkiniz bulunmamaktadır!" \
            --width=300
        return 1
    fi
    return 0
}

# Ürün ekleme
urun_ekle() {
    if ! yetki_kontrol; then return 1; fi

    local form_data
    form_data=$(zenity --forms \
        --title="Ürün Ekle" \
        --text="Ürün Bilgileri" \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-combo="Kategori" \
        --combo-values="Elektronik|Gıda|Kırtasiye|Ev Eşyaları|Giysi" \
        --width=400)

    if [ -z "$form_data" ]; then return 1; fi

    IFS='|' read -r urun_adi stok_miktari birim_fiyat kategori <<< "$form_data"

    # Veri doğrulama
    if [[ "$urun_adi" =~ [[:space:]] ]]; then
        zenity --error --text="Ürün adında boşluk olamaz!" --width=300
        return 1
    fi

    if ! [[ "$stok_miktari" =~ ^[0-9]+$ ]] || ! [[ "$birim_fiyat" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; then
        zenity --error --text="Geçersiz stok miktarı veya birim fiyat!" --width=300
        return 1
    fi

    # Ürün kontrolü
    if grep -q ",[^,]*$urun_adi," "$DEPO_CSV"; then
        zenity --error \
            --text="Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz." \
            --width=300
        return 1
    fi

    local urun_no
    urun_no=$(tail -n1 "$DEPO_CSV" 2>/dev/null | awk -F',' '{print $1+1}' || echo 1)

    show_progress "Ürün ekleniyor..."

    echo "$urun_no,$urun_adi,$stok_miktari,$birim_fiyat,$kategori" >> "$DEPO_CSV"

    zenity --info \
        --text="Ürün başarıyla eklendi!" \
        --width=300
}


    

# Ürün listeleme
urun_listele() {
    local temp_file=$(mktemp)
    echo -e "Ürün No\tÜrün Adı\tStok\tFiyat\tKategori" > "$temp_file"
    tail -n +2 "$DEPO_CSV" | sed 's/,/\t/g' >> "$temp_file"

    zenity --text-info \
        --title="Ürün Listesi" \
        --filename="$temp_file" \
        --width=600 --height=400

    rm "$temp_file"
}

# Ürün güncelleme
urun_guncelle() {
    if ! yetki_kontrol; then return 1; fi

    local urun_adi
    urun_adi=$(zenity --entry \
        --title="Ürün Güncelle" \
        --text="Güncellenecek ürünün adını girin:" \
        --width=300)

    if [ -z "$urun_adi" ]; then return 1; fi

    local urun_satiri
    urun_satiri=$(grep ",[^,]*$urun_adi," "$DEPO_CSV")

    if [ -z "$urun_satiri" ]; then
        zenity --error --text="Ürün bulunamadı!" --width=300
        return 1
    fi

    IFS=',' read -r id old_ad old_stok old_fiyat old_kategori <<< "$urun_satiri"

    local form_data
    form_data=$(zenity --forms \
        --title="Ürün Güncelle" \
        --text="Yeni bilgileri girin:" \
        --add-entry="Stok Miktarı [$old_stok]" \
        --add-entry="Birim Fiyat [$old_fiyat]" \
        --add-combo="Kategori [$old_kategori]" \
        --combo-values="Elektronik|Gıda|Kırtasiye|Ev Eşyaları|Giysi" \
        --width=400)

    if [ -z "$form_data" ]; then return 1; fi

    IFS='|' read -r yeni_stok yeni_fiyat yeni_kategori <<< "$form_data"

    # Veri doğrulama
    if ! [[ "$yeni_stok" =~ ^[0-9]+$ ]] || ! [[ "$yeni_fiyat" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; then
        zenity --error --text="Geçersiz stok miktarı veya birim fiyat!" --width=300
        return 1
    fi

    show_progress "Ürün güncelleniyor..."

    sed -i "s/^$id,$old_ad,$old_stok,$old_fiyat,$old_kategori/$id,$old_ad,$yeni_stok,$yeni_fiyat,$yeni_kategori/" "$DEPO_CSV"

    zenity --info \
        --text="Ürün başarıyla güncellendi!" \
        --width=300
}

# Ürün silme
urun_sil() {
    if ! yetki_kontrol; then return 1; fi

    local urun_adi
    urun_adi=$(zenity --entry \
        --title="Ürün Sil" \
        --text="Silinecek ürünün adını girin:" \
        --width=300)

    if [ -z "$urun_adi" ]; then return 1; fi

    if ! grep -q ",[^,]*$urun_adi," "$DEPO_CSV"; then
        zenity --error --text="Ürün bulunamadı!" --width=300
        return 1
    fi

    if ! zenity --question \
        --text="$urun_adi ürününü silmek istediğinizden emin misiniz?" \
        --width=300; then
        return 1
    fi

    show_progress "Ürün siliniyor..."

    sed -i "/,[^,]*$urun_adi,/d" "$DEPO_CSV"

    zenity --info \
        --text="Ürün başarıyla silindi!" \
        --width=300
}

# Rapor alma
rapor_menu() {
    local secim
    secim=$(zenity --list \
        --title="Rapor Al" \
        --text="Rapor türünü seçin:" \
        --column="Rapor Türü" \
        "Stokta Azalan Ürünler" \
            "En Yüksek Stok Miktarına Sahip Ürünler" \
    --width=400 --height=300)

    case "$secim" in
        "Stokta Azalan Ürünler")
            stokta_azalan_urunler
            ;;
        "En Yüksek Stok Miktarına Sahip Ürünler")
            yuksek_stok_urunler
            ;;
        *)
            zenity --error --text="Geçersiz seçim!" --width=300
            ;;
    esac
}

stokta_azalan_urunler() {
    local temp_file=$(mktemp)
    echo -e "Ürün No\tÜrün Adı\tStok\tKategori" > "$temp_file"
    awk -F',' -v stok_esik=$STOK_ESIK 'NR > 1 && $3 < stok_esik { print $1 "\t" $2 "\t" $3 "\t" $5 }' "$DEPO_CSV" >> "$temp_file"

    zenity --text-info \
        --title="Stokta Azalan Ürünler" \
        --filename="$temp_file" \
        --width=600 --height=400

    rm "$temp_file"
}

yuksek_stok_urunler() {
    local temp_file=$(mktemp)
    echo -e "Ürün No\tÜrün Adı\tStok\tKategori" > "$temp_file"
    awk -F',' -v yuksek_stok_esik=$YUKSEK_STOK_ESIK 'NR > 1 && $3 > yuksek_stok_esik { print $1 "\t" $2 "\t" $3 "\t" $5 }' "$DEPO_CSV" >> "$temp_file"

    zenity --text-info \
        --title="En Yüksek Stok Miktarına Sahip Ürünler" \
        --filename="$temp_file" \
        --width=600 --height=400

    rm "$temp_file"
}

# Main function to start the menu
main_menu() {
    while true; do
        local secim
        secim=$(zenity --list \
            --title="Ana Menü" \
            --text="Bir işlem seçin:" \
            --column="İşlemler" \
            "Ürün Ekle" \
            "Ürün Listele" \
            "Ürün Güncelle" \
            "Ürün Sil" \
            "Rapor Al" \
            "Çıkış" \
            --width=400 --height=300)

        case "$secim" in
            "Ürün Ekle")
                urun_ekle
                ;;
            "Ürün Listele")
                urun_listele
                ;;
            "Ürün Güncelle")
                urun_guncelle
                ;;
            "Ürün Sil")
                urun_sil
                ;;
            "Rapor Al")
                rapor_menu
                ;;
            "Çıkış")
                break
                ;;
            *)
                zenity --error --text="Geçersiz seçim!" --width=300
                ;;
        esac
    done
}

# Program starts here
dosya_kontrol
giris_kontrol
main_menu



