
% debug_allergen.m
% Bu script, belirli bir resim üzerinde OCR sonuçlarını ve eşleşmeleri detaylı analiz eder.

% 1. Dosya yolu
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';

if ~exist(imagePath, 'file')
    error('Görsel bulunamadı: %s', imagePath);
end

fprintf('Analiz edilen dosya: %s\n', imagePath);

% 2. Dedektör başlat
detector = AllergenDetector();
fprintf('Dedektör başlatıldı.\n');

% 3. Manuel İşlem Adımları (detector.processImage içini açıyoruz)
rawImg = imread(imagePath);

% Preprocessing
% Access private method via a trick or just copy logic? 
% AllergenDetector metodları private değilse direkt çağırabiliriz ama processImage her şeyi yapıyor.
% Ancak debug için internal adımları görmek istiyoruz.
% Preprocess metodunu public yapmadığımız için preprocessImage.m'i manuel çağıracağız.
% Dedektör preprocessImage.m'i kullanıyor gibi görünüyor kodda: "Mevcut preprocessImage.m mantığını kullanır" diyor ama
% aslında kendi içinde private preprocess metodu var. Kodda 44. satırda private preprocess metodu var.
% Ama 28. satırda "obj.preprocess(rawImg)" çağırıyor.
% preprocessImage.m dosyası var ama detector onu çağırmıyor, kendi içindeki private metodu kullanıyor.
% Kendi içindeki metod büyük ölçüde preprocessImage.m ile aynı olabilir ama farklar olabilir.
% Biz dışarıdaki preprocessImage.m'i kullanalım çünkü muhtemelen aynı mantık.
% Veya detector'ü modifiye etmemek için, processImage metodunu kullanıp OCR sonuçlarını alamayız çünkü o sadece detected döndürüyor (ve annotatedImg).
% DUR! processImage metodu: [annotatedImg, detected] dönüyor. OCR ham sonuçlarını dönemiyor.
% Bu yüzden extractTextAdvanced'i manuel çalıştıracağız.

% Preprocessing (preprocessImage.m kullanarak)
% preprocessImage.m bir script, fonksiyon değil. Bu kötü.
% Ama preprocessImage.m içeriğine baktım, script olarak yazılmış.
% AllergenDetector.m içindeki preprocess metodu ise fonksiyon.
% İçerik benzer: rgb2gray, imflatfield, imadjust, binarize.
% Biz AllergenDetector.m içindeki mantığı simüle edelim.

fprintf('--- Önişleme Başlıyor ---\n');
if size(rawImg, 3) == 3, gray = rgb2gray(rawImg); else, gray = rawImg; end
try
    corrected = imflatfield(gray, 30);
catch
    corrected = gray;
    fprintf('Uyarı: imflatfield kullanılamadı.\n');
end
corrected = imadjust(corrected, stretchlim(corrected, [0.02 0.98]), []);
level = graythresh(corrected);
bw = imbinarize(corrected, level);
if mean(bw(:)) < 0.5, bw = ~bw; end
bw = bwareaopen(bw, 15);
processedImg = bw;
fprintf('Önişleme tamamlandı.\n');

% 4. OCR
fprintf('--- OCR Başlıyor ---\n');
[ocrResults, allWords, allBoxes] = extractTextAdvanced(processedImg);
fprintf('OCR tamamlandı. Toplam %d kelime bulundu.\n', length(allWords));

% 5. OCR Sonuçlarını Listele
fprintf('\n--- Bulunan Kelimeler (İlk 50) ---\n');
for i = 1:min(length(allWords), 50)
    fprintf('%d: %s (Conf: %.2f)\n', i, allWords{i}, ocrResults.WordConfidences(i));
end

% 6. Eşleştirme Testi
detected = detector.matchAllergens(ocrResults);

fprintf('\n--- Tespit Edilen Alerjenler ---\n');
if isempty(detected)
    fprintf('HİÇBİR ALERJEN TESPİT EDİLEMEDİ!\n');
else
    for i = 1:length(detected)
        fprintf('Bulunan: %s (Kategori: %s)\n', detected(i).Word, detected(i).Category);
    end
end

% 7. Neden Eşleşmedi? (Detaylı Analiz)
% Eğer tespit yoksa, beklenen kelimeleri manuel kontrol et
fprintf('\n--- Detaylı Kelime Kontrolü ---\n');
keywordsToCheck = {'gluten', 'buğday', 'süt', 'soya', 'fıstık', 'yumurta'};
for k = 1:length(keywordsToCheck)
    key = keywordsToCheck{k};
    fprintf('Aranıyor: "%s" ...\n', key);
    found = false;
    for i = 1:length(allWords)
        word = lower(char(allWords{i}));
        if contains(word, key) || contains(word, 'bugday') || contains(word, 'sut')
            fprintf('  -> Eşleşme ADAYI bulundu: "%s" (Conf: %.2f)\n', word, ocrResults.WordConfidences(i));
            found = true;
        end
    end
    if ~found
        fprintf('  -> Kelime OCR çıktısında hiç yok.\n');
    end
end
