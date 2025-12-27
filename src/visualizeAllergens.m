% visualizeAllergens.m
% Tespit edilen alerjenleri görüntü üzerinde kırmızı kutularla işaretler
% GEVŞEK EŞLEŞME (Loose Matching) ile yeniden yazıldı

%% 1) Workspace Kontrolü
if ~exist('ocrResults', 'var')
    error('ocrResults degiskeni bulunamadi! Once extractTextAdvanced.m calistirin.');
end

if ~exist('detectedList', 'var') || isempty(detectedList)
    warning('detectedList bulunamadi veya bos. Hicbir alerjen tespit edilmemis.');
    fprintf('Sadece OCR kutularini gosterecegim (debug modu).\n');
    showDebugMode = true;
else
    showDebugMode = false;
end

fprintf('\n========== GORSEL ISARETLEME BASLADI (LOOSE MATCHING) ==========\n');

%% 2) Görüntü Seçimi (ÖNCELİK: Orijinal renkli)
if exist('img', 'var')
    baseImage = img;
    fprintf('Orijinal renkli goruntu (img) kullaniliyor.\n');
elseif exist('processedImg', 'var')
    baseImage = processedImg;
    fprintf('UYARI: Islennis goruntu kullaniliyor (renkli goruntu bulunamadi).\n');
    
    if islogical(baseImage)
        baseImage = im2uint8(baseImage);
    end
    
    if size(baseImage, 3) == 1
        baseImage = cat(3, baseImage, baseImage, baseImage);
    end
else
    error('img veya processedImg degiskeni bulunamadi!');
end

fprintf('Goruntu boyutu: %d x %d\n', size(baseImage, 1), size(baseImage, 2));

%% 4) Dinamik Ölçeklendirme ve Koordinat Dönüşümü
resimYukseklik = size(baseImage, 1);
resimGenislik = size(baseImage, 2);

% Dinamik Çizim Parametreleri
lineWidth = max(2, round(resimYukseklik / 300)); 
fontSize = max(10, round(resimYukseklik / 80));

fprintf('Dinamik Parametreler: LineWidth=%d, FontSize=%d (Resim: %dx%d)\n', ...
    lineWidth, fontSize, resimGenislik, resimYukseklik);

% Otomatik Koordinat Dönüşüm Oranı (scaleMultiplier)
% OCR'ın yapıldığı scaledImg boyutu ile üzerine çizim yapılan baseImage boyutu arasındaki oran
if exist('scaledImg', 'var')
    ocrImageHeight = size(scaledImg, 1);
    scaleMultiplier = resimYukseklik / ocrImageHeight;
    fprintf('Otomatik Koordinat Donusumu: scaleMultiplier=%.4f (scaledImg=%d px -> baseImage=%d px)\n', ...
        scaleMultiplier, ocrImageHeight, resimYukseklik);
elseif exist('scaleBeforeOCR', 'var')
    scaleMultiplier = 1 / scaleBeforeOCR;
    fprintf('UYARI: scaledImg bulunamadi, scaleBeforeOCR kullaniliyor. scaleMultiplier=%.4f\n', scaleMultiplier);
else
    scaleMultiplier = 1.0;
    fprintf('UYARI: Olcek bilgisi bulunamadi, 1.0 kullaniliyor.\n');
end

ocrWords = ocrResults.Words;
ocrBoxes = ocrResults.WordBoundingBoxes;

% Koordinatları scaleMultiplier ile dönüştür
correctedBoxes = ocrBoxes * scaleMultiplier;
fprintf('Bounding box koordinatlari %d kelime icin donusturuldu.\n', length(ocrWords));

fprintf('OCR toplam kelime sayisi: %d\n', length(ocrWords));

%% 5) Alerjen Listesini Normalize Et
if ~showDebugMode
    fprintf('\nDetected list icerigi (%d terim):\n', length(detectedList));
    for i = 1:min(5, length(detectedList))
        fprintf('  %d) "%s"\n', i, detectedList{i});
    end
    if length(detectedList) > 5
        fprintf('  ... ve %d terim daha\n', length(detectedList) - 5);
    end
    
    % detectedList'ten sadece terim kısmını al (format: "Kategori: terim")
    allergenTerms = {};
    for i = 1:length(detectedList)
        term = detectedList{i};
        if contains(term, ':')
            parts = strsplit(term, ':');
            term = strtrim(parts{end});
        end
        
        % Normalize et
        termNorm = lower(term);
        termNorm = strrep(termNorm, 'ı', 'i');
        termNorm = strrep(termNorm, 'ğ', 'g');
        termNorm = strrep(termNorm, 'ü', 'u');
        termNorm = strrep(termNorm, 'ş', 's');
        termNorm = strrep(termNorm, 'ö', 'o');
        termNorm = strrep(termNorm, 'ç', 'c');
        
        allergenTerms{end+1} = termNorm;
    end
    
    fprintf('\nNormalize edilmis alerjen terimleri:\n');
    for i = 1:min(5, length(allergenTerms))
        fprintf('  - "%s"\n', allergenTerms{i});
    end
    fprintf('\n');
end

%% 6) GEVŞEK EŞLEŞME - OCR Kelimelerini Tara
allergenBoxes = [];
allergenLabels = {};
matchCount = 0;

fprintf('--- GEVŞEK EŞLEŞME ALGORITMASI (DEBUG MODU) ---\n');

for i = 1:length(ocrWords)
    ocrWord = char(ocrWords{i});
    ocrWordLower = lower(ocrWord);
    
    % Normalize et
    ocrWordNorm = strrep(ocrWordLower, 'ı', 'i');
    ocrWordNorm = strrep(ocrWordNorm, 'ğ', 'g');
    ocrWordNorm = strrep(ocrWordNorm, 'ü', 'u');
    ocrWordNorm = strrep(ocrWordNorm, 'ş', 's');
    ocrWordNorm = strrep(ocrWordNorm, 'ö', 'o');
    ocrWordNorm = strrep(ocrWordNorm, 'ç', 'c');
    
    % Noktalama işaretlerini temizle
    ocrWordClean = regexprep(ocrWordNorm, '[.,;:()!?]', '');
    
    % OCR kaynaklı boşlukları sil
    ocrWordClean = strrep(ocrWordClean, ' ', '');
    
    % Çok kısa kelimeleri atla
    if length(ocrWordClean) < 3
        continue;
    end
    
    % Debug modu - sadece OCR kutularını göster
    if showDebugMode
        continue;
    end
    
    % Alerjen listesiyle karşılaştır
    isAllergen = false;
    matchedTerm = '';
    
    for j = 1:length(allergenTerms)
        allergenTerm = allergenTerms{j};
        allergenTermClean = strrep(allergenTerm, ' ', '');
        
        % Minimum uzunluk kontrolü - çok kısa terimler atla
        if length(allergenTermClean) < 3
            continue;
        end
        
        % 1) TEK YÖNLÜ EŞLEŞME: OCR kelimesi içinde alerjen geçiyor mu?
        % (ters kontrol kaldırıldı - "Türk" != "türk fındığı")
        if contains(ocrWordClean, allergenTermClean)
            isAllergen = true;
            matchedTerm = allergenTerm;
            fprintf('  [%d] ESLESTI! OCR: "%s" -> Alerjen: "%s"\n', i, ocrWord, allergenTerm);
            break;
        end
        
        % 2) WILDCARD REGEX: "s.t" yazımı için regex
        % "fındık" -> "f.{0,1}n.{0,1}d.{0,1}k" patternına dönüştür
        % Türkçe karakter toleransı: süt -> s[uü]t
        regexPattern = allergenTermClean;
        regexPattern = strrep(regexPattern, 'u', '[uü]');
        regexPattern = strrep(regexPattern, 'i', '[iı]');
        regexPattern = strrep(regexPattern, 'o', '[oö]');
        regexPattern = strrep(regexPattern, 's', '[sş]');
        regexPattern = strrep(regexPattern, 'c', '[cç]');
        regexPattern = strrep(regexPattern, 'g', '[gğ]');
        regexPattern = ['.*' regexPattern '.*'];
        
        if ~isempty(regexp(ocrWordClean, regexPattern, 'once'))
            isAllergen = true;
            matchedTerm = allergenTerm;
            fprintf('  [%d] ESLESTI (Regex-Tolerant)! OCR: "%s" ~ Alerjen: "%s"\n', i, ocrWord, allergenTerm);
            break;
        end
    end
    
    % Eşleşme yoksa debug yazdır (ilk 10 kelime için)
    if ~isAllergen && matchCount < 10
        fprintf('  [%d] Eslesme YOK: OCR: "%s" (normalize: "%s")\n', i, ocrWord, ocrWordClean);
    end
    
    % Eşleşme bulunduysa kaydet
    if isAllergen
        allergenBoxes = [allergenBoxes; correctedBoxes(i, :)];
        allergenLabels{end+1} = upper(ocrWord);
        matchCount = matchCount + 1;
    end
end

fprintf('\n>>> Toplam eslesme: %d alerjen kelimesi\n', matchCount);

% DEBUG: Bounding box koordinatlarını kontrol et
if matchCount > 0
    fprintf('\n--- BOUNDING BOX KOORDINATLARI (DEBUG) ---\n');
    fprintf('Goruntu boyutu: %d x %d\n', size(baseImage, 2), size(baseImage, 1));
    for i = 1:min(5, matchCount)
        fprintf('  Kutu %d: [X=%d, Y=%d, W=%d, H=%d] - "%s"\n', ...
            i, round(allergenBoxes(i,1)), round(allergenBoxes(i,2)), ...
            round(allergenBoxes(i,3)), round(allergenBoxes(i,4)), allergenLabels{i});
    end
    if matchCount > 5
        fprintf('  ... ve %d kutu daha\n', matchCount - 5);
    end
end
fprintf('\n');

%% 7) Görselleştirme
annotatedImage = baseImage;

% (Çizim parametreleri yukarıda dinamik olarak hesaplandı)

if showDebugMode || matchCount == 0
    % DEBUG MODU: Tüm OCR kutularını mavi renkte göster
    fprintf('\n!!! DEBUG MODU: Tum OCR kutuları mavi renkte ciziliyor !!!\n');
    
    if ~isempty(correctedBoxes)
        % Manuel rectangle ile çiz
        fig = figure('Name', 'DEBUG: OCR Kutuları', 'NumberTitle', 'off', 'Position', [50 50 1400 900]);
        imshow(baseImage);
        hold on;
        
        fprintf('\n--- DEBUG: OCR KELIME LISTESI ---\n');
        for i = 1:min(20, length(ocrWords))
            bbox = correctedBoxes(i, :);
            rectangle('Position', bbox, 'EdgeColor', 'b', 'LineWidth', lineWidth/2);
            fprintf('  [%d] "%s" @ [X=%d, Y=%d, W=%d, H=%d]\n', ...
                i, char(ocrWords{i}), round(bbox(1)), round(bbox(2)), round(bbox(3)), round(bbox(4)));
        end
        hold off;
        
        fprintf('>>> %d OCR kutusu mavi renkte cizildi.\n', length(ocrWords));
        fprintf('>>> Bu kutular gorunuyorsa koordinatlar dogru demektir.\n');
    end
    
    fprintf('\n!!! UYARI: Hicbir alerjen isaretlenemedi! !!!\n');
    fprintf('Eger mavi kutular gorunuyorsa:\n');
    fprintf('  1) Koordinatlar dogru\n');
    fprintf('  2) Eslestirme algoritmasi sorunlu\n');
    fprintf('  3) detectedList icerigi kontrol edilmeli\n');
    fprintf('\nOCR kelime ornekleri (ilk 10):\n');
    for i = 1:min(10, length(ocrWords))
        fprintf('  [%d] "%s"\n', i, char(ocrWords{i}));
    end
    fprintf('\n');
    
    assignin('base', 'annotatedImage', getframe(gca).cdata);
    return;
end

% Normal mod - kırmızı kutuları çiz (insertShape ile - daha güvenilir)
fprintf('Kirmizi kutular insertShape ile ciziliyor...\n');

% Tam çözünürlükte kutular çiz
annotatedImage = baseImage;

try
    % Kutu şeffaflığı: Sadece kenarlık çiz, içini boyama (Opacity=0)
    annotatedImage = insertShape(annotatedImage, 'Rectangle', allergenBoxes, ...
        'LineWidth', lineWidth, 'Color', 'red', 'Opacity', 0);
    fprintf('insertShape basarili (LineWidth=%d, Opacity=0).\n', lineWidth);
catch ME
    fprintf('UYARI: insertShape hatasi: %s\n', ME.message);
    fprintf('Alternatif yontem deneniyor...\n');
    annotatedImage = baseImage;
end

% Etiketleri ekle (Kutu içini kapatmamak için metin kutularını da şeffaf yapıyoruz)
labelPositions = allergenBoxes(:, 1:2);
labelPositions(:, 2) = max(lineWidth + 1, labelPositions(:, 2) - fontSize - 5);

try
    % Şeffaf etiket - sadece metin ve kırmızı arka plan (yazının üstünü kapatmaz)
    annotatedImage = insertText(annotatedImage, labelPositions, allergenLabels, ...
        'FontSize', fontSize, 'BoxColor', 'red', 'BoxOpacity', 0.5, ...
        'TextColor', 'white', 'Font', 'Arial Bold', 'AnchorPoint', 'LeftBottom');
    fprintf('Etiketler eklendi (FontSize=%d).\n', fontSize);
catch ME
    fprintf('UYARI: Etiket ekleme hatasi: %s\n', ME.message);
end

fprintf('%d kutu cizildi.\n', matchCount);

%% 8) Sonucu Göster (Ekran Uyumu)
% Kullanıcının ekranına sığması için yüksekliği 800 piksele sabitle
targetDisplayHeight = 800;
displayScale = targetDisplayHeight / size(annotatedImage, 1);
displayImage = imresize(annotatedImage, displayScale);

% Ölçeklendirilmiş versiyonu göster
figure('Name', 'Alerjen Tespiti - Onizleme', 'NumberTitle', 'off', 'Position', [100 100 1000 850]);
imshow(displayImage);
title(sprintf('TEHLIKE: %d Alerjen Kelimesi Isaretlendi! (Ekran Uyumu)', matchCount), ...
    'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('\nEkran gosterimi icin goruntu %d%% olceginde kucultuldu.\n', round(displayScale * 100));
fprintf('Tam cozunurluklu goruntu workspace''te: annotatedImage\n');

fprintf('\n========== GORSEL ISARETLEME TAMAMLANDI ==========\n');

%% 9) Workspace'e Aktar
assignin('base', 'annotatedImage', annotatedImage);
fprintf('\n>>> Tam cozunurluklu goruntu: annotatedImage\n');
fprintf('>>> Kaydetmek icin: imwrite(annotatedImage, ''alerjen_sonuc.png'');\n');

%% 10) İstatistikler
fprintf('\n--- ISARETLEME ISTATISTIKLERI ---\n');
fprintf('OCR kelime sayisi: %d\n', length(ocrWords));
if ~showDebugMode
    fprintf('Alerjen terim sayisi: %d\n', length(allergenTerms));
end
fprintf('Isaretlenen kutu: %d\n', matchCount);
if ~showDebugMode && length(allergenTerms) > 0
    fprintf('Basari orani: %.1f%%\n', (matchCount / length(allergenTerms)) * 100);
end
fprintf('\n');
