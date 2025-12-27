%% Alerjen Tespit Sistemi - Otomatik Test Senaryosu
% Bu script, sistemin farklı çözünürlüklerde ve ölçeklerde doğru çalışıp çalışmadığını doğrular.

clear all; clc;

fprintf('--- ALERJEN SISTEMI TESTI BASLATILDI ---\n');

% 1. Nesneyi Oluştur
try
    detector = AllergenDetector();
    fprintf('[OK] AllergenDetector sınıfı başarıyla başlatıldı.\n');
catch ME
    fprintf('[HATA] AllergenDetector başlatılamadı: %s\n', ME.message);
end

% 2. Sahte Metin Testi (Matching Algoritması Doğrulaması)
% "whey" içinde "hey" geçmesi durumunu test edelim
testOCR.Words = {'whey', 'protein', 'hey', 'süt', 'fındıklı', 'et'};
testOCR.WordBoundingBoxes = ones(length(testOCR.Words), 4);
testOCR.WordConfidences = ones(length(testOCR.Words), 1);

fprintf('\n[TEST] Matching ve False Positive Koruması Kontrolü...\n');
detected = detector.matchAllergens(testOCR);

% "hey" alerjen değil, "et" çok kısa olduğu için "etiket" (içinde geçse bile) riskli.
% Bizim veritabanımızda "et" yok ama mantığı kontrol edelim.
foundWords = {detected.Word};
fprintf('  Tespit edilen kelimeler: %s\n', strjoin(foundWords, ', '));

% "süt" ve "fındıklı" (fındık içerdiği için) tespit edilmeli.
% "hey" tespit edilmemeli (sınır kontrolü).
if ismember('süt', foundWords) && ismember('fındıklı', foundWords)
    fprintf('[OK] Alerjenler başarıyla yakalandı.\n');
else
    fprintf('[HATA] Bazı alerjenler kaçırıldı.\n');
end

if ismember('hey', foundWords)
    fprintf('[HATA] "hey" hatalı olarak yakalandı (False Positive)!\n');
else
    fprintf('[OK] "hey" gibi kısa/hatalı kelimeler elendi.\n');
end

% 3. Koordinat Dönüşüm Testi (Multi-scale OCR Logik)
fprintf('\n[TEST] Çoklu Ölçekli OCR Yapısı Kontrolü...\n');
dummyImg = uint8(255 * ones(100, 100)); % Küçük beyaz resim
try
    [ocrRes, ~, ~] = extractTextAdvanced(dummyImg);
    fprintf('[OK] extractTextAdvanced fonksiyonu çalışıyor.\n');
catch ME
    fprintf('[HATA] extractTextAdvanced hatası: %s\n', ME.message);
end

fprintf('\n--- TEST TAMAMLANDI ---\n');
