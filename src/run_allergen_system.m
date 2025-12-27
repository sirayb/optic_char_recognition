%% Alerjen Tespit Sistemi - Ana Çalıştırıcı (Main Runner)
% Bu script, AllergenDetector sınıfını kullanarak tüm süreci baştan sona yönetir.

clear all; close all; clc;

% 1. Dosya Seçimi
[fname, fpath] = uigetfile({'*.jpg;*.png;*.tif', 'Gorsel Dosyalari'}, ...
    'Bir gıda paketi fotoğrafı seçin', fullfile('data', 'samples'));

if isequal(fname, 0)
    disp('İşlem iptal edildi.');
    return;
end

imagePath = fullfile(fpath, fname);

%% 2. Sistemin Başlatılması
fprintf('\n>>> Alerjen Tespit Sistemi Baslatiliyor...\n');
detector = AllergenDetector();

%% 3. İşleme ve Analiz
tic;
[annotatedImg, detected] = detector.processImage(imagePath);
procTime = toc;

%% 4. Sonuçların Raporlanması
fprintf('\n>>> ANALIZ TAMAMLANDI (%.2f saniye)\n', procTime);

if isempty(detected)
    fprintf('--- TEMİZ: Herhangi bir riskli alerjen kelimesi tespit edilemedi. ---\n');
else
    % Tekil alerjenleri bul (Kategori ve Kelime bazında)
    allDetectedWords = {detected.Word};
    allDetectedCategories = {detected.Category};
    
    % Normalizasyon bazlı tekilleştirme (Büyük/küçük/Turkce farkını eler)
    uniqueNormMatches = {};
    uniqueDisplayMatches = {};
    
    for i = 1:length(allDetectedWords)
        word = lower(char(allDetectedWords{i}));
        [~, wordNorm] = fixTurkishCharacters(word);
        wordNorm = regexprep(wordNorm, '[^a-z0-9]', ''); % Sadece temiz metin
        
        catName = char(allDetectedCategories{i});
        matchKey = [catName ':' wordNorm];
        
        if ~ismember(matchKey, uniqueNormMatches)
            uniqueNormMatches{end+1} = matchKey;
            uniqueDisplayMatches{end+1} = sprintf('%s: %s', catName, char(allDetectedWords{i}));
        end
    end
    
    fprintf('--- TEHLİKE: %d farklı kategoride toplam %d benzersiz alerjen maddesi tespit edildi! ---\n', ...
        length(unique(allDetectedCategories)), length(uniqueDisplayMatches));
    
    fprintf('\nTespit Edilen Benzersiz Maddeler:\n');
    for i = 1:length(uniqueDisplayMatches)
        fprintf('  [!] %s\n', uniqueDisplayMatches{i});
    end
    
    fprintf('\nDetaylı Tespit Listesi (Tüm Konumlar):\n');
    % Tablo olarak göster
    struct2table(detected)
end

%% 5. Ekran Uyumu ve Görselleştirme
% Kullanıcının ekranına sığması için yüksekliği 800 piksele sabitle
targetHeight = 800;
scale = targetHeight / size(annotatedImg, 1);
displayImg = imresize(annotatedImg, scale);

% Sonucu göster
fig = figure('Name', ['Alerjen Analizi: ' fname], 'NumberTitle', 'off');
imshow(displayImg);
if isempty(detected)
    title('TEMİZ: Alerjen Tespit Edilmedi', 'Color', 'g', 'FontSize', 14);
else
    title(sprintf('TEHLİKE: %d Farklı Alerjen Maddesi Tespit Edildi!', length(uniqueDisplayMatches)), ...
        'Color', 'r', 'FontSize', 14);
end

% Tam çözünürlüklü resmi kaydetmek için (isteğe bağlı)
% outputName = ['result_' fname];
% imwrite(annotatedImg, outputName);
% fprintf('\n>>> Tam cozunurluklu sonuc "%s" olarak kaydedildi.\n', outputName);
