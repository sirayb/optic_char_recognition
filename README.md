# Alerjen Tespit Sistemi (MATLAB)

Gıda paketleri üzerindeki içerik listelerini analiz ederek, potansiyel alerjenleri otomatik olarak tespit eden ve kullanıcıyı uyaran gelişmiş bir görüntü işleme ve OCR (Optik Karakter Tanıma) sistemidir.

## 🌟 Özet
Bu proje, son kullanıcı deneyimini ve teknik mükemmelliği ön planda tutan bir mühendislik çalışmasıdır. Sistem, karmaşık gıda etiketlerini saniyeler içinde tarayarak alerjen bilgilerini görselleştirir.

## ✨ Özellikler
- **Gelişmiş OCR:** MATLAB'ın güçlü OCR yeteneklerini kullanarak, farklı font ve boyutlardaki metinleri yüksek doğrulukla okur.
- **Kapsamlı Veritabanı:** Türkiye Gıda Kodeksi'ne uygun, 30'dan fazla kategoride (Süt, Gluten, Fındık, Soya, Sülfit vb.) binlerce terim içeren dinamik alerjen kütüphanesi.
- **Dinamik GUI (Arayüz):** 
  - Orijinal ve analiz edilmiş görselleri yan yana gösteren profesyonel ekran.
  - Veritabanındaki tüm kategorileri otomatik listeleyen ve kaydırılabilen seçim paneli.
  - Canlı süreç takibi sağlayan durum çubuğu.
- **Akıllı Filtreleme:** Sadece seçtiğiniz alerjenleri tarayarak size özel sonuçlar üretir.
- **Hata Yönetimi:** Kullanıcı dostu uyarı pencereleri ve güvenli çalışma akışı.

## 🛠️ Teknik Altyapı
- **Dil:** MATLAB
- **Araç Kutuları (Toolboxes):** Computer Vision Toolbox, Image Processing Toolbox, Text Analytics Toolbox (OCR için).
- **Mimari:** Nesne Yönelimli Programlama (AllergenDetector sınıfı üzerine kurulu).

## 🚀 Başlangıç

### Gereksinimler
- MATLAB R2021a veya daha yeni bir sürüm.
- Gerekli Toolbox'ların yüklü olması.

### Kurulum
1. Repoyu bilgisayarınıza indirin.
2. MATLAB'da proje klasörüne (`optic_char_recognition`) gidin.
3. `src` klasörünü yolunuza ekleyin: `addpath(genpath(pwd))`.

### Kullanım
Uygulamayı başlatmak için MATLAB Komut Penceresi'ne (Command Window) şunu yazın:

```matlab
AllergenApp
```

Açılan pencerede:
1. **"Resim Seç..."** butonuna basarak bir gıda etiketi fotoğrafı yükleyin.
2. Taranmasını istediğiniz alerjenleri listeden işaretleyin.
3. **"Sistemi Çalıştır"** butonuna basarak analizi başlatın.

## 📂 Proje Yapısı
- `src/AllergenApp.m`: Modern GUI (Arayüz) dosyası.
- `src/AllergenDetector.m`: Görüntü işleme ve analizden sorumlu ana sınıf (Backend).
- `src/createAllergenDatabase.m`: Devasa alerjen kütüphanesini oluşturan fonksiyon.
- `src/run_allergen_system.m`: Sistem testleri için kullanılan script versiyonu.
- `data/samples/`: Test için kullanabileceğiniz örnek gıda etiketi fotoğrafları.

---
*Bu proje, son kullanıcının hayatını kolaylaştırmak ve gıda güvenliğini artırmak için geliştirilmiştir.* 🚀
