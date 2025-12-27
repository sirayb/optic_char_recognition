
% preprocessImage.m
% ROBUST (Kararlı) OCR ön işleme: Işık dengeleme, Otsu threshold, polarite kontrolü
% Tamamen siyah çıktı sorununu çözmek için yeniden yazılmıştır.

%% ===== Ayarlanabilir Parametreler =====
inputFile      = fullfile('data', 'raw', '1766854075235.jpg'); % Giriş dosyası
useFlatfield   = true;      % Işık dengeleme açık/kapalı (true önerilir)
useOtsu        = true;      % Otsu otomatik eşikleme (false ise adaptive kullanır)
adaptiveSens   = 0.5;       % Adaptive için hassasiyet (0.4-0.6 arası)
minPixelArea   = 15;        % Silinecek küçük gürültü boyutu (çok düşük - kelime ayırma için)
resizeFactor   = 2.0;       % OCR için ölçekleme (2x yeterli)

%% 1) Dosya yükleme
if ~exist(inputFile, 'file')
    warning('Dosya bulunamadi: %s', inputFile);
    [fname, fpath] = uigetfile({'*.jpg;*.png;*.tif', 'Gorsel Dosyalari'}, ...
        'Bir etiket fotografi secin', fullfile('data', 'samples'));
    if isequal(fname, 0)
        error('Dosya secilmedi, islem iptal.');
    end
    inputFile = fullfile(fpath, fname);
end

origImg = imread(inputFile);
fprintf('Dosya okundu: %s\n', inputFile);

%% 2) Griye çevir
if size(origImg, 3) == 3
    grayImg = rgb2gray(origImg);
else
    grayImg = origImg;
end

%% 3) IŞIK DENGELEME (Background Correction)
% Düzensiz ışık/gölgeleri temizlemek için en kritik adım
if useFlatfield
    % imflatfield: Işık patlamalarını ve gölgeleri otomatik düzeltir
    correctedImg = imflatfield(grayImg, 30); % 30 = sigma değeri (orta boyutlu arka plan)
    fprintf('Isik dengeleme uygulandı (imflatfield).\n');
else
    correctedImg = grayImg;
end

%% 4) KONTRAST GERME (Contrast Stretching)
% Pikselleri 0-255 aralığına tam yay, beyazlar tam beyaz, siyahlar tam siyah olsun
correctedImg = imadjust(correctedImg, stretchlim(correctedImg, [0.02 0.98]), []);
fprintf('Kontrast germe tamamlandi.\n');

%% 5) THRESHOLD (Eşikleme) - Otsu veya Adaptive
if useOtsu
    % OTSU: Görüntünün histogram dağılımına göre otomatik en iyi eşik bulur
    level = graythresh(correctedImg);
    bwImg = imbinarize(correctedImg, level);
    fprintf('Otsu metodu kullanildi (threshold=%.3f).\n', level);
else
    % ADAPTIVE: Bölgesel farklılıklara göre eşikleme (daha esnek)
    bwImg = imbinarize(correctedImg, 'adaptive', 'Sensitivity', adaptiveSens);
    fprintf('Adaptive threshold kullanildi (sensitivity=%.2f).\n', adaptiveSens);
end

%% 6) POLARİTE KONTROLÜ (Yazılar siyah, zemin beyaz olmalı)
% Eğer görüntünün çoğu siyahsa, tersine çevir
avgBrightness = mean(bwImg(:));
if avgBrightness < 0.5
    bwImg = ~bwImg; % Hızlı tersle (imcomplement yerine)
    fprintf('Polarite ters cevrildi (zemin beyazlatildi).\n');
else
    fprintf('Polarite dogru (zemin zaten beyaz).\n');
end

%% 7) MORFOLOJİK TEMİZLEME (Minimal - kelime ayırma KORUNUYOR)
% Sadece çok küçük gürültüleri sil
bwImg = bwareaopen(bwImg, minPixelArea);

% MORFOLOJIK İŞLEMLER KALDIRILDI
% imclose ve imdilate kelimeleri yapıştırıyor - kullanmıyoruz!

fprintf('Minimal temizleme tamamlandi (kelime ayirma maksimum korundu).\n');

%% 8) BOYUTLANDIRMA (isteğe bağlı)
if resizeFactor ~= 1
    processedImg = imresize(bwImg, resizeFactor, 'bicubic');
    fprintf('Goruntu %gx olceklendirildi.\n', resizeFactor);
else
    processedImg = bwImg;
end

%% 9) GÖRSEL DENETİM - 4 aşamayı göster
figure('Name', 'Preprocessing Debug Panel', 'NumberTitle', 'off', 'Position', [100 100 1200 400]);

subplot(1, 4, 1);
imshow(origImg);
title('1. Orijinal');

subplot(1, 4, 2);
imshow(grayImg);
title('2. Gri');

subplot(1, 4, 3);
imshow(correctedImg);
title('3. Isik Dengelemeli');

subplot(1, 4, 4);
imshow(processedImg);
title('4. Binary (Final)');

fprintf('\n=== Preprocessing tamamlandi ===\n');
fprintf('Sonuc degiskeni: processedImg\n');
fprintf('Eger binary tamamen siyah cikiyorsa:\n');
fprintf('  - useOtsu = false yapin\n');
fprintf('  - adaptiveSens degerini 0.3-0.4 arasina dusrun\n\n');
