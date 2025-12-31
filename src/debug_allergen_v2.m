% debug_allergen_v2.m - AllergenDetector Debug Scripti (v2)
clear classes; % Sınıf güncellemelerini zorla
clear;
clc;
% Bu script, AllergenDetector üzerindeki değişiklikleri (Rotasyon + Adaptive Threshold)
% uçtan uca test eder.

imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';

if ~exist(imagePath, 'file')
    error('Görsel bulunamadı: %s', imagePath);
end

fprintf('Test edilen dosya: %s\n', imagePath);

% 1. Dedektör başlat
fprintf('Dedektör başlatılıyor...\n');
detector = AllergenDetector();

% 2. İşlemi Çalıştır (Process Image - Rotation dahil)
fprintf('Görüntü işleniyor (processImage)...\n');
try
    % Görüntü işleme ve OCR (Düzeltildi: Dönüş değerleri ayrıştırıldı)
    [annotatedImg, detectedStruct, ocrResults] = detector.processImage(imagePath);

    % detectedStruct zaten processImage içinde hesaplandı!
    % matchAllergens tekrar çağırmaya gerek yok ama debug çıktısı için çağırabiliriz
    % verifyResults(detectedStruct);
    
    fprintf('İşlem tamamlandı.\n');

    % --- DETEKSİYON SONUÇLARINI YAZDIR (ÖNCE) ---
    fprintf('\n--- TESPIT EDILEN ALERJENLER (detectedStruct) ---\n');
    
    if isempty(detectedStruct)
        fprintf('  [!] Hiçbir alerjen tespit edilemedi (fonksiyon çıkışı).\n');
    else
        fprintf('  Tespit edilenler listesi (%d adet):\n', length(detectedStruct));
        for i = 1:length(detectedStruct)
            d = detectedStruct(i);
            fprintf('  - %s -> %s (Conf: %.2f)\n', d.Word, d.Category, d.Confidence);
        end
    end

    fprintf('\n--- HAM OCR SONUÇLARI (İlk 50) ---\n');
    try
        if isfield(ocrResults, 'Words')
            words = ocrResults.Words;
            for k = 1:min(length(words), 50)
                try
                    if iscell(words)
                        wVal = words{k};
                    else
                        wVal = words(k);
                    end
                    fprintf('%d: %s (Conf: %.2f)\n', k, wVal, ocrResults.WordConfidences(k));
                catch
                    fprintf('%d: (Yazdirilamadi)\n', k);
                end
            end
        end
    catch
        fprintf('  OCR sonuclari yazdirilamadi.\n');
    end
    
catch ME
    fprintf('HATA OLUŞTU:\n%s\n', ME.message);
    fprintf('Dosya: %s\nSatır: %d\n', ME.stack(1).file, ME.stack(1).line);
end
